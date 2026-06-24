// aurora_soc_top_chip.sv
// Aurora v1 — MACRO-BASED full-chip SoC top (minimal demo: 1 Rocket + 1 tensor).
//
// Replaces the flat aurora_soc_top.sv compute blocks with the two hardened macros:
//   * RocketAXITileTop  — RV64IMAC tile, clean single-beat AXI4 master, runs @ cpu_clk (33MHz).
//                         (coherence terminated + de-bursted inside; reset is ACTIVE-HIGH.)
//   * tensor_core_hard   — 4x4 systolic core, AXI4-Lite slave, runs @ fabric_clk (50MHz).
//
// Multi-clock: CPU domain 33MHz, fabric+tensor 50MHz. The Rocket tile exposes TWO AXI4
// masters (the TLXbar split inside RocketAXITileTop):
//   * mem_axi4_0_*  — cacheable memory path (Boot ROM @0x8000_0000 + SRAM @0x1000_0000),
//                     32-bit address. -> rocket_axi_wrapper -> axi_cdc_bridge -> crossbar M0.
//   * mmio_axi4_0_* — uncached MMIO path (UART/GPIO/Timer/Tensor @0x2/0x3/0x4/0x5xxx_xxxx),
//                     31-bit address (zero-extended). -> rocket_axi_wrapper -> axi_cdc_bridge
//                     -> crossbar M1.
// Each 64b master is widened to the 128b fabric and clock-crossed 33->50MHz. DMA is omitted
// in this minimal demo (the CPU stages tensor data directly). Crossbar stays 8x8; unused
// masters 2-7 are tied off, slaves 6-7 are error sinks.
//
// Address map (axi_crossbar.decode_address, addr[31:24]):
//   0x80 Boot ROM(S0)  0x10-13 SRAM(S1)  0x20 UART(S2)  0x30 GPIO(S3)
//   0x40 Timer(S4)     0x50 Tensor(S5)   else -> error sink

