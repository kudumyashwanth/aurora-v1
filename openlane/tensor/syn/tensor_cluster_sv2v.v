module mac_unit (
	clk,
	rst_n,
	a,
	b,
	valid_in,
	result,
	valid_out
);
	parameter DATA_WIDTH = 16;
	input wire clk;
	input wire rst_n;
	input wire [DATA_WIDTH - 1:0] a;
	input wire [DATA_WIDTH - 1:0] b;
	input wire valid_in;
	output wire [31:0] result;
	output reg valid_out;
	reg [31:0] acc;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			acc <= 0;
			valid_out <= 0;
		end
		else if (valid_in) begin
			acc <= acc + (a * b);
			valid_out <= 1;
		end
		else
			valid_out <= 0;
	assign result = acc;
endmodule
module systolic_array_16x16 (
	clk,
	rst_n,
	start,
	a_matrix,
	b_matrix,
	result,
	done
);
	parameter DATA_WIDTH = 16;
	parameter SIZE = 16;
	input wire clk;
	input wire rst_n;
	input wire start;
	input wire [(SIZE * DATA_WIDTH) - 1:0] a_matrix;
	input wire [(SIZE * DATA_WIDTH) - 1:0] b_matrix;
	output wire [((SIZE * SIZE) * 32) - 1:0] result;
	output wire done;
	wire [31:0] mac_out [0:SIZE - 1][0:SIZE - 1];
	wire valid [0:SIZE - 1][0:SIZE - 1];
	genvar _gv_i_1;
	genvar _gv_j_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < SIZE; _gv_i_1 = _gv_i_1 + 1) begin : ROW
			localparam i = _gv_i_1;
			for (_gv_j_1 = 0; _gv_j_1 < SIZE; _gv_j_1 = _gv_j_1 + 1) begin : COL
				localparam j = _gv_j_1;
				mac_unit #(.DATA_WIDTH(DATA_WIDTH)) mac_inst(
					.clk(clk),
					.rst_n(rst_n),
					.a(a_matrix[i * DATA_WIDTH+:DATA_WIDTH]),
					.b(b_matrix[j * DATA_WIDTH+:DATA_WIDTH]),
					.valid_in(start),
					.result(mac_out[i][j]),
					.valid_out(valid[i][j])
				);
				assign result[((i * SIZE) + j) * 32+:32] = mac_out[i][j];
			end
		end
	endgenerate
	assign done = start;
endmodule
module tensor_core (
	clk,
	rst_n,
	start,
	a_matrix,
	b_matrix,
	done,
	result
);
	reg _sv2v_0;
	parameter DATA_WIDTH = 16;
	parameter SIZE = 16;
	input wire clk;
	input wire rst_n;
	input wire start;
	input wire [(SIZE * DATA_WIDTH) - 1:0] a_matrix;
	input wire [(SIZE * DATA_WIDTH) - 1:0] b_matrix;
	output wire done;
	output wire [((SIZE * SIZE) * 32) - 1:0] result;
	reg [1:0] state;
	reg [1:0] next_state;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			state <= 2'b00;
		else
			state <= next_state;
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = state;
		case (state)
			2'b00:
				if (start)
					next_state = 2'b01;
			2'b01: next_state = 2'b10;
			2'b10: next_state = 2'b00;
			default: next_state = 2'b00;
		endcase
	end
	wire valid_compute;
	wire compute_done;
	assign valid_compute = state == 2'b01;
	systolic_array_16x16 #(
		.DATA_WIDTH(DATA_WIDTH),
		.SIZE(SIZE)
	) array_inst(
		.clk(clk),
		.rst_n(rst_n),
		.start(valid_compute),
		.a_matrix(a_matrix),
		.b_matrix(b_matrix),
		.result(result),
		.done(compute_done)
	);
	assign done = state == 2'b10;
	initial _sv2v_0 = 0;
