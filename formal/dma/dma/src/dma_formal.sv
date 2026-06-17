// Formal verification for DMA engine
// Properties: no spurious AXI transactions, IRQ pulse, valid write strobes

`default_nettype none

module dma_formal (
    input logic        clk,
    input logic        rst_n,
    input logic [7:0]  s_axil_awaddr,
    input logic        s_axil_awvalid,
    input logic [31:0] s_axil_wdata,
    input logic        s_axil_wvalid,
    input logic        s_axil_bready,
    input logic [7:0]  s_axil_araddr,
    input logic        s_axil_arvalid,
    input logic        s_axil_rready,
    input logic        m_axi_awready,
    input logic        m_axi_wready,
    input logic        m_axi_bvalid,
    input logic [1:0]  m_axi_bresp,
    input logic        m_axi_arready,
    input logic        m_axi_rvalid,
    input logic        m_axi_rlast,
    input logic [1:0]  m_axi_rresp,
    input logic [127:0] m_axi_rdata
);

logic        s_axil_awready, s_axil_wready, s_axil_bvalid;
logic [1:0]  s_axil_bresp;
logic        s_axil_arready, s_axil_rvalid;
logic [31:0] s_axil_rdata;
logic [1:0]  s_axil_rresp;
logic [31:0] m_axi_awaddr, m_axi_araddr;
logic        m_axi_awvalid, m_axi_arvalid;
logic [127:0] m_axi_wdata;
logic [15:0]  m_axi_wstrb;
logic         m_axi_wvalid, m_axi_wlast;
logic         m_axi_bready, m_axi_rready;
logic         irq;

// Memory always responds OK
assume property (@(posedge clk) m_axi_bresp == 2'b00);
assume property (@(posedge clk) m_axi_rresp == 2'b00);

dma_engine dut (
    .clk            (clk),
    .rst_n          (rst_n),
    .s_axil_awaddr  (s_axil_awaddr),
    .s_axil_awvalid (s_axil_awvalid),
    .s_axil_awready (s_axil_awready),
    .s_axil_wdata   (s_axil_wdata),
    .s_axil_wvalid  (s_axil_wvalid),
    .s_axil_wready  (s_axil_wready),
    .s_axil_bresp   (s_axil_bresp),
    .s_axil_bvalid  (s_axil_bvalid),
    .s_axil_bready  (s_axil_bready),
    .s_axil_araddr  (s_axil_araddr),
    .s_axil_arvalid (s_axil_arvalid),
    .s_axil_arready (s_axil_arready),
    .s_axil_rdata   (s_axil_rdata),
    .s_axil_rresp   (s_axil_rresp),
    .s_axil_rvalid  (s_axil_rvalid),
    .s_axil_rready  (s_axil_rready),
    .m_axi_awaddr   (m_axi_awaddr),
    .m_axi_awvalid  (m_axi_awvalid),
    .m_axi_awready  (m_axi_awready),
    .m_axi_wdata    (m_axi_wdata),
    .m_axi_wstrb    (m_axi_wstrb),
    .m_axi_wvalid   (m_axi_wvalid),
    .m_axi_wlast    (m_axi_wlast),
    .m_axi_wready   (m_axi_wready),
    .m_axi_bvalid   (m_axi_bvalid),
    .m_axi_bresp    (m_axi_bresp),
    .m_axi_bready   (m_axi_bready),
    .m_axi_araddr   (m_axi_araddr),
    .m_axi_arvalid  (m_axi_arvalid),
    .m_axi_arready  (m_axi_arready),
    .m_axi_rdata    (m_axi_rdata),
    .m_axi_rvalid   (m_axi_rvalid),
    .m_axi_rlast    (m_axi_rlast),
    .m_axi_rresp    (m_axi_rresp),
    .m_axi_rready   (m_axi_rready),
    .irq            (irq)
);

// P1: IRQ is a single-cycle pulse
assert property (@(posedge clk) disable iff (!rst_n)
    irq |=> !irq)
    else $error("FAIL P1: IRQ stuck high");

// P2: Write strobe never all-zero when wvalid
assert property (@(posedge clk) disable iff (!rst_n)
    m_axi_wvalid |-> (m_axi_wstrb != '0))
    else $error("FAIL P2: wvalid with zero strobe");

// P3: DMA ctrl write response only after ctrl write
assert property (@(posedge clk) disable iff (!rst_n)
    s_axil_bvalid |-> $past(s_axil_awvalid && s_axil_wvalid))
    else $error("FAIL P3: spurious ctrl write response");

// COVER
cover property (@(posedge clk) irq);
cover property (@(posedge clk) m_axi_awvalid);
cover property (@(posedge clk) m_axi_arvalid);

endmodule
