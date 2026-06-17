`timescale 1ns/1ps

// Aurora v1 - AXI4-Lite CDC Bridge
// Clock Domain Crossing between CPU (100MHz) and Fabric (200MHz)
// Uses async FIFOs with Gray code pointers for safe CDC

module axi_cdc_bridge
#(
    parameter DATA_WIDTH = 128,
    parameter ADDR_WIDTH = 32,
    parameter ID_WIDTH   = 4
)
(
    // CPU clock domain (100 MHz)
    input  logic cpu_clk,
    input  logic cpu_rst_n,

    // Fabric clock domain (200 MHz)
    input  logic fabric_clk,
    input  logic fabric_rst_n,

    // =================================================
    // AXI4 Slave Interface (CPU Side, 100 MHz)
    // =================================================
    
    // Write Address Channel
    input  logic [ID_WIDTH-1:0]    s_axi_awid,
    input  logic [ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  logic                   s_axi_awvalid,
    output logic                   s_axi_awready,

    // Write Data Channel
    input  logic [DATA_WIDTH-1:0]  s_axi_wdata,
    input  logic                   s_axi_wvalid,
    output logic                   s_axi_wready,

    // Write Response Channel
    output logic [ID_WIDTH-1:0]    s_axi_bid,
    output logic                   s_axi_bvalid,
    input  logic                   s_axi_bready,

    // Read Address Channel
    input  logic [ID_WIDTH-1:0]    s_axi_arid,
    input  logic [ADDR_WIDTH-1:0]  s_axi_araddr,
    input  logic                   s_axi_arvalid,
    output logic                   s_axi_arready,

    // Read Data Channel
    output logic [ID_WIDTH-1:0]    s_axi_rid,
    output logic [DATA_WIDTH-1:0]  s_axi_rdata,
    output logic                   s_axi_rvalid,
    input  logic                   s_axi_rready,

    // =================================================
    // AXI4 Master Interface (Fabric Side, 200 MHz)
    // =================================================
    
    // Write Address Channel
    output logic [ID_WIDTH-1:0]    m_axi_awid,
    output logic [ADDR_WIDTH-1:0]  m_axi_awaddr,
    output logic                   m_axi_awvalid,
    input  logic                   m_axi_awready,

    // Write Data Channel
    output logic [DATA_WIDTH-1:0]  m_axi_wdata,
    output logic                   m_axi_wvalid,
    input  logic                   m_axi_wready,

    // Write Response Channel
    input  logic [ID_WIDTH-1:0]    m_axi_bid,
    input  logic                   m_axi_bvalid,
    output logic                   m_axi_bready,

    // Read Address Channel
    output logic [ID_WIDTH-1:0]    m_axi_arid,
    output logic [ADDR_WIDTH-1:0]  m_axi_araddr,
    output logic                   m_axi_arvalid,
    input  logic                   m_axi_arready,

    // Read Data Channel
    input  logic [ID_WIDTH-1:0]    m_axi_rid,
    input  logic [DATA_WIDTH-1:0]  m_axi_rdata,
    input  logic                   m_axi_rvalid,
    output logic                   m_axi_rready
);

/////////////////////////////////////////////////
// AW CHANNEL CDC (CPU → Fabric)
/////////////////////////////////////////////////

localparam AW_WIDTH = ID_WIDTH + ADDR_WIDTH;

logic [AW_WIDTH-1:0] aw_wdata, aw_rdata;
logic aw_full, aw_empty, aw_wr_en, aw_rd_en;

assign aw_wdata = {s_axi_awid, s_axi_awaddr};
assign s_axi_awready = !aw_full;
assign aw_wr_en = s_axi_awvalid && s_axi_awready;

assign m_axi_awvalid = !aw_empty;
assign aw_rd_en = m_axi_awvalid && m_axi_awready;
assign {m_axi_awid, m_axi_awaddr} = aw_rdata;

async_fifo #(
    .DATA_WIDTH(AW_WIDTH),
    .ADDR_WIDTH(4)
) aw_fifo (
    .wr_clk(cpu_clk),
    .wr_rst_n(cpu_rst_n),
    .wr_en(aw_wr_en),
    .wr_data(aw_wdata),
    .wr_full(aw_full),
    .rd_clk(fabric_clk),
    .rd_rst_n(fabric_rst_n),
    .rd_en(aw_rd_en),
    .rd_data(aw_rdata),
    .rd_empty(aw_empty)
);

/////////////////////////////////////////////////
// W CHANNEL CDC (CPU → Fabric)
/////////////////////////////////////////////////

localparam W_WIDTH = DATA_WIDTH;

logic [W_WIDTH-1:0] w_wdata, w_rdata;
logic w_full, w_empty, w_wr_en, w_rd_en;

assign w_wdata = s_axi_wdata;
assign s_axi_wready = !w_full;
assign w_wr_en = s_axi_wvalid && s_axi_wready;

assign m_axi_wvalid = !w_empty;
assign w_rd_en = m_axi_wvalid && m_axi_wready;
assign m_axi_wdata = w_rdata;

async_fifo #(
    .DATA_WIDTH(W_WIDTH),
    .ADDR_WIDTH(4)
) w_fifo (
    .wr_clk(cpu_clk),
    .wr_rst_n(cpu_rst_n),
    .wr_en(w_wr_en),
    .wr_data(w_wdata),
    .wr_full(w_full),
    .rd_clk(fabric_clk),
    .rd_rst_n(fabric_rst_n),
    .rd_en(w_rd_en),
    .rd_data(w_rdata),
    .rd_empty(w_empty)
);

/////////////////////////////////////////////////
// B CHANNEL CDC (Fabric → CPU)
/////////////////////////////////////////////////

localparam B_WIDTH = ID_WIDTH;

logic [B_WIDTH-1:0] b_wdata, b_rdata;
logic b_full, b_empty, b_wr_en, b_rd_en;

assign b_wdata = m_axi_bid;
assign m_axi_bready = !b_full;
assign b_wr_en = m_axi_bvalid && m_axi_bready;

assign s_axi_bvalid = !b_empty;
assign b_rd_en = s_axi_bvalid && s_axi_bready;
assign s_axi_bid = b_rdata;

async_fifo #(
    .DATA_WIDTH(B_WIDTH),
    .ADDR_WIDTH(4)
) b_fifo (
    .wr_clk(fabric_clk),
    .wr_rst_n(fabric_rst_n),
    .wr_en(b_wr_en),
    .wr_data(b_wdata),
    .wr_full(b_full),
    .rd_clk(cpu_clk),
    .rd_rst_n(cpu_rst_n),
    .rd_en(b_rd_en),
    .rd_data(b_rdata),
    .rd_empty(b_empty)
);

/////////////////////////////////////////////////
// AR CHANNEL CDC (CPU → Fabric)
/////////////////////////////////////////////////

localparam AR_WIDTH = ID_WIDTH + ADDR_WIDTH;

logic [AR_WIDTH-1:0] ar_wdata, ar_rdata;
logic ar_full, ar_empty, ar_wr_en, ar_rd_en;

assign ar_wdata = {s_axi_arid, s_axi_araddr};
assign s_axi_arready = !ar_full;
assign ar_wr_en = s_axi_arvalid && s_axi_arready;

assign m_axi_arvalid = !ar_empty;
assign ar_rd_en = m_axi_arvalid && m_axi_arready;
assign {m_axi_arid, m_axi_araddr} = ar_rdata;

async_fifo #(
    .DATA_WIDTH(AR_WIDTH),
    .ADDR_WIDTH(4)
) ar_fifo (
    .wr_clk(cpu_clk),
    .wr_rst_n(cpu_rst_n),
    .wr_en(ar_wr_en),
    .wr_data(ar_wdata),
    .wr_full(ar_full),
    .rd_clk(fabric_clk),
    .rd_rst_n(fabric_rst_n),
    .rd_en(ar_rd_en),
    .rd_data(ar_rdata),
    .rd_empty(ar_empty)
);

/////////////////////////////////////////////////
// R CHANNEL CDC (Fabric → CPU)
/////////////////////////////////////////////////

localparam R_WIDTH = ID_WIDTH + DATA_WIDTH;

logic [R_WIDTH-1:0] r_wdata, r_rdata;
logic r_full, r_empty, r_wr_en, r_rd_en;

assign r_wdata = {m_axi_rid, m_axi_rdata};
assign m_axi_rready = !r_full;
assign r_wr_en = m_axi_rvalid && m_axi_rready;

assign s_axi_rvalid = !r_empty;
assign r_rd_en = s_axi_rvalid && s_axi_rready;
assign {s_axi_rid, s_axi_rdata} = r_rdata;

async_fifo #(
    .DATA_WIDTH(R_WIDTH),
    .ADDR_WIDTH(4)
) r_fifo (
    .wr_clk(fabric_clk),
    .wr_rst_n(fabric_rst_n),
    .wr_en(r_wr_en),
    .wr_data(r_wdata),
    .wr_full(r_full),
    .rd_clk(cpu_clk),
    .rd_rst_n(cpu_rst_n),
    .rd_en(r_rd_en),
    .rd_data(r_rdata),
    .rd_empty(r_empty)
);

endmodule
