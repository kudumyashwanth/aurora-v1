`timescale 1ns/1ps
/* verilator lint_off WIDTH */
/* verilator lint_off UNUSED */
/* verilator lint_off PINMISSING */
/* verilator lint_off CASEINCOMPLETE */

// Isolation TB: RocketAXITileTop driving simple single-beat AXI4 BFMs.
// Two-port wrapper:
//   mem_axi4  (cacheable) -> ROM @0x8000_0000 (boot program, 64b words) + SRAM @0x1000_0000 scratch.
//   mmio_axi4 (uncached)  -> UART @0x2000_0000 (writes captured as chars) + GPIO/tensor sink, reads 0.
// Goal: see Rocket fetch + boot + print the UART banner, no SoC.

module tb_rocket_iso (input logic clk, input logic rst_n);

    localparam AW=32, DW=64, IW=4;

    // ---- mem_axi4 (cacheable memory port) ----
    logic [IW-1:0] awid; logic [AW-1:0] awaddr; logic awvalid, awready;
    logic [DW-1:0] wdata; logic [DW/8-1:0] wstrb; logic wvalid, wready, wlast;
    logic [IW-1:0] bid; logic [1:0] bresp; logic bvalid, bready;
    logic [IW-1:0] arid; logic [AW-1:0] araddr; logic arvalid, arready;
    logic [IW-1:0] rid; logic [DW-1:0] rdata; logic [1:0] rresp; logic rlast, rvalid, rready;

    // ---- mmio_axi4 (uncached MMIO port) ----
    logic [IW-1:0] m_awid; logic [AW-1:0] m_awaddr; logic m_awvalid, m_awready;
    logic [DW-1:0] m_wdata; logic [DW/8-1:0] m_wstrb; logic m_wvalid, m_wready, m_wlast;
    logic [IW-1:0] m_bid; logic [1:0] m_bresp; logic m_bvalid, m_bready;
    logic [IW-1:0] m_arid; logic [AW-1:0] m_araddr; logic m_arvalid, m_arready;
    logic [IW-1:0] m_rid; logic [DW-1:0] m_rdata; logic [1:0] m_rresp; logic m_rlast, m_rvalid, m_rready;

    RocketAXITileTop u_rocket (
        .clock(clk), .reset(~rst_n),
        // ---- mem_axi4 ----
        .mem_axi4_0_aw_valid(awvalid), .mem_axi4_0_aw_ready(awready),
        .mem_axi4_0_aw_bits_id(awid), .mem_axi4_0_aw_bits_addr(awaddr),
        .mem_axi4_0_aw_bits_len(), .mem_axi4_0_aw_bits_size(), .mem_axi4_0_aw_bits_burst(),
        .mem_axi4_0_aw_bits_lock(), .mem_axi4_0_aw_bits_cache(), .mem_axi4_0_aw_bits_prot(), .mem_axi4_0_aw_bits_qos(),
        .mem_axi4_0_w_valid(wvalid), .mem_axi4_0_w_ready(wready),
        .mem_axi4_0_w_bits_data(wdata), .mem_axi4_0_w_bits_strb(wstrb), .mem_axi4_0_w_bits_last(wlast),
        .mem_axi4_0_b_valid(bvalid), .mem_axi4_0_b_ready(bready), .mem_axi4_0_b_bits_id(bid), .mem_axi4_0_b_bits_resp(bresp),
        .mem_axi4_0_ar_valid(arvalid), .mem_axi4_0_ar_ready(arready),
        .mem_axi4_0_ar_bits_id(arid), .mem_axi4_0_ar_bits_addr(araddr),
        .mem_axi4_0_ar_bits_len(), .mem_axi4_0_ar_bits_size(), .mem_axi4_0_ar_bits_burst(),
        .mem_axi4_0_ar_bits_lock(), .mem_axi4_0_ar_bits_cache(), .mem_axi4_0_ar_bits_prot(), .mem_axi4_0_ar_bits_qos(),
        .mem_axi4_0_r_valid(rvalid), .mem_axi4_0_r_ready(rready),
        .mem_axi4_0_r_bits_id(rid), .mem_axi4_0_r_bits_data(rdata), .mem_axi4_0_r_bits_resp(rresp), .mem_axi4_0_r_bits_last(rlast),
        // ---- mmio_axi4 ----
        .mmio_axi4_0_aw_valid(m_awvalid), .mmio_axi4_0_aw_ready(m_awready),
        .mmio_axi4_0_aw_bits_id(m_awid), .mmio_axi4_0_aw_bits_addr(m_awaddr),
        .mmio_axi4_0_aw_bits_len(), .mmio_axi4_0_aw_bits_size(), .mmio_axi4_0_aw_bits_burst(),
        .mmio_axi4_0_aw_bits_lock(), .mmio_axi4_0_aw_bits_cache(), .mmio_axi4_0_aw_bits_prot(), .mmio_axi4_0_aw_bits_qos(),
        .mmio_axi4_0_w_valid(m_wvalid), .mmio_axi4_0_w_ready(m_wready),
        .mmio_axi4_0_w_bits_data(m_wdata), .mmio_axi4_0_w_bits_strb(m_wstrb), .mmio_axi4_0_w_bits_last(m_wlast),
        .mmio_axi4_0_b_valid(m_bvalid), .mmio_axi4_0_b_ready(m_bready), .mmio_axi4_0_b_bits_id(m_bid), .mmio_axi4_0_b_bits_resp(m_bresp),
        .mmio_axi4_0_ar_valid(m_arvalid), .mmio_axi4_0_ar_ready(m_arready),
        .mmio_axi4_0_ar_bits_id(m_arid), .mmio_axi4_0_ar_bits_addr(m_araddr),
        .mmio_axi4_0_ar_bits_len(), .mmio_axi4_0_ar_bits_size(), .mmio_axi4_0_ar_bits_burst(),
        .mmio_axi4_0_ar_bits_lock(), .mmio_axi4_0_ar_bits_cache(), .mmio_axi4_0_ar_bits_prot(), .mmio_axi4_0_ar_bits_qos(),
        .mmio_axi4_0_r_valid(m_rvalid), .mmio_axi4_0_r_ready(m_rready),
        .mmio_axi4_0_r_bits_id(m_rid), .mmio_axi4_0_r_bits_data(m_rdata), .mmio_axi4_0_r_bits_resp(m_rresp), .mmio_axi4_0_r_bits_last(m_rlast)
    );

    // ---- memory arrays ----
    logic [63:0] rom  [0:8191];     // 64KB ROM @ 0x80000000
    logic [63:0] sram [0:524287];   // 4MB SRAM @ 0x10000000
    initial $readmemh("/home/yashwanth/aurora_v1/boot/aurora_boot_rom64.hex", rom);

    function automatic logic isrom(logic [AW-1:0] a); isrom = (a[31:28]==4'h8); endfunction // ROM @ 0x80000000
    function automatic logic issram(logic [AW-1:0] a); issram = (a[31:28]==4'h1); endfunction
    function automatic logic [18:0] sidx(logic [AW-1:0] a); sidx = a[21:3]; endfunction
    function automatic logic [12:0] ridx(logic [AW-1:0] a); ridx = a[15:3]; endfunction

    // ======================= mem_axi4 BFM (ROM + SRAM) =======================
    typedef enum logic {R_IDLE, R_RESP} rstate_t;
    rstate_t rst_;
    logic [AW-1:0] r_addr; logic [IW-1:0] r_id;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin rst_ <= R_IDLE; r_addr<='0; r_id<='0; end
        else case (rst_)
            R_IDLE: if (arvalid) begin r_addr<=araddr; r_id<=arid; rst_<=R_RESP; end
            R_RESP: if (rready)  rst_<=R_IDLE;
        endcase
    end
    assign arready = (rst_==R_IDLE);
    assign rvalid  = (rst_==R_RESP);
    assign rid     = r_id;
    assign rlast   = 1'b1;
    assign rresp   = 2'b00;
    assign rdata   = isrom(r_addr)  ? rom[ridx(r_addr)]
                   : issram(r_addr) ? sram[sidx(r_addr)]
                   : 64'h0;

    typedef enum logic [1:0] {W_AW, W_W, W_RESP} wstate_t;
    wstate_t wst;
    logic [AW-1:0] w_addr; logic [IW-1:0] w_id;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin wst<=W_AW; w_addr<='0; w_id<='0; end
        else case (wst)
            W_AW: if (awvalid) begin w_addr<=awaddr; w_id<=awid; wst<=W_W; end
            W_W:  if (wvalid) begin
                    if (issram(w_addr)) for (int i=0;i<8;i++) if (wstrb[i]) sram[sidx(w_addr)][i*8+:8] <= wdata[i*8+:8];
                    wst<=W_RESP;
                  end
            W_RESP: if (bready) wst<=W_AW;
        endcase
    end
    assign awready = (wst==W_AW);
    assign wready  = (wst==W_W);
    assign bvalid  = (wst==W_RESP);
    assign bid     = w_id;
    assign bresp   = 2'b00;

    // ======================= mmio_axi4 BFM (UART/GPIO/tensor) =======================
    // Reads return 0 (UART STATUS = not-busy). Writes are accepted; UART DATA writes captured as chars.
    rstate_t m_rst;
    logic [AW-1:0] m_r_addr; logic [IW-1:0] m_r_id;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin m_rst <= R_IDLE; m_r_addr<='0; m_r_id<='0; end
        else case (m_rst)
            R_IDLE: if (m_arvalid) begin m_r_addr<=m_araddr; m_r_id<=m_arid; m_rst<=R_RESP; end
            R_RESP: if (m_rready)  m_rst<=R_IDLE;
        endcase
    end
    assign m_arready = (m_rst==R_IDLE);
    assign m_rvalid  = (m_rst==R_RESP);
    assign m_rid     = m_r_id;
    assign m_rlast   = 1'b1;
    assign m_rresp   = 2'b00;
    assign m_rdata   = 64'h0;   // MMIO regions read as 0 => UART "not busy", tensor "not done"

    wstate_t m_wst;
    logic [AW-1:0] m_w_addr; logic [IW-1:0] m_w_id;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin m_wst<=W_AW; m_w_addr<='0; m_w_id<='0; end
        else case (m_wst)
            W_AW: if (m_awvalid) begin m_w_addr<=m_awaddr; m_w_id<=m_awid; m_wst<=W_W; end
            W_W:  if (m_wvalid) m_wst<=W_RESP;
            W_RESP: if (m_bready) m_wst<=W_AW;
        endcase
    end
    assign m_awready = (m_wst==W_AW);
    assign m_wready  = (m_wst==W_W);
    assign m_bvalid  = (m_wst==W_RESP);
    assign m_bid     = m_w_id;
    assign m_bresp   = 2'b00;

    // ---- is the tile core actually clocked? count childClock edges ----
    integer tile_clk_edges = 0;
    always @(posedge u_rocket.tile_prci_domain.element_reset_domain_childClock)
        tile_clk_edges <= tile_clk_edges + 1;

    // ---- probes ----
    integer fcnt=0; logic sa, sr; integer retired=0; logic seen_trace;
    always @(posedge clk) begin
        fcnt<=fcnt+1;
        if (u_rocket.tile_prci_domain.auto_element_reset_domain_rockettile_trace_source_out_insns_0_valid) begin
            retired<=retired+1;
            if (retired < 6 || (u_rocket.tile_prci_domain.auto_element_reset_domain_rockettile_trace_source_out_insns_0_exception && retired < 200)) begin
                $display("[f%0d] RETIRE iaddr=0x%0h exc=%b int=%b cause=%0d", fcnt,
                    u_rocket.tile_prci_domain.auto_element_reset_domain_rockettile_trace_source_out_insns_0_iaddr,
                    u_rocket.tile_prci_domain.auto_element_reset_domain_rockettile_trace_source_out_insns_0_exception,
                    u_rocket.tile_prci_domain.auto_element_reset_domain_rockettile_trace_source_out_insns_0_interrupt,
                    u_rocket.tile_prci_domain.auto_element_reset_domain_rockettile_trace_source_out_insns_0_cause);
            end
        end
        if (fcnt==2000 || fcnt==50000) $display("[f%0d] tile_clk_edges=%0d retired=%0d wfi=%b", fcnt, tile_clk_edges, retired,
            u_rocket.tile_prci_domain.auto_element_reset_domain_rockettile_wfi_out_0);
        if (arvalid && arready && !sa) begin $display("[f%0d] MEM FETCH AR addr=0x%08h id=%0d", fcnt, araddr, arid); sa<=1; end
        if (m_awvalid && m_awready && !sr) begin $display("[f%0d] MMIO WRITE AW addr=0x%08h", fcnt, m_awaddr); sr<=1; end
    end

    // UART: boot writes UART DATA @0x2000_0000 (offset 0x00) on the mmio port -> print as chars.
    integer uart_chars = 0;
    always @(posedge clk) begin
        if (rst_n && m_wvalid && m_wready && (m_w_addr[31:24]==8'h20) && (m_w_addr[7:0]==8'h00)) begin
            uart_chars <= uart_chars + 1;
            $write("%c", m_wdata[7:0]);
        end
    end
    final $display("\n=== TOTAL UART CHARS WRITTEN: %0d ===", uart_chars);

endmodule
