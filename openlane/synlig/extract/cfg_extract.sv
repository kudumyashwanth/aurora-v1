module cfg_extract;
  localparam config_pkg::cva6_cfg_t C =
      build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);
  // touch a couple of fields so the elaborator must resolve C
  localparam int unsigned TOUCH = C.XLEN + C.VLEN + C.AxiAddrWidth;
endmodule
