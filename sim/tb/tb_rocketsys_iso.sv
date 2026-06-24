`timescale 1ns/1ps
/* verilator lint_off WIDTH */
/* verilator lint_off UNUSED */
/* verilator lint_off PINMISSING */
/* verilator lint_off CASEINCOMPLETE */
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */

// Isolation TB: RocketAXISystem (full subsystem) -> mem_axi4 (program @0x80000000) +
// mmio_axi4 (UART capture / status=0). Debug + interrupts tied off. Internal bootrom
// resets the core -> jumps to 0x80000000 -> our program. Goal: see UART boot banner.
module tb_rocketsys_iso (input logic clk, input logic rst_n);

    localparam AW=32, IW=4;
    logic rst = ~rst_n; // subsystem reset is active-high

    // ---- mem_axi4 (cacheable memory, full 32b addr) ----
    logic [IW-1:0] m_awid; logic [AW-1:0] m_awaddr; logic [7:0] m_awlen; logic [2:0] m_awsize; logic [1:0] m_awburst;
    logic m_awvalid,m_awready; logic [63:0] m_wdata; logic [7:0] m_wstrb; logic m_wlast,m_wvalid,m_wready;
    logic [IW-1:0] m_bid; logic [1:0] m_bresp; logic m_bvalid,m_bready;
    logic [IW-1:0] m_arid; logic [AW-1:0] m_araddr; logic [7:0] m_arlen; logic [2:0] m_arsize; logic [1:0] m_arburst;
    logic m_arvalid,m_arready; logic [IW-1:0] m_rid; logic [63:0] m_rdata; logic [1:0] m_rresp; logic m_rlast,m_rvalid,m_rready;

    // ---- mmio_axi4 (device, 31b addr) ----
    logic [IW-1:0] o_awid; logic [30:0] o_awaddr; logic [7:0] o_awlen; logic [2:0] o_awsize; logic [1:0] o_awburst;
    logic o_awvalid,o_awready; logic [63:0] o_wdata; logic [7:0] o_wstrb; logic o_wlast,o_wvalid,o_wready;
    logic [IW-1:0] o_bid; logic [1:0] o_bresp; logic o_bvalid,o_bready;
    logic [IW-1:0] o_arid; logic [30:0] o_araddr; logic [7:0] o_arlen; logic [2:0] o_arsize; logic [1:0] o_arburst;
    logic o_arvalid,o_arready; logic [IW-1:0] o_rid; logic [63:0] o_rdata; logic [1:0] o_rresp; logic o_rlast,o_rvalid,o_rready;

    logic dbg_ndreset;
    RocketAXISystem dut (
        .io_aggregator_5_clock(clk), .io_aggregator_5_reset(rst),
        .debug_ndreset(dbg_ndreset),
        // debug tie-off
        .debug_clockeddmi_dmi_req_valid(1'b0), .debug_clockeddmi_dmi_req_bits_addr(7'b0),
        .debug_clockeddmi_dmi_req_bits_data(32'b0), .debug_clockeddmi_dmi_req_bits_op(2'b0),
        .debug_clockeddmi_dmi_resp_ready(1'b1), .debug_clockeddmi_dmiClock(clk),
        .debug_dmactiveAck(1'b1),   // ack the debug module's dmactive (release its reset domain)
        .interrupts(2'b0),
        // mem_axi4
        .mem_axi4_0_aw_ready(m_awready), .mem_axi4_0_aw_valid(m_awvalid), .mem_axi4_0_aw_bits_id(m_awid),
        .mem_axi4_0_aw_bits_addr(m_awaddr), .mem_axi4_0_aw_bits_len(m_awlen), .mem_axi4_0_aw_bits_size(m_awsize),
        .mem_axi4_0_aw_bits_burst(m_awburst), .mem_axi4_0_w_ready(m_wready), .mem_axi4_0_w_valid(m_wvalid),
        .mem_axi4_0_w_bits_data(m_wdata), .mem_axi4_0_w_bits_strb(m_wstrb), .mem_axi4_0_w_bits_last(m_wlast),
        .mem_axi4_0_b_ready(m_bready), .mem_axi4_0_b_valid(m_bvalid), .mem_axi4_0_b_bits_id(m_bid), .mem_axi4_0_b_bits_resp(m_bresp),
        .mem_axi4_0_ar_ready(m_arready), .mem_axi4_0_ar_valid(m_arvalid), .mem_axi4_0_ar_bits_id(m_arid),
        .mem_axi4_0_ar_bits_addr(m_araddr), .mem_axi4_0_ar_bits_len(m_arlen), .mem_axi4_0_ar_bits_size(m_arsize),
        .mem_axi4_0_ar_bits_burst(m_arburst), .mem_axi4_0_r_ready(m_rready), .mem_axi4_0_r_valid(m_rvalid),
        .mem_axi4_0_r_bits_id(m_rid), .mem_axi4_0_r_bits_data(m_rdata), .mem_axi4_0_r_bits_resp(m_rresp), .mem_axi4_0_r_bits_last(m_rlast),
        // mmio_axi4
        .mmio_axi4_0_aw_ready(o_awready), .mmio_axi4_0_aw_valid(o_awvalid), .mmio_axi4_0_aw_bits_id(o_awid),
        .mmio_axi4_0_aw_bits_addr(o_awaddr), .mmio_axi4_0_aw_bits_len(o_awlen), .mmio_axi4_0_aw_bits_size(o_awsize),
        .mmio_axi4_0_aw_bits_burst(o_awburst), .mmio_axi4_0_w_ready(o_wready), .mmio_axi4_0_w_valid(o_wvalid),
        .mmio_axi4_0_w_bits_data(o_wdata), .mmio_axi4_0_w_bits_strb(o_wstrb), .mmio_axi4_0_w_bits_last(o_wlast),
        .mmio_axi4_0_b_ready(o_bready), .mmio_axi4_0_b_valid(o_bvalid), .mmio_axi4_0_b_bits_id(o_bid), .mmio_axi4_0_b_bits_resp(o_bresp),
        .mmio_axi4_0_ar_ready(o_arready), .mmio_axi4_0_ar_valid(o_arvalid), .mmio_axi4_0_ar_bits_id(o_arid),
        .mmio_axi4_0_ar_bits_addr(o_araddr), .mmio_axi4_0_ar_bits_len(o_arlen), .mmio_axi4_0_ar_bits_size(o_arsize),
        .mmio_axi4_0_ar_bits_burst(o_arburst), .mmio_axi4_0_r_ready(o_rready), .mmio_axi4_0_r_valid(o_rvalid),
        .mmio_axi4_0_r_bits_id(o_rid), .mmio_axi4_0_r_bits_data(o_rdata), .mmio_axi4_0_r_bits_resp(o_rresp), .mmio_axi4_0_r_bits_last(o_rlast)
    );

    // mem: program @ 0x80000000
    logic mwr_fire; logic [AW-1:0] mwr_addr; logic [63:0] mwr_data;
    axi4_ram_bfm #(.DEPTH(1<<17), .BASE(64'h8000_0000), .INIT_HEX("/home/yashwanth/aurora_v1/boot/aurora_boot_rom64.hex")) mem (
        .clk(clk), .rst_n(rst_n),
        .awid(m_awid),.awaddr(m_awaddr),.awlen(m_awlen),.awsize(m_awsize),.awburst(m_awburst),.awvalid(m_awvalid),.awready(m_awready),
        .wdata(m_wdata),.wstrb(m_wstrb),.wlast(m_wlast),.wvalid(m_wvalid),.wready(m_wready),
        .bid(m_bid),.bresp(m_bresp),.bvalid(m_bvalid),.bready(m_bready),
        .arid(m_arid),.araddr(m_araddr),.arlen(m_arlen),.arsize(m_arsize),.arburst(m_arburst),.arvalid(m_arvalid),.arready(m_arready),
        .rid(m_rid),.rdata(m_rdata),.rresp(m_rresp),.rlast(m_rlast),.rvalid(m_rvalid),.rready(m_rready),
        .wr_fire(mwr_fire),.wr_addr(mwr_addr),.wr_data(mwr_data));

    // mmio: small RAM (reads default 0 => UART "not full"); UART writes captured via sideband
    logic owr_fire; logic [AW-1:0] owr_addr; logic [63:0] owr_data;
    axi4_ram_bfm #(.DEPTH(1<<16), .BASE(64'h0)) mmio (
        .clk(clk), .rst_n(rst_n),
        .awid(o_awid),.awaddr({1'b0,o_awaddr}),.awlen(o_awlen),.awsize(o_awsize),.awburst(o_awburst),.awvalid(o_awvalid),.awready(o_awready),
        .wdata(o_wdata),.wstrb(o_wstrb),.wlast(o_wlast),.wvalid(o_wvalid),.wready(o_wready),
        .bid(o_bid),.bresp(o_bresp),.bvalid(o_bvalid),.bready(o_bready),
        .arid(o_arid),.araddr({1'b0,o_araddr}),.arlen(o_arlen),.arsize(o_arsize),.arburst(o_arburst),.arvalid(o_arvalid),.arready(o_arready),
        .rid(o_rid),.rdata(o_rdata),.rresp(o_rresp),.rlast(o_rlast),.rvalid(o_rvalid),.rready(o_rready),
        .wr_fire(owr_fire),.wr_addr(owr_addr),.wr_data(owr_data));

    // UART capture: write to 0x20000000 (UART DATA) on mmio
    always @(posedge clk) if (rst_n && owr_fire && (owr_addr[30:0]==31'h2000_0000)) begin $write("%c", owr_data[7:0]); $fflush; end

    // progress + AXI activity probes
    integer cyc=0; logic smar, soar, soaw;
    always @(posedge clk) begin cyc<=cyc+1;
        if (cyc%200000==0) $display("[cyc %0d] running...", cyc);
        if (m_arvalid && m_arready && !smar) begin $display("[cyc %0d] MEM AR addr=0x%08h len=%0d", cyc, m_araddr, m_arlen); smar<=1; end
        if (o_arvalid && o_arready && !soar) begin $display("[cyc %0d] MMIO AR addr=0x%08h", cyc, o_araddr); soar<=1; end
        if (o_awvalid && o_awready && !soaw) begin $display("[cyc %0d] MMIO AW addr=0x%08h", cyc, o_awaddr); soaw<=1; end
        // reset state
        if (cyc==30 || cyc==500 || cyc==5000 || cyc==30000)
            $display("[cyc %0d] rst=%b ndreset=%b", cyc, rst, dbg_ndreset);
    end
endmodule
