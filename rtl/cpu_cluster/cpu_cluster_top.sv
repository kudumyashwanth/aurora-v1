// cpu_cluster_top.sv
// Aurora v1 — CPU Cluster Top
//
// Instantiates 4 independent CVA6 64-bit RISC-V cores.
// Each core connects directly to a crossbar master port (0-3).
// No cache coherency — matches Aurora v1 frozen architecture.
//
// Architecture: FROZEN — 4 cores, 100 MHz

`timescale 1ns/1ps

/* verilator lint_off PINMISSING */
/* verilator lint_off WIDTH      */
/* verilator lint_off NULLPORT   */

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
    output logic [NUM_CORES-1:0]                  m_axi_rready
);

genvar g;
generate
    for (g = 0; g < NUM_CORES; g++) begin : CPU_CORE_GEN
        cva6_axi_wrapper #(
            .AURORA_AW ( ADDR_WIDTH     ),
            .AURORA_DW ( DATA_WIDTH     ),
            .AURORA_IW ( ID_WIDTH       ),
            .BOOT_ADDR ( 64'(BOOT_ADDR) ),
            .HART_ID   ( 64'(g)         )
        ) cpu (
            .clk            ( clk               ),
            .rst_n          ( rst_n             ),
            .irq            ( irq[g]            ),
            .timer_irq      ( timer_irq[g]      ),
            .ipi            ( 1'b0              ),
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
            .m_axi_rready   ( m_axi_rready[g]  )
        );
    end
endgenerate

endmodule
