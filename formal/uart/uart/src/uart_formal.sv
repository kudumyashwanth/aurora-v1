// Formal verification for UART
// Properties: TX never X, idle after reset, AXI handshake correctness

`default_nettype none

module uart_formal (
    input logic        clk,
    input logic        rst_n,
    input logic [7:0]  s_axil_awaddr,
    input logic        s_axil_awvalid,
    input logic [31:0] s_axil_wdata,
    input logic        s_axil_wvalid,
    input logic        s_axil_bready,
    input logic [7:0]  s_axil_araddr,
    input logic        s_axil_arvalid,
    input logic        s_axil_rready
);

logic        s_axil_awready, s_axil_wready, s_axil_bvalid;
logic [1:0]  s_axil_bresp, s_axil_rresp;
logic        s_axil_arready, s_axil_rvalid;
logic [31:0] s_axil_rdata;
logic        uart_txd, uart_rxd;
logic        tx_irq, rx_irq;

assign uart_rxd = 1'b1;

uart dut (
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
    .uart_txd       (uart_txd),
    .uart_rxd       (uart_rxd),
    .tx_irq         (tx_irq),
    .rx_irq         (rx_irq)
);

// P1: TX never unknown
assert property (@(posedge clk) disable iff (!rst_n)
    !$isunknown(uart_txd))
    else $error("FAIL P1: uart_txd unknown");

// P2: TX idle high after reset
assert property (@(posedge clk)
    $rose(rst_n) |=> uart_txd)
    else $error("FAIL P2: TX not idle after reset");

// P3: Write response only after valid write
assert property (@(posedge clk) disable iff (!rst_n)
    s_axil_bvalid |-> $past(s_axil_awvalid && s_axil_wvalid))
    else $error("FAIL P3: spurious write response");

// P4: Read response only after read request
assert property (@(posedge clk) disable iff (!rst_n)
    s_axil_rvalid |-> $past(s_axil_arvalid))
    else $error("FAIL P4: spurious read response");

// P5: Always OKAY response
assert property (@(posedge clk) disable iff (!rst_n)
    s_axil_bvalid |-> (s_axil_bresp == 2'b00))
    else $error("FAIL P5: write error response");

// COVER
cover property (@(posedge clk) !uart_txd);
cover property (@(posedge clk) tx_irq);

endmodule
