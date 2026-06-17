// cpu_cluster_stub.v — Black-box stub for GDSII synthesis
// Replaces the full CVA6-based cpu_cluster_top when synthesizing
// the SoC fabric without the CPU cores.  The CVA6 cores are
// intended to be integrated as pre-hardened macros at the top level.

module cpu_cluster_top #(
    parameter NUM_CORES  = 4,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 128,
    parameter ID_WIDTH   = 4,
    parameter [31:0] BOOT_ADDR = 32'h0000_0000
) (
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire [NUM_CORES-1:0]          irq,
    input  wire [NUM_CORES-1:0]          timer_irq,
    output wire [NUM_CORES*ID_WIDTH-1:0]    m_axi_awid,
    output wire [NUM_CORES*ADDR_WIDTH-1:0]  m_axi_awaddr,
    output wire [NUM_CORES*8-1:0]           m_axi_awlen,
    output wire [NUM_CORES*3-1:0]           m_axi_awsize,
    output wire [NUM_CORES*2-1:0]           m_axi_awburst,
    output wire [NUM_CORES-1:0]             m_axi_awvalid,
    input  wire [NUM_CORES-1:0]             m_axi_awready,
    output wire [NUM_CORES*DATA_WIDTH-1:0]  m_axi_wdata,
    output wire [NUM_CORES*16-1:0]          m_axi_wstrb,
    output wire [NUM_CORES-1:0]             m_axi_wlast,
    output wire [NUM_CORES-1:0]             m_axi_wvalid,
    input  wire [NUM_CORES-1:0]             m_axi_wready,
    input  wire [NUM_CORES*ID_WIDTH-1:0]    m_axi_bid,
    input  wire [NUM_CORES*2-1:0]           m_axi_bresp,
    input  wire [NUM_CORES-1:0]             m_axi_bvalid,
    output wire [NUM_CORES-1:0]             m_axi_bready,
    output wire [NUM_CORES*ID_WIDTH-1:0]    m_axi_arid,
    output wire [NUM_CORES*ADDR_WIDTH-1:0]  m_axi_araddr,
    output wire [NUM_CORES*8-1:0]           m_axi_arlen,
    output wire [NUM_CORES*3-1:0]           m_axi_arsize,
    output wire [NUM_CORES*2-1:0]           m_axi_arburst,
    output wire [NUM_CORES-1:0]             m_axi_arvalid,
    input  wire [NUM_CORES-1:0]             m_axi_arready,
    input  wire [NUM_CORES*ID_WIDTH-1:0]    m_axi_rid,
    input  wire [NUM_CORES*DATA_WIDTH-1:0]  m_axi_rdata,
    input  wire [NUM_CORES*2-1:0]           m_axi_rresp,
    input  wire [NUM_CORES-1:0]             m_axi_rlast,
    input  wire [NUM_CORES-1:0]             m_axi_rvalid,
    output wire [NUM_CORES-1:0]             m_axi_rready
);

// All outputs driven to 0 — replaced by pre-hardened CVA6 macro at integration
assign m_axi_awid     = {(NUM_CORES*ID_WIDTH){1'b0}};
assign m_axi_awaddr   = {(NUM_CORES*ADDR_WIDTH){1'b0}};
assign m_axi_awlen    = {(NUM_CORES*8){1'b0}};
assign m_axi_awsize   = {(NUM_CORES*3){1'b0}};
assign m_axi_awburst  = {(NUM_CORES*2){1'b0}};
assign m_axi_awvalid  = {NUM_CORES{1'b0}};
assign m_axi_wdata    = {(NUM_CORES*DATA_WIDTH){1'b0}};
assign m_axi_wstrb    = {(NUM_CORES*16){1'b0}};
assign m_axi_wlast    = {NUM_CORES{1'b0}};
assign m_axi_wvalid   = {NUM_CORES{1'b0}};
assign m_axi_bready   = {NUM_CORES{1'b0}};
assign m_axi_arid     = {(NUM_CORES*ID_WIDTH){1'b0}};
assign m_axi_araddr   = {(NUM_CORES*ADDR_WIDTH){1'b0}};
assign m_axi_arlen    = {(NUM_CORES*8){1'b0}};
assign m_axi_arsize   = {(NUM_CORES*3){1'b0}};
assign m_axi_arburst  = {(NUM_CORES*2){1'b0}};
assign m_axi_arvalid  = {NUM_CORES{1'b0}};
assign m_axi_rready   = {NUM_CORES{1'b0}};

endmodule
