// cpu_cluster_top_picorv32.sv
// Aurora v1 — CPU Cluster (PicoRV32 fallback)
//
// Use this instead of cpu_cluster_top.sv when you want fast
// compilation without CVA6. PicoRV32 is 32-bit and cannot boot
// Linux, but compiles in ~30 seconds versus 3-5 minutes for CVA6.
//
// To switch:
//   In Makefile: use PICORV32_SRCS list instead of ALL_RTL
//   In that list: this file replaces cpu_cluster_top.sv
//   aurora_soc_top.sv instantiates cpu_cluster_top — same name,
//   so the top-level is unchanged.
//
// Architecture: FROZEN (same external interface as CVA6 version)

`timescale 1ns/1ps

/* verilator lint_off PINMISSING */
/* verilator lint_off WIDTH      */

module cpu_cluster_top #(
    parameter NUM_CORES  = 4,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 128,
    parameter ID_WIDTH   = 4,
    parameter [31:0] BOOT_ADDR = 32'h0000_0000
) (
    input  logic clk,
    input  logic rst_n,

    input  logic [NUM_CORES-1:0] irq,
    input  logic [NUM_CORES-1:0] timer_irq,

    output logic [NUM_CORES-1:0][ID_WIDTH-1:0]    m_axi_awid,
    output logic [NUM_CORES-1:0][ADDR_WIDTH-1:0]  m_axi_awaddr,
    output logic [NUM_CORES-1:0][7:0]             m_axi_awlen,
    output logic [NUM_CORES-1:0][2:0]             m_axi_awsize,
    output logic [NUM_CORES-1:0][1:0]             m_axi_awburst,
    output logic [NUM_CORES-1:0]                  m_axi_awvalid,
    input  logic [NUM_CORES-1:0]                  m_axi_awready,

    output logic [NUM_CORES-1:0][DATA_WIDTH-1:0]  m_axi_wdata,
    output logic [NUM_CORES-1:0][15:0]            m_axi_wstrb,
    output logic [NUM_CORES-1:0]                  m_axi_wlast,
    output logic [NUM_CORES-1:0]                  m_axi_wvalid,
    input  logic [NUM_CORES-1:0]                  m_axi_wready,

    input  logic [NUM_CORES-1:0][ID_WIDTH-1:0]    m_axi_bid,
    input  logic [NUM_CORES-1:0][1:0]             m_axi_bresp,
    input  logic [NUM_CORES-1:0]                  m_axi_bvalid,
    output logic [NUM_CORES-1:0]                  m_axi_bready,

    output logic [NUM_CORES-1:0][ID_WIDTH-1:0]    m_axi_arid,
    output logic [NUM_CORES-1:0][ADDR_WIDTH-1:0]  m_axi_araddr,
    output logic [NUM_CORES-1:0][7:0]             m_axi_arlen,
    output logic [NUM_CORES-1:0][2:0]             m_axi_arsize,
    output logic [NUM_CORES-1:0][1:0]             m_axi_arburst,
    output logic [NUM_CORES-1:0]                  m_axi_arvalid,
    input  logic [NUM_CORES-1:0]                  m_axi_arready,

    input  logic [NUM_CORES-1:0][ID_WIDTH-1:0]    m_axi_rid,
    input  logic [NUM_CORES-1:0][DATA_WIDTH-1:0]  m_axi_rdata,
    input  logic [NUM_CORES-1:0][1:0]             m_axi_rresp,
    input  logic [NUM_CORES-1:0]                  m_axi_rlast,
    input  logic [NUM_CORES-1:0]                  m_axi_rvalid,
    output logic [NUM_CORES-1:0]                  m_axi_rready,

    output logic [NUM_CORES-1:0]       cpu_trap,
    output logic [NUM_CORES-1:0][31:0] cpu_pc
);

genvar g;
generate
    for (g = 0; g < NUM_CORES; g++) begin : CPU_CORE_GEN
        riscv_cpu_wrapper #(
            .ADDR_WIDTH ( ADDR_WIDTH ),
            .DATA_WIDTH ( DATA_WIDTH ),
            .ID_WIDTH   ( ID_WIDTH   ),
            .BOOT_ADDR  ( BOOT_ADDR  )
        ) cpu (
            .clk            ( clk               ),
            .rst_n          ( rst_n             ),
            .irq            ( irq[g]            ),
            .timer_irq      ( timer_irq[g]      ),
            .m_axi_awid     ( m_axi_awid[g]    ),
            .m_axi_awaddr   ( m_axi_awaddr[g]  ),
            .m_axi_awlen    ( m_axi_awlen[g]   ),
            .m_axi_awsize   ( m_axi_awsize[g]  ),
            .m_axi_awburst  ( m_axi_awburst[g] ),
            .m_axi_awvalid  ( m_axi_awvalid[g] ),
            .m_axi_awready  ( m_axi_awready[g] ),
            .m_axi_wdata    ( m_axi_wdata[g]   ),
            .m_axi_wstrb    ( m_axi_wstrb[g]   ),
            .m_axi_wlast    ( m_axi_wlast[g]   ),
            .m_axi_wvalid   ( m_axi_wvalid[g]  ),
            .m_axi_wready   ( m_axi_wready[g]  ),
            .m_axi_bid      ( m_axi_bid[g]     ),
            .m_axi_bresp    ( m_axi_bresp[g]   ),
            .m_axi_bvalid   ( m_axi_bvalid[g]  ),
            .m_axi_bready   ( m_axi_bready[g]  ),
            .m_axi_arid     ( m_axi_arid[g]    ),
            .m_axi_araddr   ( m_axi_araddr[g]  ),
            .m_axi_arlen    ( m_axi_arlen[g]   ),
            .m_axi_arsize   ( m_axi_arsize[g]  ),
            .m_axi_arburst  ( m_axi_arburst[g] ),
            .m_axi_arvalid  ( m_axi_arvalid[g] ),
            .m_axi_arready  ( m_axi_arready[g] ),
            .m_axi_rid      ( m_axi_rid[g]     ),
            .m_axi_rdata    ( m_axi_rdata[g]   ),
            .m_axi_rresp    ( m_axi_rresp[g]   ),
            .m_axi_rlast    ( m_axi_rlast[g]   ),
            .m_axi_rvalid   ( m_axi_rvalid[g]  ),
            .m_axi_rready   ( m_axi_rready[g]  ),
            .debug_req_i    ( 1'b0             ),
            .debug_gnt_o    (                  ),
            .debug_rvalid_o (                  ),
            .cpu_trap       ( cpu_trap[g]       ),
            .cpu_pc         ( cpu_pc[g]         )
        );
    end
endgenerate

endmodule