endmodule
module tensor_cluster_top (
	clk,
	rst_n,
	s_axi_awaddr,
	s_axi_awvalid,
	s_axi_awready,
	s_axi_wdata,
	s_axi_wvalid,
	s_axi_wready,
	s_axi_bvalid,
	s_axi_bready,
	s_axi_araddr,
	s_axi_arvalid,
	s_axi_arready,
	s_axi_rdata,
	s_axi_rvalid,
	s_axi_rready,
	core_done_irq
);
	reg _sv2v_0;
	parameter NUM_CORES = 4;
	parameter DATA_WIDTH = 16;
	parameter SIZE = 16;
	input wire clk;
	input wire rst_n;
	input wire [31:0] s_axi_awaddr;
	input wire s_axi_awvalid;
	output wire s_axi_awready;
	input wire [31:0] s_axi_wdata;
	input wire s_axi_wvalid;
	output wire s_axi_wready;
	output reg s_axi_bvalid;
	input wire s_axi_bready;
	input wire [31:0] s_axi_araddr;
	input wire s_axi_arvalid;
	output wire s_axi_arready;
	output reg [31:0] s_axi_rdata;
	output reg s_axi_rvalid;
	input wire s_axi_rready;
	output wire [NUM_CORES - 1:0] core_done_irq;
	reg [(NUM_CORES * 32) - 1:0] ctrl_reg;
	wire [(NUM_CORES * 32) - 1:0] status_reg;
	reg [(NUM_CORES * 32) - 1:0] a_addr_reg;
	reg [(NUM_CORES * 32) - 1:0] b_addr_reg;
	reg [(NUM_CORES * 32) - 1:0] c_addr_reg;
	reg [(NUM_CORES * 32) - 1:0] config_reg;
	wire [NUM_CORES - 1:0] core_start;
	wire [NUM_CORES - 1:0] core_done;
	wire [NUM_CORES - 1:0] core_busy;
	wire [((NUM_CORES * (SIZE * SIZE)) * 32) - 1:0] result_flat;
	reg [NUM_CORES - 1:0] core_done_sticky;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			core_done_sticky <= 1'sb0;
		else begin : sv2v_autoblock_1
			reg signed [31:0] k;
			for (k = 0; k < NUM_CORES; k = k + 1)
				if (core_start[k])
					core_done_sticky[k] <= 1'b0;
				else if (core_done[k])
					core_done_sticky[k] <= 1'b1;
		end
	genvar _gv_g_1;
	generate
		for (_gv_g_1 = 0; _gv_g_1 < NUM_CORES; _gv_g_1 = _gv_g_1 + 1) begin : CTRL_DECODE
			localparam g = _gv_g_1;
			assign core_start[g] = ctrl_reg[g * 32];
			assign status_reg[g * 32+:32] = {29'h00000000, core_done_sticky[g], core_busy[g], ~core_busy[g]};
		end
	endgenerate
	wire is_buf_wr = s_axi_awvalid && (s_axi_awaddr[15:12] != 4'h0);
	wire [1:0] buf_core = s_axi_awaddr[13:12] - 2'd1;
	wire [15:0] buf_wr_addr = s_axi_awaddr[15:0];
	reg [127:0] buf_wr_accum [0:NUM_CORES - 1];
	reg [NUM_CORES - 1:0] buf_wr_en;
	reg [15:0] buf_wr_word_addr [0:NUM_CORES - 1];
	assign s_axi_awready = 1'b1;
	assign s_axi_wready = 1'b1;
	integer lc;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			for (lc = 0; lc < NUM_CORES; lc = lc + 1)
				begin
					buf_wr_accum[lc] <= 1'sb0;
					buf_wr_word_addr[lc] <= 1'sb0;
				end
			buf_wr_en <= 1'sb0;
		end
		else begin
			buf_wr_en <= 1'sb0;
			if ((s_axi_awvalid && s_axi_wvalid) && is_buf_wr)
				case (s_axi_awaddr[3:2])
					2'd0: buf_wr_accum[buf_core][31:0] <= s_axi_wdata;
					2'd1: buf_wr_accum[buf_core][63:32] <= s_axi_wdata;
					2'd2: buf_wr_accum[buf_core][95:64] <= s_axi_wdata;
					2'd3: begin
						buf_wr_accum[buf_core][127:96] <= s_axi_wdata;
						buf_wr_en[buf_core] <= 1'b1;
						buf_wr_word_addr[buf_core] <= {4'b0000, s_axi_awaddr[11:0]};
					end
				endcase
		end
	generate
		for (_gv_g_1 = 0; _gv_g_1 < NUM_CORES; _gv_g_1 = _gv_g_1 + 1) begin : TENSOR_CORE_GEN
			localparam g = _gv_g_1;
			reg [15:0] buf_rd_addr;
			reg buf_rd_en;
			wire [127:0] buf_rd_data;
			tensor_local_buffer #(
				.DATA_WIDTH(128),
				.ADDR_WIDTH(16),
				.BUFFER_DEPTH(4096)
			) local_buffer(
				.clk(clk),
				.rst_n(rst_n),
				.porta_addr(buf_wr_word_addr[g]),
				.porta_wr_en(buf_wr_en[g]),
				.porta_wr_data(buf_wr_accum[g]),
				.porta_rd_data(),
				.portb_addr(buf_rd_addr),
				.portb_rd_en(buf_rd_en),
				.portb_rd_data(buf_rd_data)
			);
			reg [2:0] ls;
			reg [2:0] ls_next;
			reg [(SIZE * DATA_WIDTH) - 1:0] a_matrix;
			reg [(SIZE * DATA_WIDTH) - 1:0] b_matrix;
			wire [((SIZE * SIZE) * 32) - 1:0] result;
			reg core_launch;
			always @(posedge clk or negedge rst_n)
				if (!rst_n)
					ls <= 3'd0;
				else
					ls <= ls_next;
			always @(*) begin
				if (_sv2v_0)
					;
				ls_next = ls;
				buf_rd_addr = 1'sb0;
				buf_rd_en = 1'b0;
				core_launch = 1'b0;
				case (ls)
					3'd0:
						if (core_start[g]) begin
							ls_next = 3'd1;
							buf_rd_addr = 16'h0000;
							buf_rd_en = 1'b1;
						end
					3'd1: begin
						ls_next = 3'd2;
						buf_rd_addr = 16'h0010;
						buf_rd_en = 1'b1;
					end
					3'd2: begin
						ls_next = 3'd3;
						buf_rd_addr = 16'h0020;
						buf_rd_en = 1'b1;
					end
					3'd3: begin
						ls_next = 3'd4;
						buf_rd_addr = 16'h0030;
						buf_rd_en = 1'b1;
					end
					3'd4: ls_next = 3'd5;
					3'd5: begin
						ls_next = 3'd6;
						core_launch = 1'b1;
					end
					3'd6: ls_next = 3'd7;
					3'd7: ls_next = 3'd0;
					default: ls_next = 3'd0;
				endcase
			end
			always @(posedge clk or negedge rst_n)
				if (!rst_n) begin
					a_matrix <= 1'sb0;
					b_matrix <= 1'sb0;
				end
				else
					case (ls)
						3'd2: begin : sv2v_autoblock_2
							reg signed [31:0] e;
							for (e = 0; e < 8; e = e + 1)
								a_matrix[e * DATA_WIDTH+:DATA_WIDTH] <= buf_rd_data[16 * e+:16];
						end
						3'd3: begin : sv2v_autoblock_3
							reg signed [31:0] e;
							for (e = 0; e < 8; e = e + 1)
								a_matrix[(e + 8) * DATA_WIDTH+:DATA_WIDTH] <= buf_rd_data[16 * e+:16];
						end
						3'd4: begin : sv2v_autoblock_4
							reg signed [31:0] e;
							for (e = 0; e < 8; e = e + 1)
								b_matrix[e * DATA_WIDTH+:DATA_WIDTH] <= buf_rd_data[16 * e+:16];
						end
						3'd5: begin : sv2v_autoblock_5
							reg signed [31:0] e;
							for (e = 0; e < 8; e = e + 1)
								b_matrix[(e + 8) * DATA_WIDTH+:DATA_WIDTH] <= buf_rd_data[16 * e+:16];
						end
						default:
							;
					endcase
			tensor_core #(
				.DATA_WIDTH(DATA_WIDTH),
				.SIZE(SIZE)
			) core(
				.clk(clk),
				.rst_n(rst_n),
				.start(core_launch),
				.a_matrix(a_matrix),
				.b_matrix(b_matrix),
				.result(result),
				.done(core_done[g])
			);
			assign result_flat[32 * (g * (SIZE * SIZE))+:32 * (SIZE * SIZE)] = result;
			assign core_busy[g] = (ls != 3'd0) && !core_done[g];
			assign core_done_irq[g] = ls == 3'd7;
		end
	endgenerate
	wire [1:0] core_sel_wr;
	wire [4:0] reg_offset_wr;
	assign core_sel_wr = s_axi_awaddr[6:5];
	assign reg_offset_wr = s_axi_awaddr[4:0];
	integer lci;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			for (lci = 0; lci < NUM_CORES; lci = lci + 1)
				begin
					ctrl_reg[lci * 32+:32] <= 1'sb0;
					a_addr_reg[lci * 32+:32] <= 1'sb0;
					b_addr_reg[lci * 32+:32] <= 1'sb0;
					c_addr_reg[lci * 32+:32] <= 1'sb0;
					config_reg[lci * 32+:32] <= 1'sb0;
				end
		else begin
			for (lci = 0; lci < NUM_CORES; lci = lci + 1)
				ctrl_reg[lci * 32] <= 1'b0;
			if ((s_axi_awvalid && s_axi_wvalid) && !is_buf_wr)
				case (reg_offset_wr)
					5'h00: ctrl_reg[core_sel_wr * 32+:32] <= s_axi_wdata;
					5'h08: a_addr_reg[core_sel_wr * 32+:32] <= s_axi_wdata;
					5'h0c: b_addr_reg[core_sel_wr * 32+:32] <= s_axi_wdata;
					5'h10: c_addr_reg[core_sel_wr * 32+:32] <= s_axi_wdata;
					5'h14: config_reg[core_sel_wr * 32+:32] <= s_axi_wdata;
					default:
						;
				endcase
		end
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			s_axi_bvalid <= 1'b0;
		else if (s_axi_awvalid && s_axi_wvalid)
			s_axi_bvalid <= 1'b1;
		else if (s_axi_bready)
			s_axi_bvalid <= 1'b0;
	wire [1:0] core_sel_rd;
	wire [4:0] reg_offset_rd;
	wire is_result_rd;
	wire [1:0] res_core_rd;
	wire [7:0] res_word_rd;
	assign core_sel_rd = s_axi_araddr[6:5];
	assign reg_offset_rd = s_axi_araddr[4:0];
	assign is_result_rd = s_axi_araddr[15];
	assign res_core_rd = s_axi_araddr[14:13];
	assign res_word_rd = s_axi_araddr[9:2];
	assign s_axi_arready = 1'b1;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			s_axi_rdata <= 1'sb0;
			s_axi_rvalid <= 1'b0;
		end
		else if (s_axi_arvalid) begin
			if (is_result_rd)
				s_axi_rdata <= result_flat[((res_core_rd * (SIZE * SIZE)) + res_word_rd) * 32+:32];
			else
				case (reg_offset_rd)
					5'h00: s_axi_rdata <= ctrl_reg[core_sel_rd * 32+:32];
					5'h04: s_axi_rdata <= status_reg[core_sel_rd * 32+:32];
					5'h08: s_axi_rdata <= a_addr_reg[core_sel_rd * 32+:32];
					5'h0c: s_axi_rdata <= b_addr_reg[core_sel_rd * 32+:32];
					5'h10: s_axi_rdata <= c_addr_reg[core_sel_rd * 32+:32];
					5'h14: s_axi_rdata <= config_reg[core_sel_rd * 32+:32];
					default: s_axi_rdata <= 32'hdeadbeef;
				endcase
			s_axi_rvalid <= 1'b1;
		end
		else if (s_axi_rready)
			s_axi_rvalid <= 1'b0;
	initial _sv2v_0 = 0;
endmodule
module tensor_local_buffer (
	clk,
	rst_n,
	porta_addr,
	porta_wr_en,
	porta_wr_data,
	porta_rd_data,
	portb_addr,
	portb_rd_en,
	portb_rd_data
);
	parameter DATA_WIDTH = 128;
	parameter ADDR_WIDTH = 16;
	parameter BUFFER_DEPTH = 512;
	input wire clk;
	input wire rst_n;
	input wire [ADDR_WIDTH - 1:0] porta_addr;
	input wire porta_wr_en;
	input wire [DATA_WIDTH - 1:0] porta_wr_data;
	output wire [DATA_WIDTH - 1:0] porta_rd_data;
	input wire [ADDR_WIDTH - 1:0] portb_addr;
	input wire portb_rd_en;
	output wire [DATA_WIDTH - 1:0] portb_rd_data;
	localparam signed [31:0] MACRO_AW = 9;
	localparam signed [31:0] N_MACRO = DATA_WIDTH / 32;
	wire [8:0] porta_word_addr = porta_addr[12:4];
	wire [8:0] portb_word_addr = portb_addr[12:4];
	wire csb0 = 1'b0;
	wire web0 = ~porta_wr_en;
	wire csb1 = ~portb_rd_en;
	genvar _gv_m_1;
	generate
		for (_gv_m_1 = 0; _gv_m_1 < N_MACRO; _gv_m_1 = _gv_m_1 + 1) begin : g_bank
			localparam m = _gv_m_1;
			sky130_sram_2kbyte_1rw1r_32x512_8 u_sram(
				.clk0(clk),
				.csb0(csb0),
				.web0(web0),
				.wmask0(4'b1111),
				.addr0(porta_word_addr),
				.din0(porta_wr_data[m * 32+:32]),
				.dout0(porta_rd_data[m * 32+:32]),
				.clk1(clk),
				.csb1(csb1),
				.addr1(portb_word_addr),
				.dout1(portb_rd_data[m * 32+:32])
			);
		end
	endgenerate
endmodule
