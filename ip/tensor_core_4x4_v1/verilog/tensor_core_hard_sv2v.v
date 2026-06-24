module tensor_core_hard (
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
	parameter DATA_WIDTH = 16;
	parameter SIZE = 4;
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
	output wire core_done_irq;
	reg [31:0] ctrl_reg;
	wire [31:0] status_reg;
	reg [31:0] a_addr_reg;
	reg [31:0] b_addr_reg;
	reg [31:0] c_addr_reg;
	reg [31:0] config_reg;
	wire core_start;
	wire core_done;
	wire core_busy;
	reg core_done_sticky;
	assign core_start = ctrl_reg[0];
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			core_done_sticky <= 1'b0;
		else if (core_start)
			core_done_sticky <= 1'b0;
		else if (core_done)
			core_done_sticky <= 1'b1;
	assign status_reg = {29'h00000000, core_done_sticky, core_busy, ~core_busy};
	wire is_buf_wr = s_axi_awvalid && (s_axi_awaddr[15:12] != 4'h0);
	reg [127:0] buf_wr_accum;
	reg buf_wr_en;
	reg [15:0] buf_wr_word_addr;
	assign s_axi_awready = 1'b1;
	assign s_axi_wready = 1'b1;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			buf_wr_accum <= 1'sb0;
			buf_wr_word_addr <= 1'sb0;
			buf_wr_en <= 1'b0;
		end
		else begin
			buf_wr_en <= 1'b0;
			if ((s_axi_awvalid && s_axi_wvalid) && is_buf_wr)
				case (s_axi_awaddr[3:2])
					2'd0: buf_wr_accum[31:0] <= s_axi_wdata;
					2'd1: buf_wr_accum[63:32] <= s_axi_wdata;
					2'd2: buf_wr_accum[95:64] <= s_axi_wdata;
					2'd3: begin
						buf_wr_accum[127:96] <= s_axi_wdata;
						buf_wr_en <= 1'b1;
						buf_wr_word_addr <= {4'b0000, s_axi_awaddr[11:0]};
					end
				endcase
		end
	reg [15:0] buf_rd_addr;
	reg buf_rd_en;
	wire [127:0] buf_rd_data;
	tensor_local_buffer #(
		.DATA_WIDTH(128),
		.ADDR_WIDTH(16),
		.BUFFER_DEPTH(16)
	) local_buffer(
		.clk(clk),
		.rst_n(rst_n),
		.porta_addr(buf_wr_word_addr),
		.porta_wr_en(buf_wr_en),
		.porta_wr_data(buf_wr_accum),
		.porta_rd_data(),
		.portb_addr(buf_rd_addr),
		.portb_rd_en(buf_rd_en),
		.portb_rd_data(buf_rd_data)
	);
	localparam signed [31:0] EPW = 128 / DATA_WIDTH;
	localparam signed [31:0] WPM = ((SIZE + EPW) - 1) / EPW;
	localparam signed [31:0] NRD = 2 * WPM;
	reg [1:0] ls;
	reg [(SIZE * DATA_WIDTH) - 1:0] a_matrix;
	reg [(SIZE * DATA_WIDTH) - 1:0] b_matrix;
	wire [((SIZE * SIZE) * 32) - 1:0] result;
	reg core_launch;
	reg [31:0] issue_idx;
	reg rd_pend;
	reg [31:0] rd_idx;
	wire issuing = (ls == 2'd1) && (issue_idx < NRD);
	always @(*) begin
		if (_sv2v_0)
			;
		buf_rd_en = issuing;
		buf_rd_addr = (issuing ? {issue_idx[11:0], 4'b0000} : 16'h0000);
		core_launch = ls == 2'd2;
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			ls <= 2'd0;
			issue_idx <= 1'sb0;
			rd_pend <= 1'b0;
			rd_idx <= 1'sb0;
			a_matrix <= 1'sb0;
			b_matrix <= 1'sb0;
		end
		else begin
			if (rd_pend) begin
				if (rd_idx < WPM) begin : sv2v_autoblock_1
					reg signed [31:0] e;
					for (e = 0; e < EPW; e = e + 1)
						if (((rd_idx * EPW) + e) < SIZE)
							a_matrix[((rd_idx * EPW) + e) * DATA_WIDTH+:DATA_WIDTH] <= buf_rd_data[DATA_WIDTH * e+:DATA_WIDTH];
				end
				else begin : sv2v_autoblock_2
					reg signed [31:0] e;
					for (e = 0; e < EPW; e = e + 1)
						if ((((rd_idx - WPM) * EPW) + e) < SIZE)
							b_matrix[(((rd_idx - WPM) * EPW) + e) * DATA_WIDTH+:DATA_WIDTH] <= buf_rd_data[DATA_WIDTH * e+:DATA_WIDTH];
				end
			end
			rd_pend <= 1'b0;
			case (ls)
				2'd0: begin
					issue_idx <= 1'sb0;
					if (core_start)
						ls <= 2'd1;
				end
				2'd1:
					if (issue_idx < NRD) begin
						rd_pend <= 1'b1;
						rd_idx <= issue_idx;
						issue_idx <= issue_idx + 1;
					end
					else
						ls <= 2'd2;
				2'd2: ls <= 2'd3;
				2'd3: ls <= 2'd0;
				default: ls <= 2'd0;
			endcase
		end
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
		.done(core_done)
	);
	assign core_busy = (ls != 2'd0) && !core_done;
	assign core_done_irq = ls == 2'd3;
	localparam signed [31:0] RIDXW = $clog2(SIZE * SIZE);
	wire [((SIZE * SIZE) * 32) - 1:0] result_flat;
	assign result_flat = result;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			ctrl_reg <= 1'sb0;
			a_addr_reg <= 1'sb0;
			b_addr_reg <= 1'sb0;
			c_addr_reg <= 1'sb0;
			config_reg <= 1'sb0;
		end
		else begin
			ctrl_reg[0] <= 1'b0;
			if ((s_axi_awvalid && s_axi_wvalid) && !is_buf_wr)
				case (s_axi_awaddr[4:0])
					5'h00: ctrl_reg <= s_axi_wdata;
					5'h08: a_addr_reg <= s_axi_wdata;
					5'h0c: b_addr_reg <= s_axi_wdata;
					5'h10: c_addr_reg <= s_axi_wdata;
					5'h14: config_reg <= s_axi_wdata;
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
	assign s_axi_arready = 1'b1;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			s_axi_rdata <= 1'sb0;
			s_axi_rvalid <= 1'b0;
		end
		else if (s_axi_arvalid) begin
			if (s_axi_araddr[15])
				s_axi_rdata <= result_flat[s_axi_araddr[2+:RIDXW] * 32+:32];
			else
				case (s_axi_araddr[4:0])
					5'h00: s_axi_rdata <= ctrl_reg;
					5'h04: s_axi_rdata <= status_reg;
					5'h08: s_axi_rdata <= a_addr_reg;
					5'h0c: s_axi_rdata <= b_addr_reg;
					5'h10: s_axi_rdata <= c_addr_reg;
					5'h14: s_axi_rdata <= config_reg;
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
	parameter BUFFER_DEPTH = 4096;
	input wire clk;
	input wire rst_n;
	input wire [ADDR_WIDTH - 1:0] porta_addr;
	input wire porta_wr_en;
	input wire [DATA_WIDTH - 1:0] porta_wr_data;
	output reg [DATA_WIDTH - 1:0] porta_rd_data;
	input wire [ADDR_WIDTH - 1:0] portb_addr;
	input wire portb_rd_en;
	output reg [DATA_WIDTH - 1:0] portb_rd_data;
	reg [DATA_WIDTH - 1:0] mem [0:BUFFER_DEPTH - 1];
	wire [$clog2(BUFFER_DEPTH) - 1:0] porta_word_addr;
	wire [$clog2(BUFFER_DEPTH) - 1:0] portb_word_addr;
	assign porta_word_addr = porta_addr[$clog2(BUFFER_DEPTH) + 3:4];
	assign portb_word_addr = portb_addr[$clog2(BUFFER_DEPTH) + 3:4];
	always @(posedge clk) begin
		if (porta_wr_en)
			mem[porta_word_addr] <= porta_wr_data;
		porta_rd_data <= mem[porta_word_addr];
	end
	always @(posedge clk)
		if (portb_rd_en)
			portb_rd_data <= mem[portb_word_addr];
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
