module rockettile_dcache_data_arrays_0_ext (
	RW0_addr,
	RW0_en,
	RW0_clk,
	RW0_wmode,
	RW0_wdata,
	RW0_rdata,
	RW0_wmask
);
	input [8:0] RW0_addr;
	input RW0_en;
	input RW0_clk;
	input RW0_wmode;
	input [255:0] RW0_wdata;
	output wire [255:0] RW0_rdata;
	input [31:0] RW0_wmask;
	wire csb0 = ~RW0_en;
	wire web0 = ~RW0_wmode;
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < 8; _gv_i_1 = _gv_i_1 + 1) begin : g_bank
			localparam i = _gv_i_1;
			sky130_sram_2kbyte_1rw1r_32x512_8 u_sram(
				.clk0(RW0_clk),
				.csb0(csb0),
				.web0(web0),
				.wmask0(RW0_wmask[i * 4+:4]),
				.addr0(RW0_addr),
				.din0(RW0_wdata[i * 32+:32]),
				.dout0(RW0_rdata[i * 32+:32]),
				.clk1(RW0_clk),
				.csb1(1'b1),
				.addr1(9'b000000000),
				.dout1()
			);
		end
	endgenerate
endmodule
module rockettile_icache_data_arrays_0_ext (
	RW0_addr,
	RW0_en,
	RW0_clk,
	RW0_wmode,
	RW0_wdata,
	RW0_rdata,
	RW0_wmask
);
	input [8:0] RW0_addr;
	input RW0_en;
	input RW0_clk;
	input RW0_wmode;
	input [127:0] RW0_wdata;
	output wire [127:0] RW0_rdata;
	input [3:0] RW0_wmask;
	wire csb0 = ~RW0_en;
	wire web0 = ~RW0_wmode;
	genvar _gv_i_2;
	generate
		for (_gv_i_2 = 0; _gv_i_2 < 4; _gv_i_2 = _gv_i_2 + 1) begin : g_bank
			localparam i = _gv_i_2;
			sky130_sram_2kbyte_1rw1r_32x512_8 u_sram(
				.clk0(RW0_clk),
				.csb0(csb0),
				.web0(web0),
				.wmask0({4 {RW0_wmask[i]}}),
				.addr0(RW0_addr),
				.din0(RW0_wdata[i * 32+:32]),
				.dout0(RW0_rdata[i * 32+:32]),
				.clk1(RW0_clk),
				.csb1(1'b1),
				.addr1(9'b000000000),
				.dout1()
			);
		end
	endgenerate
endmodule
module rockettile_dcache_tag_array_ext (
	RW0_addr,
	RW0_en,
	RW0_clk,
	RW0_wmode,
	RW0_wdata,
	RW0_rdata,
	RW0_wmask
);
	input [5:0] RW0_addr;
	input RW0_en;
	input RW0_clk;
	input RW0_wmode;
	input [87:0] RW0_wdata;
	output wire [87:0] RW0_rdata;
	input [3:0] RW0_wmask;
	reg [87:0] mem [0:63];
	reg [5:0] raddr;
	always @(posedge RW0_clk) begin
		if (RW0_en & RW0_wmode) begin
			if (RW0_wmask[0])
				mem[RW0_addr][21:0] <= RW0_wdata[21:0];
			if (RW0_wmask[1])
				mem[RW0_addr][43:22] <= RW0_wdata[43:22];
			if (RW0_wmask[2])
				mem[RW0_addr][65:44] <= RW0_wdata[65:44];
			if (RW0_wmask[3])
				mem[RW0_addr][87:66] <= RW0_wdata[87:66];
		end
		if (RW0_en & ~RW0_wmode)
			raddr <= RW0_addr;
	end
	assign RW0_rdata = mem[raddr];
endmodule
module rockettile_icache_tag_array_ext (
	RW0_addr,
	RW0_en,
	RW0_clk,
	RW0_wmode,
	RW0_wdata,
	RW0_rdata,
	RW0_wmask
);
	input [5:0] RW0_addr;
	input RW0_en;
	input RW0_clk;
	input RW0_wmode;
	input [83:0] RW0_wdata;
	output wire [83:0] RW0_rdata;
	input [3:0] RW0_wmask;
	reg [83:0] mem [0:63];
	reg [5:0] raddr;
	always @(posedge RW0_clk) begin
		if (RW0_en & RW0_wmode) begin
			if (RW0_wmask[0])
				mem[RW0_addr][20:0] <= RW0_wdata[20:0];
			if (RW0_wmask[1])
				mem[RW0_addr][41:21] <= RW0_wdata[41:21];
			if (RW0_wmask[2])
				mem[RW0_addr][62:42] <= RW0_wdata[62:42];
			if (RW0_wmask[3])
				mem[RW0_addr][83:63] <= RW0_wdata[83:63];
		end
		if (RW0_en & ~RW0_wmode)
			raddr <= RW0_addr;
	end
	assign RW0_rdata = mem[raddr];
endmodule
