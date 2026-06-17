// cva6_stub.v — Black-box stub for CVA6 core
// Used during synthesis — CVA6 is treated as pre-verified hard macro.
// noc_req_t  = 282 bits, noc_resp_t = 88 bits (cv64a6_imafdc_sv39 config)
module cva6 (
    input  wire        clk_i,
    input  wire        rst_ni,
    input  wire [63:0] boot_addr_i,
    input  wire [63:0] hart_id_i,
    input  wire [1:0]  irq_i,
    input  wire        ipi_i,
    input  wire        time_irq_i,
    input  wire        debug_req_i,
    output wire        rvfi_probes_o,
    output wire        cvxif_req_o,
    input  wire        cvxif_resp_i,
    output wire [281:0] noc_req_o,
    input  wire [87:0]  noc_resp_i
);
  // Black-box: no logic, outputs tied off for synthesis stub
  assign rvfi_probes_o = 1'b0;
  assign cvxif_req_o   = 1'b0;
  assign noc_req_o     = 282'b0;
endmodule
