// tensor_core_hard_bb.v — black-box declaration of the hardened tensor 4x4 macro (tc23)
// for chip-level synthesis. Physical view = ip/tensor_core_4x4_v1/{lef,gds,lib}.
(* blackbox *)
module tensor_core_hard (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,
    output wire        core_done_irq
);
endmodule
