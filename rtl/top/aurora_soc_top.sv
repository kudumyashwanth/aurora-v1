// aurora_soc_top.sv
// Aurora v1 — Top-Level SoC Integration
// 4× PicoRV32 CPUs + 4× Tensor cores + Full peripheral set
// Architecture: FROZEN

`timescale 1ns/1ps

module aurora_soc_top #(
    parameter DATA_WIDTH = 128,
    parameter ADDR_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter NUM_CPU    = 4,
    parameter NUM_DMA    = 4
) (
    input  logic clk,
    input  logic rst_n,

    // UART
    input  logic uart_rxd,
    output logic uart_txd,

    // GPIO
    input  logic [31:0] gpio_in,
    output logic [31:0] gpio_out,
    output logic [31:0] gpio_oe,

    // Timer PWM
    output logic timer_pwm,

    // Global interrupt (to external debug / test monitoring)
    output logic global_irq
);

// ============================================================
// CLOCK & RESET
// ============================================================
logic cpu_clk,    cpu_rst_n;
logic fabric_clk, fabric_rst_n;

clock_reset_controller clk_rst (
    .clk_in     (clk),
    .rst_in_n   (rst_n),
    .cpu_clk    (cpu_clk),
    .cpu_rst_n  (cpu_rst_n),
    .fabric_clk (fabric_clk),
    .fabric_rst_n(fabric_rst_n)
);

// ============================================================
// IRQ LINES
// ============================================================
logic uart_irq, gpio_irq, timer_irq_periph;
logic [3:0] tensor_irq;
logic global_irq_int;

// ============================================================
// CROSSBAR BUS ARRAYS
// Masters  0-3: 4× CPU cores
// Masters  4-7: 4× DMA channels
// Slaves     0: Boot ROM   (0x0000_0000 – 0x0000_FFFF)
// Slaves     1: SRAM       (0x1000_0000 – 0x13FF_FFFF)
// Slaves     2: UART       (0x2000_0000 – 0x2000_00FF)
// Slaves     3: GPIO       (0x3000_0000 – 0x3000_00FF)
// Slaves     4: Timer      (0x4000_0000 – 0x4000_00FF)
// Slaves     5: Tensor     (0x5000_0000 – 0x5000_00FF)
// Slaves   6-7: (reserved)
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

// 32-bit register slaves (UART/GPIO/Timer/Tensor/DMA regs) sit on the
// 128-bit fabric: select the active write lane by awaddr[3:2], and
// replicate read data across all four lanes so any master lane sees it.
function automatic logic [31:0] lane32(logic [DATA_WIDTH-1:0] beat,
                                       logic [3:2] sel);
    lane32 = beat[32*sel +: 32];   // assignment style — Yosys-compatible
endfunction

// ============================================================
// AXI CDC BRIDGE  (CPU 100 MHz → Fabric 200 MHz)
// For simplicity: single bridge for all 4 CPUs via shared bus.
// In a real chip each CPU would have its own bridge; here they
// share one because Aurora v1 has no cache coherency anyway.
// Master 0 of crossbar carries the CDC-bridged CPU traffic.
// ============================================================

// Aggregate CPU traffic (simple round-robin mux not yet implemented —
// for now CPU-0 drives the CDC bridge; others tie-off in the cluster).
// The CPU cluster exposes per-core AXI masters; we connect them directly
// to crossbar masters 0-3 (no CDC needed if both domains use same clk
// in simulation; clock_reset_controller passes through clk_in).
// Full CDC would be needed if PLLs generate truly different clocks.

// Per-CPU AXI buses (fabric-side, after bridge)
logic [NUM_CPU-1:0][ID_WIDTH-1:0]    cpu_axi_awid;
logic [NUM_CPU-1:0][ADDR_WIDTH-1:0]  cpu_axi_awaddr;
logic [NUM_CPU-1:0][7:0]             cpu_axi_awlen;
logic [NUM_CPU-1:0][2:0]             cpu_axi_awsize;
logic [NUM_CPU-1:0][1:0]             cpu_axi_awburst;
logic [NUM_CPU-1:0]                  cpu_axi_awvalid;
logic [NUM_CPU-1:0]                  cpu_axi_awready;
logic [NUM_CPU-1:0][DATA_WIDTH-1:0]  cpu_axi_wdata;
logic [NUM_CPU-1:0][15:0]            cpu_axi_wstrb;
logic [NUM_CPU-1:0]                  cpu_axi_wlast;
logic [NUM_CPU-1:0]                  cpu_axi_wvalid;
logic [NUM_CPU-1:0]                  cpu_axi_wready;
logic [NUM_CPU-1:0][ID_WIDTH-1:0]    cpu_axi_bid;
logic [NUM_CPU-1:0][1:0]             cpu_axi_bresp;
logic [NUM_CPU-1:0]                  cpu_axi_bvalid;
logic [NUM_CPU-1:0]                  cpu_axi_bready;
logic [NUM_CPU-1:0][ID_WIDTH-1:0]    cpu_axi_arid;
logic [NUM_CPU-1:0][ADDR_WIDTH-1:0]  cpu_axi_araddr;
logic [NUM_CPU-1:0][7:0]             cpu_axi_arlen;
logic [NUM_CPU-1:0][2:0]             cpu_axi_arsize;
logic [NUM_CPU-1:0][1:0]             cpu_axi_arburst;
logic [NUM_CPU-1:0]                  cpu_axi_arvalid;
logic [NUM_CPU-1:0]                  cpu_axi_arready;
logic [NUM_CPU-1:0][ID_WIDTH-1:0]    cpu_axi_rid;
logic [NUM_CPU-1:0][DATA_WIDTH-1:0]  cpu_axi_rdata;
logic [NUM_CPU-1:0][1:0]             cpu_axi_rresp;
logic [NUM_CPU-1:0]                  cpu_axi_rlast;
logic [NUM_CPU-1:0]                  cpu_axi_rvalid;
logic [NUM_CPU-1:0]                  cpu_axi_rready;

// CPU trap & PC (for waveform visibility)
logic [NUM_CPU-1:0]       cpu_trap;
logic [NUM_CPU-1:0][31:0] cpu_pc;

// ============================================================
// CPU CLUSTER
// ============================================================
cpu_cluster_top #(
    .NUM_CORES  (NUM_CPU),
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .ID_WIDTH   (ID_WIDTH),
    .BOOT_ADDR  (32'h0000_0000)
) cpu_cluster (
    .clk            (cpu_clk),
    .rst_n          (cpu_rst_n),
    .irq            ({NUM_CPU{global_irq_int}}),
    .timer_irq      ({NUM_CPU{timer_irq_periph}}),
    .m_axi_awid     (cpu_axi_awid),
    .m_axi_awaddr   (cpu_axi_awaddr),
    .m_axi_awlen    (cpu_axi_awlen),
    .m_axi_awsize   (cpu_axi_awsize),
    .m_axi_awburst  (cpu_axi_awburst),
    .m_axi_awvalid  (cpu_axi_awvalid),
    .m_axi_awready  (cpu_axi_awready),
    .m_axi_wdata    (cpu_axi_wdata),
    .m_axi_wstrb    (cpu_axi_wstrb),
    .m_axi_wlast    (cpu_axi_wlast),
    .m_axi_wvalid   (cpu_axi_wvalid),
    .m_axi_wready   (cpu_axi_wready),
    .m_axi_bid      (cpu_axi_bid),
    .m_axi_bresp    (cpu_axi_bresp),
    .m_axi_bvalid   (cpu_axi_bvalid),
    .m_axi_bready   (cpu_axi_bready),
    .m_axi_arid     (cpu_axi_arid),
    .m_axi_araddr   (cpu_axi_araddr),
    .m_axi_arlen    (cpu_axi_arlen),
    .m_axi_arsize   (cpu_axi_arsize),
    .m_axi_arburst  (cpu_axi_arburst),
    .m_axi_arvalid  (cpu_axi_arvalid),
    .m_axi_arready  (cpu_axi_arready),
    .m_axi_rid      (cpu_axi_rid),
    .m_axi_rdata    (cpu_axi_rdata),
    .m_axi_rresp    (cpu_axi_rresp),
    .m_axi_rlast    (cpu_axi_rlast),
    .m_axi_rvalid   (cpu_axi_rvalid),
    .m_axi_rready   (cpu_axi_rready)
);

// Wire CPU cores to crossbar masters 0-3
// (Only awaddr/awvalid/araddr/arvalid/wdata/wvalid used by simple crossbar)
genvar ci;
generate
    for (ci = 0; ci < NUM_CPU; ci++) begin : CPU_XBAR_WIRE
        assign xm_awaddr[ci]  = cpu_axi_awaddr[ci];
        assign xm_awvalid[ci] = cpu_axi_awvalid[ci];
        assign cpu_axi_awready[ci] = xm_awready[ci];
        assign xm_wdata[ci]   = cpu_axi_wdata[ci];
        assign xm_wstrb[ci]   = cpu_axi_wstrb[ci];
        assign xm_wvalid[ci]  = cpu_axi_wvalid[ci];
        assign cpu_axi_wready[ci]  = xm_wready[ci];
        assign cpu_axi_bvalid[ci]  = xm_bvalid[ci];
        assign xm_bready[ci]  = cpu_axi_bready[ci];
        assign xm_araddr[ci]  = cpu_axi_araddr[ci];
        assign xm_arvalid[ci] = cpu_axi_arvalid[ci];
        assign cpu_axi_arready[ci] = xm_arready[ci];
        assign cpu_axi_rdata[ci]   = xm_rdata[ci];
        assign cpu_axi_rvalid[ci]  = xm_rvalid[ci];
        assign xm_rready[ci]  = cpu_axi_rready[ci];
        // unused AXI4 extended signals (not needed by simple crossbar)
        assign cpu_axi_bid[ci]  = '0;
        assign cpu_axi_bresp[ci]= '0;
        assign cpu_axi_rid[ci]  = '0;
        assign cpu_axi_rresp[ci]= '0;
        assign cpu_axi_rlast[ci]= 1'b1;
    end
endgenerate

// ============================================================
// DMA ENGINE (masters 4-7)
// ============================================================
logic [NUM_DMA-1:0] dma_irq;

// Per-DMA AXI buses
logic [NUM_DMA-1:0][ADDR_WIDTH-1:0] dma_araddr, dma_awaddr;
logic [NUM_DMA-1:0]                 dma_arvalid, dma_awvalid;
logic [NUM_DMA-1:0]                 dma_arready, dma_awready;
logic [NUM_DMA-1:0][DATA_WIDTH-1:0] dma_wdata, dma_rdata;
logic [NUM_DMA-1:0]                 dma_wvalid, dma_wready;
logic [NUM_DMA-1:0]                 dma_bvalid, dma_bready;
logic [NUM_DMA-1:0]                 dma_rvalid, dma_rready;
// DMA control (from slave port — fabric register writes)
// Using crossbar slave 6 for DMA registers (address decode handled in crossbar)
// For simplicity: DMA gets its registers via a side-channel (direct reg writes)
// Full integration would add DMA as both master and slave.

genvar di;
generate
    for (di = 0; di < NUM_DMA; di++) begin : DMA_GEN
        dma_engine_complete #(
            .ADDR_WIDTH (ADDR_WIDTH),
            .DATA_WIDTH (DATA_WIDTH),
            .CHANNEL_ID (di)
        ) dma (
            .clk          (fabric_clk),
            .rst_n        (fabric_rst_n),
            // Register interface — slave 6 of the crossbar
            .s_axil_awaddr  (xs_awaddr[6]),
            .s_axil_awvalid (dma_s_awvalid[di]),
            .s_axil_awready (dma_s_awready[di]),
            .s_axil_wdata   (lane32(xs_wdata[6], xs_awaddr[6][3:2])),
            .s_axil_wvalid  (dma_s_wvalid[di]),
            .s_axil_wready  (dma_s_wready[di]),
            .s_axil_bvalid  (dma_s_bvalid[di]),
            .s_axil_bready  (dma_s_bready[di]),
            .s_axil_araddr  (xs_araddr[6]),
            .s_axil_arvalid (dma_s_arvalid[di]),
            .s_axil_arready (dma_s_arready[di]),
            .s_axil_rdata   (dma_s_rdata[di]),
            .s_axil_rvalid  (dma_s_rvalid[di]),
            .s_axil_rready  (dma_s_rready[di]),
            // AXI master (data movement)
            .m_axi_araddr  (dma_araddr[di]),
            .m_axi_arlen   (),
            .m_axi_arsize  (),
            .m_axi_arvalid (dma_arvalid[di]),
            .m_axi_arready (dma_arready[di]),
            .m_axi_rdata   (dma_rdata[di]),
            .m_axi_rlast   (1'b1),
            .m_axi_rvalid  (dma_rvalid[di]),
            .m_axi_rready  (dma_rready[di]),
            .m_axi_awaddr  (dma_awaddr[di]),
            .m_axi_awlen   (),
            .m_axi_awsize  (),
            .m_axi_awvalid (dma_awvalid[di]),
            .m_axi_awready (dma_awready[di]),
            .m_axi_wdata   (dma_wdata[di]),
            .m_axi_wlast   (),
            .m_axi_wvalid  (dma_wvalid[di]),
            .m_axi_wready  (dma_wready[di]),
            .m_axi_bvalid  (dma_bvalid[di]),
            .m_axi_bready  (dma_bready[di]),
            .irq           (dma_irq[di])
        );

        // Wire DMA to crossbar masters 4-7
        assign xm_araddr [NUM_CPU + di] = dma_araddr[di];
        assign xm_arvalid[NUM_CPU + di] = dma_arvalid[di];
        assign dma_arready[di]          = xm_arready[NUM_CPU + di];
        assign dma_rdata[di]            = xm_rdata[NUM_CPU + di];
        assign dma_rvalid[di]           = xm_rvalid[NUM_CPU + di];
        assign xm_rready [NUM_CPU + di] = dma_rready[di];

        assign xm_awaddr [NUM_CPU + di] = dma_awaddr[di];
        assign xm_awvalid[NUM_CPU + di] = dma_awvalid[di];
        assign dma_awready[di]          = xm_awready[NUM_CPU + di];
        assign xm_wdata  [NUM_CPU + di] = dma_wdata[di];
        assign xm_wstrb  [NUM_CPU + di] = '1;   // DMA always writes full beats
        assign xm_wvalid [NUM_CPU + di] = dma_wvalid[di];
        assign dma_wready[di]           = xm_wready[NUM_CPU + di];
        assign dma_bvalid[di]           = xm_bvalid[NUM_CPU + di];
        assign xm_bready [NUM_CPU + di] = dma_bready[di];
    end
endgenerate

// ============================================================
// AXI CROSSBAR
// ============================================================
axi_crossbar #(
    .DATA_WIDTH  (DATA_WIDTH),
    .ADDR_WIDTH  (ADDR_WIDTH),
    .ID_WIDTH    (ID_WIDTH),
    .NUM_MASTERS (NM),
    .NUM_SLAVES  (NS)
) crossbar (
    .clk        (fabric_clk),
    .rst_n      (fabric_rst_n),
    .m_awaddr   (xm_awaddr),  .m_awvalid(xm_awvalid), .m_awready(xm_awready),
    .m_wdata    (xm_wdata),   .m_wstrb  (xm_wstrb),
    .m_wvalid   (xm_wvalid),  .m_wready (xm_wready),
    .m_bvalid   (xm_bvalid),  .m_bready (xm_bready),
    .m_araddr   (xm_araddr),  .m_arvalid(xm_arvalid), .m_arready(xm_arready),
    .m_rdata    (xm_rdata),   .m_rvalid (xm_rvalid),  .m_rready (xm_rready),
    .s_awaddr   (xs_awaddr),  .s_awvalid(xs_awvalid), .s_awready(xs_awready),
    .s_wdata    (xs_wdata),   .s_wstrb  (xs_wstrb),
    .s_wvalid   (xs_wvalid),  .s_wready (xs_wready),
    .s_bvalid   (xs_bvalid),  .s_bready (xs_bready),
    .s_araddr   (xs_araddr),  .s_arvalid(xs_arvalid), .s_arready(xs_arready),
    .s_rdata    (xs_rdata),   .s_rvalid (xs_rvalid),  .s_rready (xs_rready)
);

// ============================================================
// BOOT ROM (Slave 0 – 0x0000_0000)
// ============================================================
boot_rom #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ROM_SIZE  (1024)
) boot_rom_inst (
    .clk          (fabric_clk),
    .rst_n        (fabric_rst_n),
    .s_axi_araddr (xs_araddr[0]),  .s_axi_arvalid(xs_arvalid[0]), .s_axi_arready(xs_arready[0]),
    .s_axi_rdata  (xs_rdata[0]),   .s_axi_rvalid (xs_rvalid[0]),  .s_axi_rready (xs_rready[0]),
    .s_axi_awaddr (xs_awaddr[0]),  .s_axi_awvalid(xs_awvalid[0]), .s_axi_awready(xs_awready[0]),
    .s_axi_wdata  (xs_wdata[0]),   .s_axi_wvalid (xs_wvalid[0]),  .s_axi_wready (xs_wready[0]),
    .s_axi_bvalid (xs_bvalid[0]),  .s_axi_bready (xs_bready[0])
);

// ============================================================
// SRAM BANK ARRAY (Slave 1 – 0x1000_0000)
// ============================================================
sram_bank_array #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .NUM_BANKS (2),
    .BANK_DEPTH(256)
) sram (
    .clk    (fabric_clk),
    .rst_n  (fabric_rst_n),
    .awaddr (xs_awaddr[1]),  .awvalid(xs_awvalid[1]), .awready(xs_awready[1]),
    .wdata  (xs_wdata[1]),   .wstrb  (xs_wstrb[1]),
    .wvalid (xs_wvalid[1]),  .wready (xs_wready[1]),
    .bvalid (xs_bvalid[1]),  .bready (xs_bready[1]),
    .araddr (xs_araddr[1]),  .arvalid(xs_arvalid[1]), .arready(xs_arready[1]),
    .rdata  (xs_rdata[1]),   .rvalid (xs_rvalid[1]),  .rready (xs_rready[1])
);

// ============================================================
// UART (Slave 2 – 0x2000_0000)
// ============================================================
logic [31:0] uart_rdata32;

uart #(
    .CLK_FREQ (200_000_000),
    .BAUD_RATE(115200)
) uart_inst (
    .clk          (fabric_clk),
    .rst_n        (fabric_rst_n),
    .s_axi_awaddr (xs_awaddr[2]),      .s_axi_awvalid(xs_awvalid[2]),  .s_axi_awready(xs_awready[2]),
    .s_axi_wdata  (lane32(xs_wdata[2], xs_awaddr[2][3:2])),
    .s_axi_wvalid (xs_wvalid[2]),      .s_axi_wready (xs_wready[2]),
    .s_axi_bvalid (xs_bvalid[2]),      .s_axi_bready (xs_bready[2]),
    .s_axi_araddr (xs_araddr[2]),      .s_axi_arvalid(xs_arvalid[2]),  .s_axi_arready(xs_arready[2]),
    .s_axi_rdata  (uart_rdata32),      .s_axi_rvalid (xs_rvalid[2]),   .s_axi_rready (xs_rready[2]),
    .uart_rxd     (uart_rxd),
    .uart_txd     (uart_txd),
    .irq          (uart_irq)
);
assign xs_rdata[2] = {4{uart_rdata32}};

// ============================================================
// GPIO (Slave 3 – 0x3000_0000)
// ============================================================
logic [31:0] gpio_rdata32;

gpio #(
    .NUM_PINS(32)
) gpio_inst (
    .clk          (fabric_clk),
    .rst_n        (fabric_rst_n),
    .s_axi_awaddr (xs_awaddr[3]),      .s_axi_awvalid(xs_awvalid[3]),  .s_axi_awready(xs_awready[3]),
    .s_axi_wdata  (lane32(xs_wdata[3], xs_awaddr[3][3:2])),
    .s_axi_wvalid (xs_wvalid[3]),      .s_axi_wready (xs_wready[3]),
    .s_axi_bvalid (xs_bvalid[3]),      .s_axi_bready (xs_bready[3]),
    .s_axi_araddr (xs_araddr[3]),      .s_axi_arvalid(xs_arvalid[3]),  .s_axi_arready(xs_arready[3]),
    .s_axi_rdata  (gpio_rdata32),      .s_axi_rvalid (xs_rvalid[3]),   .s_axi_rready (xs_rready[3]),
    .gpio_in      (gpio_in),
    .gpio_out     (gpio_out),
    .gpio_oe      (gpio_oe),
    .irq          (gpio_irq)
);
assign xs_rdata[3] = {4{gpio_rdata32}};

// ============================================================
// TIMER (Slave 4 – 0x4000_0000)
// ============================================================
logic [31:0] timer_rdata32;

timer #(
    .CLK_FREQ(200_000_000)
) timer_inst (
    .clk          (fabric_clk),
    .rst_n        (fabric_rst_n),
    .s_axi_awaddr (xs_awaddr[4]),      .s_axi_awvalid(xs_awvalid[4]),  .s_axi_awready(xs_awready[4]),
    .s_axi_wdata  (lane32(xs_wdata[4], xs_awaddr[4][3:2])),
    .s_axi_wvalid (xs_wvalid[4]),      .s_axi_wready (xs_wready[4]),
    .s_axi_bvalid (xs_bvalid[4]),      .s_axi_bready (xs_bready[4]),
    .s_axi_araddr (xs_araddr[4]),      .s_axi_arvalid(xs_arvalid[4]),  .s_axi_arready(xs_arready[4]),
    .s_axi_rdata  (timer_rdata32),     .s_axi_rvalid (xs_rvalid[4]),   .s_axi_rready (xs_rready[4]),
    .pwm_out      (timer_pwm),
    .irq          (timer_irq_periph)
);
assign xs_rdata[4] = {4{timer_rdata32}};

// ============================================================
// TENSOR CLUSTER (Slave 5 – 0x5000_0000)
// AXI wdata[31:0] carries 32-bit writes (control or buffer lane).
// Buffer lane accumulation and matrix loading handled inside.
// ============================================================
logic [31:0] tensor_rdata32;

tensor_cluster_top #(
    .NUM_CORES (4),
    .DATA_WIDTH(16),
    .SIZE      (16)
) tensor_cluster (
    .clk           (fabric_clk),
    .rst_n         (fabric_rst_n),
    .s_axi_awaddr  (xs_awaddr[5][31:0]),  .s_axi_awvalid(xs_awvalid[5]),  .s_axi_awready(xs_awready[5]),
    .s_axi_wdata   (lane32(xs_wdata[5], xs_awaddr[5][3:2])),
    .s_axi_wvalid  (xs_wvalid[5]),        .s_axi_wready (xs_wready[5]),
    .s_axi_bvalid  (xs_bvalid[5]),        .s_axi_bready (xs_bready[5]),
    .s_axi_araddr  (xs_araddr[5][31:0]),  .s_axi_arvalid(xs_arvalid[5]),  .s_axi_arready(xs_arready[5]),
    .s_axi_rdata   (tensor_rdata32),      .s_axi_rvalid (xs_rvalid[5]),   .s_axi_rready (xs_rready[5]),
    .core_done_irq (tensor_irq)
);
assign xs_rdata[5] = {4{tensor_rdata32}};

// ============================================================
// DMA CONTROL REGISTERS (Slave 6 – 0x6000_0000)
// Channel select: addr[9:8]. Each channel occupies 0x100 bytes.
//   Ch0: 0x6000_0000-0x60_00FF
//   Ch1: 0x6000_0100-0x60_01FF
//   Ch2: 0x6000_0200-0x60_02FF
//   Ch3: 0x6000_0300-0x60_03FF
// ============================================================
logic [NUM_DMA-1:0] dma_s_awvalid, dma_s_awready;
logic [NUM_DMA-1:0] dma_s_wvalid,  dma_s_wready;
logic [NUM_DMA-1:0] dma_s_bvalid,  dma_s_bready;
logic [NUM_DMA-1:0] dma_s_arvalid, dma_s_arready;
logic [NUM_DMA-1:0] dma_s_rvalid,  dma_s_rready;
logic [NUM_DMA-1:0][31:0] dma_s_rdata;

// Crossbar slave 6 write response: OR of whichever channel responds
assign xs_awready[6] = |dma_s_awready;
assign xs_wready[6]  = |dma_s_wready;
assign xs_bvalid[6]  = |dma_s_bvalid;
assign xs_arready[6] = |dma_s_arready;
assign xs_rvalid[6]  = |dma_s_rvalid;
// Mux rdata from the responding channel (addr[9:8] selects channel)
assign xs_rdata[6]   = {4{dma_s_rdata[xs_araddr[6][9:8]]}};

genvar di2;
generate
    for (di2 = 0; di2 < NUM_DMA; di2++) begin : DMA_REG_DEMUX
        // Steer slave-6 traffic to this DMA channel when addr[9:8] matches
        assign dma_s_awvalid[di2] = xs_awvalid[6] && (xs_awaddr[6][9:8] == di2[1:0]);
        assign dma_s_wvalid[di2]  = xs_wvalid[6]  && (xs_awaddr[6][9:8] == di2[1:0]);
        assign dma_s_bready[di2]  = xs_bready[6]  && (xs_awaddr[6][9:8] == di2[1:0]);
        assign dma_s_arvalid[di2] = xs_arvalid[6] && (xs_araddr[6][9:8] == di2[1:0]);
        assign dma_s_rready[di2]  = xs_rready[6]  && (xs_araddr[6][9:8] == di2[1:0]);
    end
endgenerate

// ============================================================
// RESERVED SLAVE 7 — error sink (accepts all, returns 0)
// Proper bvalid/rvalid handshake prevents master deadlock.
// ============================================================
logic rsvd_bvalid, rsvd_rvalid;

always_ff @(posedge fabric_clk or negedge fabric_rst_n) begin
    if (!fabric_rst_n) begin
        rsvd_bvalid <= 1'b0;
        rsvd_rvalid <= 1'b0;
    end else begin
        if (xs_awvalid[7] && xs_wvalid[7])
            rsvd_bvalid <= 1'b1;
        else if (rsvd_bvalid && xs_bready[7])
            rsvd_bvalid <= 1'b0;

        if (xs_arvalid[7])
            rsvd_rvalid <= 1'b1;
        else if (rsvd_rvalid && xs_rready[7])
            rsvd_rvalid <= 1'b0;
    end
end

assign xs_awready[7] = 1'b1;
assign xs_wready[7]  = 1'b1;
assign xs_bvalid[7]  = rsvd_bvalid;
assign xs_arready[7] = 1'b1;
assign xs_rdata[7]   = '0;
assign xs_rvalid[7]  = rsvd_rvalid;

// ============================================================
// INTERRUPT CONTROLLER
// ============================================================
logic [15:0] irq_sources;
assign irq_sources = {
    4'h0,                // [15:12] reserved
    dma_irq,             // [11:8]  DMA channel 3-0
    tensor_irq,          // [7:4]   Tensor core 3-0
    timer_irq_periph,    // [3]
    gpio_irq,            // [2]
    uart_irq,            // [1]
    1'b0                 // [0]     reserved
};

interrupt_controller #(.NUM_IRQ(16)) irq_ctrl (
    .clk        (cpu_clk),
    .rst_n      (cpu_rst_n),
    .irq_sources(irq_sources),
    .clear      (1'b0),
    .irq_out    (global_irq_int)
);

assign global_irq = global_irq_int;

endmodule
