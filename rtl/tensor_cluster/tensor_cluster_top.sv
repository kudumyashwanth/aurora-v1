`timescale 1ns/1ps

// Aurora v1 - Tensor Cluster Top
// 4 tensor cores with 64KB local buffers each.
//
// AXI slave address map (relative to 0x5000_0000):
//   0x0000 - 0x007F : Per-core control registers (0x20 per core)
//   0x1000 - 0x1FFF : Core 0 local buffer (128-bit word writes)
//   0x2000 - 0x2FFF : Core 1 local buffer
//   0x3000 - 0x3FFF : Core 2 local buffer
//   0x4000 - 0x4FFF : Core 3 local buffer
//
// Buffer write: awaddr[15:12] selects the core (1-4), awaddr[11:0] is
// the byte offset (128-bit aligned, word addr = offset[11:4]).
// On start, the FSM reads buffer entries 0-1 into a_matrix and
// entries 2-3 into b_matrix before launching the systolic array.

module tensor_cluster_top
#(
    parameter NUM_CORES = 4,
    parameter DATA_WIDTH = 16,
    parameter SIZE = 16
)
(
    input  logic clk,
    input  logic rst_n,

    // AXI4-Lite Slave (control registers + local buffer writes)
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

    // Interrupt outputs
    output logic [NUM_CORES-1:0] core_done_irq
);

////////////////////////////////////////////////////
// CONTROL/STATUS REGISTERS (Per Core)
////////////////////////////////////////////////////

logic [NUM_CORES-1:0][31:0] ctrl_reg;
logic [NUM_CORES-1:0][31:0] status_reg;
logic [NUM_CORES-1:0][31:0] a_addr_reg;
logic [NUM_CORES-1:0][31:0] b_addr_reg;
logic [NUM_CORES-1:0][31:0] c_addr_reg;
logic [NUM_CORES-1:0][31:0] config_reg;

logic [NUM_CORES-1:0] core_start;
logic [NUM_CORES-1:0] core_done;
logic [NUM_CORES-1:0] core_busy;

// Computed result read-back. Each core produces a SIZE x SIZE x 32-bit C
// matrix; flatten to SIZE*SIZE words/core so the CPU can read it through the
// AXI read window (see READ DECODE). Without this observable path the entire
// MAC fabric optimizes away in synthesis.
logic [NUM_CORES-1:0][SIZE*SIZE-1:0][31:0] result_flat;

// core_done is a single-cycle pulse from the tensor core FSM; a polling
// CPU would miss it. Latch it until the next start.
logic [NUM_CORES-1:0] core_done_sticky;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        core_done_sticky <= '0;
    else begin
        for (int k = 0; k < NUM_CORES; k++) begin
            if (core_start[k])
                core_done_sticky[k] <= 1'b0;
            else if (core_done[k])
                core_done_sticky[k] <= 1'b1;
        end
    end
end

genvar g;
generate
    for (g = 0; g < NUM_CORES; g++) begin : CTRL_DECODE
        assign core_start[g] = ctrl_reg[g][0];
        assign status_reg[g] = {29'h0, core_done_sticky[g], core_busy[g], ~core_busy[g]};
    end
endgenerate

////////////////////////////////////////////////////
// AXI WRITE DECODE
// awaddr[15:12] == 0      : control register write
// awaddr[15:12] == 1..4   : local buffer write to core (val-1)
////////////////////////////////////////////////////

wire        is_buf_wr  = s_axi_awvalid && (s_axi_awaddr[15:12] != 4'h0);
wire [1:0]  buf_core   = s_axi_awaddr[13:12] - 2'd1;  // 1→0, 2→1, 3→2, 4→3
wire [15:0] buf_wr_addr = s_axi_awaddr[15:0];          // byte address into buffer

// The buffer write needs 128-bit data; AXI slave is 32-bit.
// We collect 4 consecutive 32-bit beats into a 128-bit buffer write.
// Each AXI write transaction (aw+w) is treated as one 32-bit sub-word.
// The buffer word address is derived from awaddr[15:4] (128-bit alignment).
// awaddr[3:2] selects the 32-bit lane within the 128-bit word.
// We accumulate all 4 lanes and write when lane 3 (last) is written.

logic [127:0] buf_wr_accum [0:NUM_CORES-1];
logic [NUM_CORES-1:0] buf_wr_en;
logic [15:0]  buf_wr_word_addr [0:NUM_CORES-1];

// AXI always-ready (single-cycle accept)
assign s_axi_awready = 1'b1;
assign s_axi_wready  = 1'b1;

integer lc;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (lc = 0; lc < NUM_CORES; lc++) begin
            buf_wr_accum[lc]     <= '0;
            buf_wr_word_addr[lc] <= '0;
        end
        buf_wr_en <= '0;
    end else begin
        buf_wr_en <= '0;  // default de-assert

        if (s_axi_awvalid && s_axi_wvalid && is_buf_wr) begin
            // Accumulate 32-bit lane
            case (s_axi_awaddr[3:2])
                2'd0: buf_wr_accum[buf_core][31:0]   <= s_axi_wdata;
                2'd1: buf_wr_accum[buf_core][63:32]  <= s_axi_wdata;
                2'd2: buf_wr_accum[buf_core][95:64]  <= s_axi_wdata;
                2'd3: begin
                    buf_wr_accum[buf_core][127:96] <= s_axi_wdata;
                    buf_wr_en[buf_core]            <= 1'b1;
                    // byte address within the core's buffer window; tensor_local_buffer
                    // divides by 16 internally to get the 128-bit word index
                    buf_wr_word_addr[buf_core]     <= {4'b0, s_axi_awaddr[11:0]};
                end
            endcase
        end
    end
end

////////////////////////////////////////////////////
// TENSOR CORES WITH LOCAL BUFFERS + MATRIX LOADER
////////////////////////////////////////////////////

generate
    for (g = 0; g < NUM_CORES; g++) begin : TENSOR_CORE_GEN

        // ---- Local Buffer ----
        logic [15:0]  buf_rd_addr;
        logic         buf_rd_en;
        logic [127:0] buf_rd_data;

        tensor_local_buffer #(
            .DATA_WIDTH(128),
            .ADDR_WIDTH(16),
            .BUFFER_DEPTH(4096)
        ) local_buffer (
            .clk          (clk),
            .rst_n        (rst_n),
            .porta_addr   (buf_wr_word_addr[g]),
            .porta_wr_en  (buf_wr_en[g]),
            .porta_wr_data(buf_wr_accum[g]),
            .porta_rd_data(),
            .portb_addr   (buf_rd_addr),
            .portb_rd_en  (buf_rd_en),
            .portb_rd_data(buf_rd_data)
        );

        // ---- Matrix Loader FSM ----
        // Reads 4 buffer entries before launching:
        //   entry 0 → a_matrix[7:0]
        //   entry 1 → a_matrix[15:8]
        //   entry 2 → b_matrix[7:0]
        //   entry 3 → b_matrix[15:8]
        // The buffer has 1-cycle registered read latency.

        typedef enum logic [2:0] {
            LS_IDLE    = 3'd0,
            LS_RD0     = 3'd1,  // issue read for entry 0
            LS_RD1     = 3'd2,  // latch entry 0, issue read for entry 1
            LS_RD2     = 3'd3,  // latch entry 1, issue read for entry 2
            LS_RD3     = 3'd4,  // latch entry 2, issue read for entry 3
            LS_LATCH3  = 3'd5,  // latch entry 3
            LS_RUN     = 3'd6,  // tensor_core active
            LS_DONE    = 3'd7
        } load_state_t;

        load_state_t ls, ls_next;

        logic [SIZE-1:0][DATA_WIDTH-1:0] a_matrix;
        logic [SIZE-1:0][DATA_WIDTH-1:0] b_matrix;
        logic [SIZE-1:0][SIZE-1:0][31:0] result;
        logic core_launch;

        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) ls <= LS_IDLE;
            else        ls <= ls_next;
        end

        always_comb begin
            ls_next    = ls;
            buf_rd_addr = '0;
            buf_rd_en   = 1'b0;
            core_launch = 1'b0;

            // buf_rd_addr is a BYTE address; tensor_local_buffer divides by 16
            // internally. Each 128-bit matrix chunk occupies 16 bytes.
            // Entries 0-1 → a_matrix, entries 2-3 → b_matrix.
            case (ls)
                LS_IDLE:   if (core_start[g]) begin ls_next = LS_RD0; buf_rd_addr = 16'h0000; buf_rd_en = 1'b1; end
                LS_RD0:    begin ls_next = LS_RD1;   buf_rd_addr = 16'h0010; buf_rd_en = 1'b1; end
                LS_RD1:    begin ls_next = LS_RD2;   buf_rd_addr = 16'h0020; buf_rd_en = 1'b1; end
                LS_RD2:    begin ls_next = LS_RD3;   buf_rd_addr = 16'h0030; buf_rd_en = 1'b1; end
                LS_RD3:    begin ls_next = LS_LATCH3; end
                LS_LATCH3: begin ls_next = LS_RUN;   core_launch = 1'b1; end
                LS_RUN:    begin ls_next = LS_DONE; end
                LS_DONE:   begin ls_next = LS_IDLE; end
                default:   ls_next = LS_IDLE;
            endcase
        end

        // Latch buffer reads into matrix registers
        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                a_matrix <= '0;
                b_matrix <= '0;
            end else begin
                // per-element assigns (Yosys can't slice packed-of-packed)
                case (ls)
                    LS_RD1:    for (int e = 0; e < 8; e++) a_matrix[e]   <= buf_rd_data[16*e +: 16]; // entry 0
                    LS_RD2:    for (int e = 0; e < 8; e++) a_matrix[e+8] <= buf_rd_data[16*e +: 16]; // entry 1
                    LS_RD3:    for (int e = 0; e < 8; e++) b_matrix[e]   <= buf_rd_data[16*e +: 16]; // entry 2
                    LS_LATCH3: for (int e = 0; e < 8; e++) b_matrix[e+8] <= buf_rd_data[16*e +: 16]; // entry 3
                    default: ;
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
            .done     (core_done[g])
        );

        // Expose this core's result for AXI read-back (flatten 16x16 -> 256 words)
        assign result_flat[g] = result;

        assign core_busy[g] = (ls != LS_IDLE) && !core_done[g];
        assign core_done_irq[g] = (ls == LS_DONE);
    end
endgenerate

////////////////////////////////////////////////////
// AXI WRITE — CONTROL REGISTERS
////////////////////////////////////////////////////

logic [1:0] core_sel_wr;
logic [4:0] reg_offset_wr;

assign core_sel_wr   = s_axi_awaddr[6:5];
assign reg_offset_wr = s_axi_awaddr[4:0];

integer lci;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (lci = 0; lci < NUM_CORES; lci++) begin
            ctrl_reg[lci]   <= '0;
            a_addr_reg[lci] <= '0;
            b_addr_reg[lci] <= '0;
            c_addr_reg[lci] <= '0;
            config_reg[lci] <= '0;
        end
    end else begin
        for (lci = 0; lci < NUM_CORES; lci++)
            ctrl_reg[lci][0] <= 1'b0;  // auto-clear start

        if (s_axi_awvalid && s_axi_wvalid && !is_buf_wr) begin
            case (reg_offset_wr)
                5'h00: ctrl_reg[core_sel_wr]   <= s_axi_wdata;
                5'h08: a_addr_reg[core_sel_wr] <= s_axi_wdata;
                5'h0C: b_addr_reg[core_sel_wr] <= s_axi_wdata;
                5'h10: c_addr_reg[core_sel_wr] <= s_axi_wdata;
                5'h14: config_reg[core_sel_wr] <= s_axi_wdata;
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
// AXI READ — CONTROL REGISTERS
////////////////////////////////////////////////////

// araddr[15]==0 : control/status register read (core = araddr[6:5])
// araddr[15]==1 : result matrix read-back
//                 core      = araddr[14:13]
//                 word idx  = araddr[9:2]  (0..255 -> result[row][col])
logic [1:0] core_sel_rd;
logic [4:0] reg_offset_rd;
logic       is_result_rd;
logic [1:0] res_core_rd;
logic [7:0] res_word_rd;

assign core_sel_rd   = s_axi_araddr[6:5];
assign reg_offset_rd = s_axi_araddr[4:0];
assign is_result_rd  = s_axi_araddr[15];
assign res_core_rd   = s_axi_araddr[14:13];
assign res_word_rd   = s_axi_araddr[9:2];

assign s_axi_arready = 1'b1;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s_axi_rdata  <= '0;
        s_axi_rvalid <= 1'b0;
    end else if (s_axi_arvalid) begin
        if (is_result_rd) begin
            s_axi_rdata <= result_flat[res_core_rd][res_word_rd];
        end else begin
            case (reg_offset_rd)
                5'h00:   s_axi_rdata <= ctrl_reg[core_sel_rd];
                5'h04:   s_axi_rdata <= status_reg[core_sel_rd];
                5'h08:   s_axi_rdata <= a_addr_reg[core_sel_rd];
                5'h0C:   s_axi_rdata <= b_addr_reg[core_sel_rd];
                5'h10:   s_axi_rdata <= c_addr_reg[core_sel_rd];
                5'h14:   s_axi_rdata <= config_reg[core_sel_rd];
                default: s_axi_rdata <= 32'hDEADBEEF;
            endcase
        end
        s_axi_rvalid <= 1'b1;
    end else if (s_axi_rready) begin
        s_axi_rvalid <= 1'b0;
    end
end

endmodule
