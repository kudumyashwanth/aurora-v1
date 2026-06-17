`timescale 1ns/1ps

// Aurora v1 - Single Tensor Core, hardenable block (Phase 1b macro target).
//
// One 16x16 systolic core (256 MACs) + one 8 KB SRAM local buffer (4x sky130
// 32x512 macros) + matrix-loader FSM + AXI4-Lite slave (control regs, 128-bit
// buffer writes, result read-back). This is tensor_cluster_top specialized to a
// single core: the full 4-core cluster (~800k cells) does not place/route on a
// 23 GB host, so we harden ONE core as a macro and instantiate it x4 at top
// integration (same strategy as RocketTile).
//
// AXI slave map (relative to the block's base):
//   awaddr[15:12]==0 : control registers   (0x00 ctrl, 0x08 a_addr,
//                      0x0C b_addr, 0x10 c_addr, 0x14 config)
//   awaddr[15:12]==1 : local-buffer write   (128-bit word assembled from 4x
//                      32-bit beats; awaddr[11:4]=word, awaddr[3:2]=lane)
//   araddr[15]==0    : register read         (0x00 ctrl,0x04 status,0x08 a_addr,
//                      0x0C b_addr,0x10 c_addr,0x14 config)
//   araddr[15]==1    : result read-back      (word = araddr[9:2], 0..255)

module tensor_core_hard
#(
    parameter DATA_WIDTH = 16,
    parameter SIZE       = 8     // 8x8 = 64-MAC tile (routes clean; tile x4 for full 256)
)
(
    input  logic clk,
    input  logic rst_n,

    // AXI4-Lite Slave
    input  logic [31:0] s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,

    input  logic [31:0] s_axi_wdata,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,

    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,

    input  logic [31:0] s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,

    output logic [31:0] s_axi_rdata,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    output logic        core_done_irq
);

    ////////////////////////////////////////////////////
    // CONTROL/STATUS REGISTERS
    ////////////////////////////////////////////////////
    logic [31:0] ctrl_reg;
    logic [31:0] status_reg;
    logic [31:0] a_addr_reg;
    logic [31:0] b_addr_reg;
    logic [31:0] c_addr_reg;
    logic [31:0] config_reg;

    logic core_start;
    logic core_done;
    logic core_busy;
    logic core_done_sticky;

    assign core_start = ctrl_reg[0];

    // Latch the single-cycle done pulse until the next start (poll-safe).
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            core_done_sticky <= 1'b0;
        else if (core_start)
            core_done_sticky <= 1'b0;
        else if (core_done)
            core_done_sticky <= 1'b1;
    end

    assign status_reg = {29'h0, core_done_sticky, core_busy, ~core_busy};

    ////////////////////////////////////////////////////
    // AXI WRITE DECODE
    ////////////////////////////////////////////////////
    wire is_buf_wr = s_axi_awvalid && (s_axi_awaddr[15:12] != 4'h0);

    logic [127:0] buf_wr_accum;
    logic         buf_wr_en;
    logic [15:0]  buf_wr_word_addr;

    assign s_axi_awready = 1'b1;
    assign s_axi_wready  = 1'b1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buf_wr_accum     <= '0;
            buf_wr_word_addr <= '0;
            buf_wr_en        <= 1'b0;
        end else begin
            buf_wr_en <= 1'b0;  // default de-assert
            if (s_axi_awvalid && s_axi_wvalid && is_buf_wr) begin
                case (s_axi_awaddr[3:2])
                    2'd0: buf_wr_accum[31:0]   <= s_axi_wdata;
                    2'd1: buf_wr_accum[63:32]  <= s_axi_wdata;
                    2'd2: buf_wr_accum[95:64]  <= s_axi_wdata;
                    2'd3: begin
                        buf_wr_accum[127:96] <= s_axi_wdata;
                        buf_wr_en            <= 1'b1;
                        buf_wr_word_addr     <= {4'b0, s_axi_awaddr[11:0]};
                    end
                endcase
            end
        end
    end

    ////////////////////////////////////////////////////
    // LOCAL BUFFER (SRAM macros)
    ////////////////////////////////////////////////////
    logic [15:0]  buf_rd_addr;
    logic         buf_rd_en;
    logic [127:0] buf_rd_data;

    tensor_local_buffer #(
        .DATA_WIDTH(128),
        .ADDR_WIDTH(16),
        .BUFFER_DEPTH(512)
    ) local_buffer (
        .clk          (clk),
        .rst_n        (rst_n),
        .porta_addr   (buf_wr_word_addr),
        .porta_wr_en  (buf_wr_en),
        .porta_wr_data(buf_wr_accum),
        .porta_rd_data(),
        .portb_addr   (buf_rd_addr),
        .portb_rd_en  (buf_rd_en),
        .portb_rd_data(buf_rd_data)
    );

    ////////////////////////////////////////////////////
    // MATRIX LOADER FSM  (parametric in SIZE / DATA_WIDTH)
    // Buffer holds 128-bit words. EPW = elements/word, WPM = words per matrix.
    // Stream WPM words of A then WPM words of B (1-cycle SRAM read latency),
    // then pulse core_launch. SIZE=8,DW=16 -> 1 word each = 2 reads (A@0x00,B@0x10);
    // SIZE=16 -> 2 words each = 4 reads. A then B, word index r -> buffer addr r*0x10.
    ////////////////////////////////////////////////////
    localparam int EPW = 128 / DATA_WIDTH;   // elements per 128-bit buffer word
    localparam int WPM = SIZE / EPW;          // buffer words per matrix
    localparam int NRD = 2 * WPM;             // total reads (A words then B words)

    typedef enum logic [1:0] { LS_IDLE, LS_STREAM, LS_RUN, LS_DONE } load_state_t;
    load_state_t ls;

    logic [SIZE-1:0][DATA_WIDTH-1:0] a_matrix;
    logic [SIZE-1:0][DATA_WIDTH-1:0] b_matrix;
    logic [SIZE-1:0][SIZE-1:0][31:0] result;
    logic core_launch;

    logic [31:0] issue_idx;   // next buffer word to request
    logic        rd_pend;     // requested word lands on buf_rd_data this cycle
    logic [31:0] rd_idx;      // which word that is

    // Combinational read issue + launch pulse.
    wire issuing = (ls == LS_STREAM) && (issue_idx < NRD);
    always_comb begin
        buf_rd_en   = issuing;
        buf_rd_addr = issuing ? {issue_idx[11:0], 4'b0000} : 16'h0;   // word stride 0x10
        core_launch = (ls == LS_RUN);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ls        <= LS_IDLE;
            issue_idx <= '0;
            rd_pend   <= 1'b0;
            rd_idx    <= '0;
            a_matrix  <= '0;
            b_matrix  <= '0;
        end else begin
            // Latch the word requested last cycle: first WPM -> A, next WPM -> B.
            if (rd_pend) begin
                if (rd_idx < WPM) begin
                    for (int e = 0; e < EPW; e++)
                        a_matrix[rd_idx*EPW + e] <= buf_rd_data[DATA_WIDTH*e +: DATA_WIDTH];
                end else begin
                    for (int e = 0; e < EPW; e++)
                        b_matrix[(rd_idx-WPM)*EPW + e] <= buf_rd_data[DATA_WIDTH*e +: DATA_WIDTH];
                end
            end
            rd_pend <= 1'b0;

            case (ls)
                LS_IDLE: begin
                    issue_idx <= '0;
                    if (core_start) ls <= LS_STREAM;
                end
                LS_STREAM: begin
                    if (issue_idx < NRD) begin
                        rd_pend   <= 1'b1;
                        rd_idx    <= issue_idx;
                        issue_idx <= issue_idx + 1;
                    end else begin
                        ls <= LS_RUN;   // all words requested; last latch lands this cycle
                    end
                end
                LS_RUN:  ls <= LS_DONE;
                LS_DONE: ls <= LS_IDLE;
                default: ls <= LS_IDLE;
            endcase
        end
    end

    tensor_core #(
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE)
    ) core (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (core_launch),
        .a_matrix (a_matrix),
        .b_matrix (b_matrix),
        .result   (result),
        .done     (core_done)
    );

    assign core_busy     = (ls != LS_IDLE) && !core_done;
    assign core_done_irq = (ls == LS_DONE);

    // Flatten the SIZE x SIZE result for AXI read-back (keeps the MAC fabric alive).
    localparam int RIDXW = $clog2(SIZE*SIZE);   // result word index width (8x8->6, 16x16->8)
    logic [SIZE*SIZE-1:0][31:0] result_flat;
    assign result_flat = result;

    ////////////////////////////////////////////////////
    // AXI WRITE — CONTROL REGISTERS + B RESPONSE
    ////////////////////////////////////////////////////
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_reg   <= '0;
            a_addr_reg <= '0;
            b_addr_reg <= '0;
            c_addr_reg <= '0;
            config_reg <= '0;
        end else begin
            ctrl_reg[0] <= 1'b0;  // auto-clear start
            if (s_axi_awvalid && s_axi_wvalid && !is_buf_wr) begin
                case (s_axi_awaddr[4:0])
                    5'h00: ctrl_reg   <= s_axi_wdata;
                    5'h08: a_addr_reg <= s_axi_wdata;
                    5'h0C: b_addr_reg <= s_axi_wdata;
                    5'h10: c_addr_reg <= s_axi_wdata;
                    5'h14: config_reg <= s_axi_wdata;
                    default: ;
                endcase
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            s_axi_bvalid <= 1'b0;
        else if (s_axi_awvalid && s_axi_wvalid)
            s_axi_bvalid <= 1'b1;
        else if (s_axi_bready)
            s_axi_bvalid <= 1'b0;
    end

    ////////////////////////////////////////////////////
    // AXI READ
    ////////////////////////////////////////////////////
    assign s_axi_arready = 1'b1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_rdata  <= '0;
            s_axi_rvalid <= 1'b0;
        end else if (s_axi_arvalid) begin
            if (s_axi_araddr[15]) begin
                s_axi_rdata <= result_flat[s_axi_araddr[2 +: RIDXW]];
            end else begin
                case (s_axi_araddr[4:0])
                    5'h00:   s_axi_rdata <= ctrl_reg;
                    5'h04:   s_axi_rdata <= status_reg;
                    5'h08:   s_axi_rdata <= a_addr_reg;
                    5'h0C:   s_axi_rdata <= b_addr_reg;
                    5'h10:   s_axi_rdata <= c_addr_reg;
                    5'h14:   s_axi_rdata <= config_reg;
                    default: s_axi_rdata <= 32'hDEADBEEF;
                endcase
            end
            s_axi_rvalid <= 1'b1;
        end else if (s_axi_rready) begin
            s_axi_rvalid <= 1'b0;
        end
    end

endmodule
