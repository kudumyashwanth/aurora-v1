module cfg_print;
  localparam config_pkg::cva6_cfg_t C =
      build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);
  initial begin
    $display("CFG_BITS=%0d", $bits(C));
    $display("AW=%0d DW=%0d IW=%0d UW=%0d XLEN=%0d",
             C.AxiAddrWidth, C.AxiDataWidth, C.AxiIdWidth, C.AxiUserWidth, C.XLEN);
    $display("CFG_HEX=%h", C);
    $finish;
  end
endmodule
