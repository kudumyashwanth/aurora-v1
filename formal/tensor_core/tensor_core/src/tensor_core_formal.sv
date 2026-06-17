// Formal verification for tensor_core
// Properties: AXI handshake correctness, IRQ pulse, no error responses

`default_nettype none

module tensor_core_formal (
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
logic        irq;

tensor_core dut (
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
    .irq            (irq)
);

// P1: Write response only after valid write
assert property (@(posedge clk) disable iff (!rst_n)
    s_axil_bvalid |-> $past(s_axil_awvalid && s_axil_wvalid))
    else $error("FAIL P1: spurious write response");

// P2: Read response only after read request
assert property (@(posedge clk) disable iff (!rst_n)
    s_axil_rvalid |-> $past(s_axil_arvalid))
    else $error("FAIL P2: spurious read response");

// P3: No error responses
assert property (@(posedge clk) disable iff (!rst_n)
    s_axil_bvalid |-> (s_axil_bresp == 2'b00))
    else $error("FAIL P3: write error response");

// P4: IRQ is a single-cycle pulse
assert property (@(posedge clk) disable iff (!rst_n)
    irq |=> !irq)
    else $error("FAIL P4: IRQ stuck high");

// COVER
cover property (@(posedge clk) irq);
cover property (@(posedge clk) s_axil_bvalid);
cover property (@(posedge clk) s_axil_rvalid);

endmodule