`timescale 1ns/1ps

module aurora_soc_top_chip #(
    parameter DATA_WIDTH = 128,
    parameter ADDR_WIDTH = 32,
    parameter ID_WIDTH   = 4
) (
    input  logic clk,
    input  logic rst_n,

    input  logic uart_rxd,
    output logic uart_txd,

    input  logic [31:0] gpio_in,
    output logic [31:0] gpio_out,
    output logic [31:0] gpio_oe,

    output logic timer_pwm,
    output logic global_irq
);

    // ============================================================
    // CLOCK & RESET  (cpu 33MHz, fabric 50MHz)
    // ============================================================
    logic cpu_clk, cpu_rst_n, fabric_clk, fabric_rst_n;

    clock_reset_controller clk_rst (
        .clk_in      (clk),
        .rst_in_n    (rst_n),
        .cpu_clk     (cpu_clk),
        .cpu_rst_n   (cpu_rst_n),
        .fabric_clk  (fabric_clk),
        .fabric_rst_n(fabric_rst_n)
    );

    // ============================================================
    // CROSSBAR BUS ARRAYS (8 masters x 8 slaves)
    // ============================================================
    localparam NM = 8;
    localparam NS = 8;

    logic [NM-1:0][ADDR_WIDTH-1:0]   xm_awaddr,  xm_araddr;
    logic [NM-1:0]                   xm_awvalid, xm_awready;
    logic [NM-1:0][DATA_WIDTH-1:0]   xm_wdata,   xm_rdata;
    logic [NM-1:0][DATA_WIDTH/8-1:0] xm_wstrb;
    logic [NM-1:0]                   xm_wvalid,  xm_wready;
    logic [NM-1:0]                   xm_bvalid,  xm_bready;
    logic [NM-1:0]                   xm_arvalid, xm_arready;
    logic [NM-1:0]                   xm_rvalid,  xm_rready;

    logic [NS-1:0][ADDR_WIDTH-1:0]   xs_awaddr,  xs_araddr;
    logic [NS-1:0]                   xs_awvalid, xs_awready;
    logic [NS-1:0][DATA_WIDTH-1:0]   xs_wdata,   xs_rdata;
    logic [NS-1:0][DATA_WIDTH/8-1:0] xs_wstrb;
    logic [NS-1:0]                   xs_wvalid,  xs_wready;
    logic [NS-1:0]                   xs_bvalid,  xs_bready;
    logic [NS-1:0]                   xs_arvalid, xs_arready;
    logic [NS-1:0]                   xs_rvalid,  xs_rready;

    // 32-bit register slaves sit on the 128b fabric: pick the active write lane
    // by awaddr[3:2], replicate read data across all four lanes.
    function automatic logic [31:0] lane32(logic [DATA_WIDTH-1:0] beat, logic [3:2] sel);
        lane32 = beat[32*sel +: 32];
    endfunction

    // ============================================================
    // ROCKET MACRO (RV64IMAC) — two AXI4 masters -> crossbar M0 (mem) + M1 (mmio)
    // Rocket(64b mem_axi4  @cpu_clk) -> rocket_axi_wrapper -> axi_cdc_bridge -> crossbar M0
    // Rocket(64b mmio_axi4 @cpu_clk) -> rocket_axi_wrapper -> axi_cdc_bridge -> crossbar M1
    // ============================================================
    // Rocket macro MEM master signals (cpu_clk domain, 32-bit addr)
    logic [ID_WIDTH-1:0]   rk_awid;   logic [ADDR_WIDTH-1:0] rk_awaddr; logic rk_awvalid, rk_awready;
    logic [63:0]           rk_wdata;  logic [7:0]            rk_wstrb;  logic rk_wvalid,  rk_wready; logic rk_wlast;
    logic [ID_WIDTH-1:0]   rk_bid;    logic [1:0]            rk_bresp;  logic rk_bvalid,  rk_bready;
    logic [ID_WIDTH-1:0]   rk_arid;   logic [ADDR_WIDTH-1:0] rk_araddr; logic rk_arvalid, rk_arready;
    logic [ID_WIDTH-1:0]   rk_rid;    logic [63:0]           rk_rdata;  logic [1:0] rk_rresp; logic rk_rlast, rk_rvalid, rk_rready;

    // Rocket macro MMIO master signals (cpu_clk domain, 31-bit addr from the macro)
    logic [ID_WIDTH-1:0]   mm_awid;   logic [30:0]           mm_awaddr; logic mm_awvalid, mm_awready;
    logic [63:0]           mm_wdata;  logic [7:0]            mm_wstrb;  logic mm_wvalid,  mm_wready; logic mm_wlast;
    logic [ID_WIDTH-1:0]   mm_bid;    logic [1:0]            mm_bresp;  logic mm_bvalid,  mm_bready;
    logic [ID_WIDTH-1:0]   mm_arid;   logic [30:0]           mm_araddr; logic mm_arvalid, mm_arready;
    logic [ID_WIDTH-1:0]   mm_rid;    logic [63:0]           mm_rdata;  logic [1:0] mm_rresp; logic mm_rlast, mm_rvalid, mm_rready;

    RocketAXITileTop u_rocket (
        .clock                    (cpu_clk),
        .reset                    (~cpu_rst_n),          // Chisel reset is ACTIVE-HIGH
        // AW
        .mem_axi4_0_aw_valid      (rk_awvalid),
        .mem_axi4_0_aw_ready      (rk_awready),
        .mem_axi4_0_aw_bits_id    (rk_awid),
        .mem_axi4_0_aw_bits_addr  (rk_awaddr),
        .mem_axi4_0_aw_bits_len   (),                    // single-beat (fragmented): ignored
        .mem_axi4_0_aw_bits_size  (),
        .mem_axi4_0_aw_bits_burst (),
        .mem_axi4_0_aw_bits_lock  (),
        .mem_axi4_0_aw_bits_cache (),
        .mem_axi4_0_aw_bits_prot  (),
        .mem_axi4_0_aw_bits_qos   (),
        // W
        .mem_axi4_0_w_valid       (rk_wvalid),
        .mem_axi4_0_w_ready       (rk_wready),
        .mem_axi4_0_w_bits_data   (rk_wdata),
        .mem_axi4_0_w_bits_strb   (rk_wstrb),
        .mem_axi4_0_w_bits_last   (rk_wlast),
        // B
        .mem_axi4_0_b_valid       (rk_bvalid),
        .mem_axi4_0_b_ready       (rk_bready),
        .mem_axi4_0_b_bits_id     (rk_bid),
        .mem_axi4_0_b_bits_resp   (rk_bresp),
        // AR
        .mem_axi4_0_ar_valid      (rk_arvalid),
        .mem_axi4_0_ar_ready      (rk_arready),
        .mem_axi4_0_ar_bits_id    (rk_arid),
        .mem_axi4_0_ar_bits_addr  (rk_araddr),
        .mem_axi4_0_ar_bits_len   (),
        .mem_axi4_0_ar_bits_size  (),
        .mem_axi4_0_ar_bits_burst (),
        .mem_axi4_0_ar_bits_lock  (),
        .mem_axi4_0_ar_bits_cache (),
        .mem_axi4_0_ar_bits_prot  (),
        .mem_axi4_0_ar_bits_qos   (),
        // R
        .mem_axi4_0_r_valid       (rk_rvalid),
        .mem_axi4_0_r_ready       (rk_rready),
        .mem_axi4_0_r_bits_id     (rk_rid),
        .mem_axi4_0_r_bits_data   (rk_rdata),
        .mem_axi4_0_r_bits_resp   (rk_rresp),
        .mem_axi4_0_r_bits_last   (rk_rlast),
        // ---- MMIO master (uncached: UART/GPIO/Timer/Tensor) ----
        // AW
        .mmio_axi4_0_aw_valid     (mm_awvalid),
        .mmio_axi4_0_aw_ready     (mm_awready),
        .mmio_axi4_0_aw_bits_id   (mm_awid),
        .mmio_axi4_0_aw_bits_addr (mm_awaddr),
        .mmio_axi4_0_aw_bits_len  (),
        .mmio_axi4_0_aw_bits_size (),
        .mmio_axi4_0_aw_bits_burst(),
        .mmio_axi4_0_aw_bits_lock (),
        .mmio_axi4_0_aw_bits_cache(),
        .mmio_axi4_0_aw_bits_prot (),
        .mmio_axi4_0_aw_bits_qos  (),
        // W
        .mmio_axi4_0_w_valid      (mm_wvalid),
        .mmio_axi4_0_w_ready      (mm_wready),
        .mmio_axi4_0_w_bits_data  (mm_wdata),
        .mmio_axi4_0_w_bits_strb  (mm_wstrb),
        .mmio_axi4_0_w_bits_last  (mm_wlast),
        // B
        .mmio_axi4_0_b_valid      (mm_bvalid),
        .mmio_axi4_0_b_ready      (mm_bready),
        .mmio_axi4_0_b_bits_id    (mm_bid),
        .mmio_axi4_0_b_bits_resp  (mm_bresp),
        // AR
        .mmio_axi4_0_ar_valid     (mm_arvalid),
        .mmio_axi4_0_ar_ready     (mm_arready),
        .mmio_axi4_0_ar_bits_id   (mm_arid),
        .mmio_axi4_0_ar_bits_addr (mm_araddr),
        .mmio_axi4_0_ar_bits_len  (),
        .mmio_axi4_0_ar_bits_size (),
        .mmio_axi4_0_ar_bits_burst(),
        .mmio_axi4_0_ar_bits_lock (),
        .mmio_axi4_0_ar_bits_cache(),
        .mmio_axi4_0_ar_bits_prot (),
        .mmio_axi4_0_ar_bits_qos  (),
        // R
        .mmio_axi4_0_r_valid      (mm_rvalid),
        .mmio_axi4_0_r_ready      (mm_rready),
        .mmio_axi4_0_r_bits_id    (mm_rid),
        .mmio_axi4_0_r_bits_data  (mm_rdata),
        .mmio_axi4_0_r_bits_resp  (mm_rresp),
        .mmio_axi4_0_r_bits_last  (mm_rlast)
    );
    // (mem/mmio w_bits_last are macro OUTPUTS = WLAST; single-beat, unused downstream — left
    //  macro-driven. Do NOT tie to a constant: that double-drives the macro output port.)

    // 64b Rocket -> 128b half-bus (cpu_clk domain). Wrapper-side fabric signals:
    logic [ID_WIDTH-1:0]   rw_awid;   logic [ADDR_WIDTH-1:0] rw_awaddr; logic rw_awvalid, rw_awready;
    logic [DATA_WIDTH-1:0] rw_wdata;  logic [DATA_WIDTH/8-1:0] rw_wstrb; logic rw_wvalid, rw_wready;
    logic [ID_WIDTH-1:0]   rw_bid;    logic rw_bvalid, rw_bready;
    logic [ID_WIDTH-1:0]   rw_arid;   logic [ADDR_WIDTH-1:0] rw_araddr; logic rw_arvalid, rw_arready;
    logic [ID_WIDTH-1:0]   rw_rid;    logic [DATA_WIDTH-1:0] rw_rdata;  logic rw_rvalid, rw_rready;

    rocket_axi_wrapper u_rocket_wrap (
        .clk       (cpu_clk),   .rst_n (cpu_rst_n),
        // Rocket side
        .r_awid(rk_awid), .r_awaddr(rk_awaddr), .r_awvalid(rk_awvalid), .r_awready(rk_awready),
        .r_wdata(rk_wdata), .r_wstrb(rk_wstrb), .r_wvalid(rk_wvalid), .r_wready(rk_wready),
        .r_bid(rk_bid), .r_bresp(rk_bresp), .r_bvalid(rk_bvalid), .r_bready(rk_bready),
        .r_arid(rk_arid), .r_araddr(rk_araddr), .r_arvalid(rk_arvalid), .r_arready(rk_arready),
        .r_rid(rk_rid), .r_rdata(rk_rdata), .r_rresp(rk_rresp), .r_rlast(rk_rlast),
        .r_rvalid(rk_rvalid), .r_rready(rk_rready),
        // fabric side (128b, cpu_clk)
        .f_awid(rw_awid), .f_awaddr(rw_awaddr), .f_awvalid(rw_awvalid), .f_awready(rw_awready),
        .f_wdata(rw_wdata), .f_wstrb(rw_wstrb), .f_wvalid(rw_wvalid), .f_wready(rw_wready),
        .f_bid(rw_bid), .f_bvalid(rw_bvalid), .f_bready(rw_bready),
        .f_arid(rw_arid), .f_araddr(rw_araddr), .f_arvalid(rw_arvalid), .f_arready(rw_arready),
        .f_rid(rw_rid), .f_rdata(rw_rdata), .f_rvalid(rw_rvalid), .f_rready(rw_rready)
    );

    // CDC 33MHz(cpu) -> 50MHz(fabric), into crossbar master 0.
    axi_cdc_bridge #(
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .ID_WIDTH(ID_WIDTH)
    ) u_cpu_cdc (
        .cpu_clk(cpu_clk), .cpu_rst_n(cpu_rst_n),
        .fabric_clk(fabric_clk), .fabric_rst_n(fabric_rst_n),
        // slave side (cpu domain) <- wrapper
        .s_axi_awid(rw_awid), .s_axi_awaddr(rw_awaddr), .s_axi_awvalid(rw_awvalid), .s_axi_awready(rw_awready),
        .s_axi_wdata(rw_wdata), .s_axi_wstrb(rw_wstrb), .s_axi_wvalid(rw_wvalid), .s_axi_wready(rw_wready),
        .s_axi_bid(rw_bid), .s_axi_bvalid(rw_bvalid), .s_axi_bready(rw_bready),
        .s_axi_arid(rw_arid), .s_axi_araddr(rw_araddr), .s_axi_arvalid(rw_arvalid), .s_axi_arready(rw_arready),
        .s_axi_rid(rw_rid), .s_axi_rdata(rw_rdata), .s_axi_rvalid(rw_rvalid), .s_axi_rready(rw_rready),
        // master side (fabric domain) -> crossbar master 0 (wstrb dropped at crossbar input)
        .m_axi_awid(), .m_axi_awaddr(xm_awaddr[0]), .m_axi_awvalid(xm_awvalid[0]), .m_axi_awready(xm_awready[0]),
        .m_axi_wdata(xm_wdata[0]), .m_axi_wstrb(xm_wstrb[0]), .m_axi_wvalid(xm_wvalid[0]), .m_axi_wready(xm_wready[0]),
        .m_axi_bid('0), .m_axi_bvalid(xm_bvalid[0]), .m_axi_bready(xm_bready[0]),
        .m_axi_arid(), .m_axi_araddr(xm_araddr[0]), .m_axi_arvalid(xm_arvalid[0]), .m_axi_arready(xm_arready[0]),
        .m_axi_rid('0), .m_axi_rdata(xm_rdata[0]), .m_axi_rvalid(xm_rvalid[0]), .m_axi_rready(xm_rready[0])
    );

    // ============================================================
    // MMIO master path: Rocket mmio_axi4 -> wrapper(64->128) -> CDC -> crossbar M1
    // ============================================================
    // 64b Rocket mmio -> 128b half-bus (cpu_clk). 31-bit macro addr zero-extended to 32.
    logic [ID_WIDTH-1:0]   mw_awid;   logic [ADDR_WIDTH-1:0] mw_awaddr; logic mw_awvalid, mw_awready;
    logic [DATA_WIDTH-1:0] mw_wdata;  logic [DATA_WIDTH/8-1:0] mw_wstrb; logic mw_wvalid, mw_wready;
    logic [ID_WIDTH-1:0]   mw_bid;    logic mw_bvalid, mw_bready;
    logic [ID_WIDTH-1:0]   mw_arid;   logic [ADDR_WIDTH-1:0] mw_araddr; logic mw_arvalid, mw_arready;
    logic [ID_WIDTH-1:0]   mw_rid;    logic [DATA_WIDTH-1:0] mw_rdata;  logic mw_rvalid, mw_rready;

    rocket_axi_wrapper u_rocket_wrap_mmio (
        .clk       (cpu_clk),   .rst_n (cpu_rst_n),
        // Rocket mmio side (31-bit addr zero-extended to 32)
        .r_awid(mm_awid), .r_awaddr({1'b0, mm_awaddr}), .r_awvalid(mm_awvalid), .r_awready(mm_awready),
        .r_wdata(mm_wdata), .r_wstrb(mm_wstrb), .r_wvalid(mm_wvalid), .r_wready(mm_wready),
        .r_bid(mm_bid), .r_bresp(mm_bresp), .r_bvalid(mm_bvalid), .r_bready(mm_bready),
        .r_arid(mm_arid), .r_araddr({1'b0, mm_araddr}), .r_arvalid(mm_arvalid), .r_arready(mm_arready),
        .r_rid(mm_rid), .r_rdata(mm_rdata), .r_rresp(mm_rresp), .r_rlast(mm_rlast),
        .r_rvalid(mm_rvalid), .r_rready(mm_rready),
        // fabric side (128b, cpu_clk)
        .f_awid(mw_awid), .f_awaddr(mw_awaddr), .f_awvalid(mw_awvalid), .f_awready(mw_awready),
        .f_wdata(mw_wdata), .f_wstrb(mw_wstrb), .f_wvalid(mw_wvalid), .f_wready(mw_wready),
        .f_bid(mw_bid), .f_bvalid(mw_bvalid), .f_bready(mw_bready),
        .f_arid(mw_arid), .f_araddr(mw_araddr), .f_arvalid(mw_arvalid), .f_arready(mw_arready),
        .f_rid(mw_rid), .f_rdata(mw_rdata), .f_rvalid(mw_rvalid), .f_rready(mw_rready)
    );

    // CDC 33MHz(cpu) -> 50MHz(fabric), into crossbar master 1.
    axi_cdc_bridge #(
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .ID_WIDTH(ID_WIDTH)
    ) u_mmio_cdc (
        .cpu_clk(cpu_clk), .cpu_rst_n(cpu_rst_n),
        .fabric_clk(fabric_clk), .fabric_rst_n(fabric_rst_n),
        // slave side (cpu domain) <- mmio wrapper
        .s_axi_awid(mw_awid), .s_axi_awaddr(mw_awaddr), .s_axi_awvalid(mw_awvalid), .s_axi_awready(mw_awready),
        .s_axi_wdata(mw_wdata), .s_axi_wstrb(mw_wstrb), .s_axi_wvalid(mw_wvalid), .s_axi_wready(mw_wready),
        .s_axi_bid(mw_bid), .s_axi_bvalid(mw_bvalid), .s_axi_bready(mw_bready),
        .s_axi_arid(mw_arid), .s_axi_araddr(mw_araddr), .s_axi_arvalid(mw_arvalid), .s_axi_arready(mw_arready),
        .s_axi_rid(mw_rid), .s_axi_rdata(mw_rdata), .s_axi_rvalid(mw_rvalid), .s_axi_rready(mw_rready),
        // master side (fabric domain) -> crossbar master 1
        .m_axi_awid(), .m_axi_awaddr(xm_awaddr[1]), .m_axi_awvalid(xm_awvalid[1]), .m_axi_awready(xm_awready[1]),
        .m_axi_wdata(xm_wdata[1]), .m_axi_wstrb(xm_wstrb[1]), .m_axi_wvalid(xm_wvalid[1]), .m_axi_wready(xm_wready[1]),
        .m_axi_bid('0), .m_axi_bvalid(xm_bvalid[1]), .m_axi_bready(xm_bready[1]),
        .m_axi_arid(), .m_axi_araddr(xm_araddr[1]), .m_axi_arvalid(xm_arvalid[1]), .m_axi_arready(xm_arready[1]),
        .m_axi_rid('0), .m_axi_rdata(xm_rdata[1]), .m_axi_rvalid(xm_rvalid[1]), .m_axi_rready(xm_rready[1])
    );

    // Tie off unused crossbar masters 2..7
    genvar mi;
    generate
        for (mi = 2; mi < NM; mi++) begin : UNUSED_MASTERS
            assign xm_awaddr[mi]  = '0;
            assign xm_awvalid[mi] = 1'b0;
            assign xm_wdata[mi]   = '0;
            assign xm_wstrb[mi]   = '0;
            assign xm_wvalid[mi]  = 1'b0;
            assign xm_bready[mi]  = 1'b0;
            assign xm_araddr[mi]  = '0;
            assign xm_arvalid[mi] = 1'b0;
            assign xm_rready[mi]  = 1'b0;
        end
    endgenerate

    // ============================================================
    // AXI CROSSBAR (fabric_clk)
    // ============================================================
    axi_crossbar #(
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .ID_WIDTH(ID_WIDTH),
        .NUM_MASTERS(NM), .NUM_SLAVES(NS)
    ) crossbar (
        .clk(fabric_clk), .rst_n(fabric_rst_n),
        .m_awaddr(xm_awaddr), .m_awvalid(xm_awvalid), .m_awready(xm_awready),
        .m_wdata(xm_wdata),   .m_wstrb(xm_wstrb),
        .m_wvalid(xm_wvalid), .m_wready(xm_wready),
        .m_bvalid(xm_bvalid), .m_bready(xm_bready),
        .m_araddr(xm_araddr), .m_arvalid(xm_arvalid), .m_arready(xm_arready),
        .m_rdata(xm_rdata),   .m_rvalid(xm_rvalid),   .m_rready(xm_rready),
        .s_awaddr(xs_awaddr), .s_awvalid(xs_awvalid), .s_awready(xs_awready),
        .s_wdata(xs_wdata),   .s_wstrb(xs_wstrb),
        .s_wvalid(xs_wvalid), .s_wready(xs_wready),
        .s_bvalid(xs_bvalid), .s_bready(xs_bready),
        .s_araddr(xs_araddr), .s_arvalid(xs_arvalid), .s_arready(xs_arready),
        .s_rdata(xs_rdata),   .s_rvalid(xs_rvalid),   .s_rready(xs_rready)
    );

    // ============================================================
    // BOOT ROM (S0 @ 0x80xx_xxxx) — Rocket resets here (0x8000_0000)
    // ============================================================
    boot_rom #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ROM_SIZE(1024)) boot_rom_inst (
        .clk(fabric_clk), .rst_n(fabric_rst_n),
        .s_axi_araddr(xs_araddr[0]), .s_axi_arvalid(xs_arvalid[0]), .s_axi_arready(xs_arready[0]),
        .s_axi_rdata(xs_rdata[0]),   .s_axi_rvalid(xs_rvalid[0]),   .s_axi_rready(xs_rready[0]),
        .s_axi_awaddr(xs_awaddr[0]), .s_axi_awvalid(xs_awvalid[0]), .s_axi_awready(xs_awready[0]),
        .s_axi_wdata(xs_wdata[0]),   .s_axi_wvalid(xs_wvalid[0]),   .s_axi_wready(xs_wready[0]),
        .s_axi_bvalid(xs_bvalid[0]), .s_axi_bready(xs_bready[0])
    );

    // ============================================================
    // SRAM (S1 @ 0x10xx_xxxx)
    // ============================================================
    // 2 KB (2 banks x 64 x 128b). Boot only stores ~512 B of A/B matrices here (tensor holds C),
    // and never uses the stack (sp is vestigial) -> 2 KB is ample. Kept small so the flop-based
    // array doesn't blow up ABC memory at chip synthesis (8 KB = 65k flops OOM-killed ABC).
    sram_bank_array #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .NUM_BANKS(2), .BANK_DEPTH(64)) sram (
        .clk(fabric_clk), .rst_n(fabric_rst_n),
        .awaddr(xs_awaddr[1]), .awvalid(xs_awvalid[1]), .awready(xs_awready[1]),
        .wdata(xs_wdata[1]),   .wstrb(xs_wstrb[1]),
        .wvalid(xs_wvalid[1]), .wready(xs_wready[1]),
        .bvalid(xs_bvalid[1]), .bready(xs_bready[1]),
        .araddr(xs_araddr[1]), .arvalid(xs_arvalid[1]), .arready(xs_arready[1]),
        .rdata(xs_rdata[1]),   .rvalid(xs_rvalid[1]),   .rready(xs_rready[1])
    );

    // ============================================================
    // UART (S2), GPIO (S3), TIMER (S4)
    // ============================================================
    logic uart_irq, gpio_irq, timer_irq_periph, tensor_irq;
    logic [31:0] uart_rdata32, gpio_rdata32, timer_rdata32, tensor_rdata32;

    uart #(.CLK_FREQ(50_000_000), .BAUD_RATE(115200)) uart_inst (
        .clk(fabric_clk), .rst_n(fabric_rst_n),
        .s_axi_awaddr(xs_awaddr[2]), .s_axi_awvalid(xs_awvalid[2]), .s_axi_awready(xs_awready[2]),
        .s_axi_wdata(lane32(xs_wdata[2], xs_awaddr[2][3:2])),
        .s_axi_wvalid(xs_wvalid[2]), .s_axi_wready(xs_wready[2]),
        .s_axi_bvalid(xs_bvalid[2]), .s_axi_bready(xs_bready[2]),
        .s_axi_araddr(xs_araddr[2]), .s_axi_arvalid(xs_arvalid[2]), .s_axi_arready(xs_arready[2]),
        .s_axi_rdata(uart_rdata32),  .s_axi_rvalid(xs_rvalid[2]),   .s_axi_rready(xs_rready[2]),
        .uart_rxd(uart_rxd), .uart_txd(uart_txd), .irq(uart_irq)
    );
    assign xs_rdata[2] = {4{uart_rdata32}};

    gpio #(.NUM_PINS(32)) gpio_inst (
        .clk(fabric_clk), .rst_n(fabric_rst_n),
        .s_axi_awaddr(xs_awaddr[3]), .s_axi_awvalid(xs_awvalid[3]), .s_axi_awready(xs_awready[3]),
        .s_axi_wdata(lane32(xs_wdata[3], xs_awaddr[3][3:2])),
        .s_axi_wvalid(xs_wvalid[3]), .s_axi_wready(xs_wready[3]),
        .s_axi_bvalid(xs_bvalid[3]), .s_axi_bready(xs_bready[3]),
        .s_axi_araddr(xs_araddr[3]), .s_axi_arvalid(xs_arvalid[3]), .s_axi_arready(xs_arready[3]),
        .s_axi_rdata(gpio_rdata32),  .s_axi_rvalid(xs_rvalid[3]),   .s_axi_rready(xs_rready[3]),
        .gpio_in(gpio_in), .gpio_out(gpio_out), .gpio_oe(gpio_oe), .irq(gpio_irq)
    );
    assign xs_rdata[3] = {4{gpio_rdata32}};

    timer #(.CLK_FREQ(50_000_000)) timer_inst (
        .clk(fabric_clk), .rst_n(fabric_rst_n),
        .s_axi_awaddr(xs_awaddr[4]), .s_axi_awvalid(xs_awvalid[4]), .s_axi_awready(xs_awready[4]),
        .s_axi_wdata(lane32(xs_wdata[4], xs_awaddr[4][3:2])),
        .s_axi_wvalid(xs_wvalid[4]), .s_axi_wready(xs_wready[4]),
        .s_axi_bvalid(xs_bvalid[4]), .s_axi_bready(xs_bready[4]),
        .s_axi_araddr(xs_araddr[4]), .s_axi_arvalid(xs_arvalid[4]), .s_axi_arready(xs_arready[4]),
        .s_axi_rdata(timer_rdata32), .s_axi_rvalid(xs_rvalid[4]),   .s_axi_rready(xs_rready[4]),
        .pwm_out(timer_pwm), .irq(timer_irq_periph)
    );
    assign xs_rdata[4] = {4{timer_rdata32}};

    // ============================================================
    // TENSOR MACRO (S5 @ 0x50xx_xxxx) — tensor_core_hard, AXI4-Lite slave
    // ============================================================
    tensor_core_hard u_tensor (
        .clk(fabric_clk), .rst_n(fabric_rst_n),
        .s_axi_awaddr(xs_awaddr[5]), .s_axi_awvalid(xs_awvalid[5]), .s_axi_awready(xs_awready[5]),
        .s_axi_wdata(lane32(xs_wdata[5], xs_awaddr[5][3:2])),
        .s_axi_wvalid(xs_wvalid[5]), .s_axi_wready(xs_wready[5]),
        .s_axi_bvalid(xs_bvalid[5]), .s_axi_bready(xs_bready[5]),
        .s_axi_araddr(xs_araddr[5]), .s_axi_arvalid(xs_arvalid[5]), .s_axi_arready(xs_arready[5]),
        .s_axi_rdata(tensor_rdata32), .s_axi_rvalid(xs_rvalid[5]),  .s_axi_rready(xs_rready[5]),
        .core_done_irq(tensor_irq)
    );
    assign xs_rdata[5] = {4{tensor_rdata32}};

    // ============================================================
    // SLAVES 6-7 — error sinks (accept all, return 0)
    // ============================================================
    logic [7:6] rsvd_bvalid, rsvd_rvalid;
    genvar si;
    generate
        for (si = 6; si < NS; si++) begin : ERR_SINK
            always_ff @(posedge fabric_clk or negedge fabric_rst_n) begin
                if (!fabric_rst_n) begin
                    rsvd_bvalid[si] <= 1'b0;
                    rsvd_rvalid[si] <= 1'b0;
                end else begin
                    if (xs_awvalid[si] && xs_wvalid[si]) rsvd_bvalid[si] <= 1'b1;
                    else if (rsvd_bvalid[si] && xs_bready[si]) rsvd_bvalid[si] <= 1'b0;
                    if (xs_arvalid[si]) rsvd_rvalid[si] <= 1'b1;
                    else if (rsvd_rvalid[si] && xs_rready[si]) rsvd_rvalid[si] <= 1'b0;
                end
            end
            assign xs_awready[si] = 1'b1;
            assign xs_wready[si]  = 1'b1;
            assign xs_bvalid[si]  = rsvd_bvalid[si];
            assign xs_arready[si] = 1'b1;
            assign xs_rdata[si]   = '0;
            assign xs_rvalid[si]  = rsvd_rvalid[si];
        end
    endgenerate

    // ============================================================
    // INTERRUPT CONTROLLER (observation only; Rocket IRQs tied off in the macro)
    // ============================================================
    logic [15:0] irq_sources;
    assign irq_sources = {
        11'h0,
        tensor_irq,        // [4]
        timer_irq_periph,  // [3]
        gpio_irq,          // [2]
        uart_irq,          // [1]
        1'b0               // [0]
    };

    interrupt_controller #(.NUM_IRQ(16)) irq_ctrl (
        .clk(fabric_clk), .rst_n(fabric_rst_n),
        .irq_sources(irq_sources), .clear(1'b0), .irq_out(global_irq)
    );

endmodule
