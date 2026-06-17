// riscv_cpu_wrapper.sv
// Aurora v1 — RISC-V CPU Wrapper
// Integrates picorv32_core + cpu_mem_bridge into a single AXI4 master.
// Self-contained: no external IP required.

`timescale 1ns/1ps

module riscv_cpu_wrapper #(
    parameter ADDR_WIDTH    = 32,
    parameter DATA_WIDTH    = 128,
    parameter ID_WIDTH      = 4,
    parameter [31:0] BOOT_ADDR = 32'h0000_0000  // Boot ROM base
) (
    input  logic clk,
    input  logic rst_n,

    // Interrupts (IRQ line from interrupt controller)
    input  logic irq,
    input  logic timer_irq,

    // AXI4 Master Interface (to crossbar, 128-bit)
    output logic [ID_WIDTH-1:0]    m_axi_awid,
    output logic [ADDR_WIDTH-1:0]  m_axi_awaddr,
    output logic [7:0]             m_axi_awlen,
    output logic [2:0]             m_axi_awsize,
    output logic [1:0]             m_axi_awburst,
    output logic                   m_axi_awvalid,
    input  logic                   m_axi_awready,

    output logic [DATA_WIDTH-1:0]  m_axi_wdata,
    output logic [15:0]            m_axi_wstrb,
    output logic                   m_axi_wlast,
    output logic                   m_axi_wvalid,
    input  logic                   m_axi_wready,

    input  logic [ID_WIDTH-1:0]    m_axi_bid,
    input  logic [1:0]             m_axi_bresp,
    input  logic                   m_axi_bvalid,
    output logic                   m_axi_bready,

    output logic [ID_WIDTH-1:0]    m_axi_arid,
    output logic [ADDR_WIDTH-1:0]  m_axi_araddr,
    output logic [7:0]             m_axi_arlen,
    output logic [2:0]             m_axi_arsize,
    output logic [1:0]             m_axi_arburst,
    output logic                   m_axi_arvalid,
    input  logic                   m_axi_arready,

    input  logic [ID_WIDTH-1:0]    m_axi_rid,
    input  logic [DATA_WIDTH-1:0]  m_axi_rdata,
    input  logic [1:0]             m_axi_rresp,
    input  logic                   m_axi_rlast,
    input  logic                   m_axi_rvalid,
    output logic                   m_axi_rready,

    // Debug / status
    input  logic  debug_req_i,
    output logic  debug_gnt_o,
    output logic  debug_rvalid_o,

    // Observable outputs for verification
    output logic        cpu_trap,
    output logic [31:0] cpu_pc
);

// -------------------------------------------------------
// Internal memory bus (PicoRV32 native 32-bit)
// -------------------------------------------------------
logic        mem_valid;
logic        mem_instr;
logic        mem_ready;
logic [31:0] mem_addr;
logic [31:0] mem_wdata;
logic [ 3:0] mem_wstrb;
logic [31:0] mem_rdata;

// IRQ vector — combine both interrupt lines into bit positions
logic [31:0] irq_vec;
assign irq_vec = {30'd0, timer_irq, irq};

// -------------------------------------------------------
// PicoRV32 Core (simplified version - only PROGADDR_RESET supported)
// -------------------------------------------------------
picorv32_core #(
    .PROGADDR_RESET (BOOT_ADDR)
) cpu (
    .clk       (clk),
    .resetn    (rst_n),
    .mem_valid (mem_valid),
    .mem_instr (mem_instr),
    .mem_ready (mem_ready),
    .mem_addr  (mem_addr),
    .mem_wdata (mem_wdata),
    .mem_wstrb (mem_wstrb),
    .mem_rdata (mem_rdata),
    .irq       (irq_vec),
    .eoi       (),
    .trap      (cpu_trap)
);

assign cpu_pc = mem_addr;  // approximate PC for waveform/debug

// -------------------------------------------------------
// Memory Bridge: 32-bit native → 128-bit AXI4
// -------------------------------------------------------
cpu_mem_bridge #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .AXI_WIDTH (DATA_WIDTH),
    .ID_WIDTH  (ID_WIDTH)
) bridge (
    .clk          (clk),
    .rst_n        (rst_n),
    // PicoRV32 side
    .cpu_mem_valid(mem_valid),
    .cpu_mem_instr(mem_instr),
    .cpu_mem_ready(mem_ready),
    .cpu_mem_addr (mem_addr),
    .cpu_mem_wdata(mem_wdata),
    .cpu_mem_wstrb(mem_wstrb),
    .cpu_mem_rdata(mem_rdata),
    // AXI4 side
    .m_axi_awid   (m_axi_awid),
    .m_axi_awaddr (m_axi_awaddr),
    .m_axi_awlen  (m_axi_awlen),
    .m_axi_awsize (m_axi_awsize),
    .m_axi_awburst(m_axi_awburst),
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awready(m_axi_awready),
    .m_axi_wdata  (m_axi_wdata),
    .m_axi_wstrb  (m_axi_wstrb),
    .m_axi_wlast  (m_axi_wlast),
    .m_axi_wvalid (m_axi_wvalid),
    .m_axi_wready (m_axi_wready),
    .m_axi_bid    (m_axi_bid),
    .m_axi_bresp  (m_axi_bresp),
    .m_axi_bvalid (m_axi_bvalid),
    .m_axi_bready (m_axi_bready),
    .m_axi_arid   (m_axi_arid),
    .m_axi_araddr (m_axi_araddr),
    .m_axi_arlen  (m_axi_arlen),
    .m_axi_arsize (m_axi_arsize),
    .m_axi_arburst(m_axi_arburst),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_arready(m_axi_arready),
    .m_axi_rid    (m_axi_rid),
    .m_axi_rdata  (m_axi_rdata),
    .m_axi_rresp  (m_axi_rresp),
    .m_axi_rlast  (m_axi_rlast),
    .m_axi_rvalid (m_axi_rvalid),
    .m_axi_rready (m_axi_rready)
);

// Debug tie-offs
assign debug_gnt_o    = debug_req_i;
assign debug_rvalid_o = 1'b0;

endmodule
