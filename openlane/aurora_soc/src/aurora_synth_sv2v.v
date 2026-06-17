module clock_reset_controller (
	clk_in,
	rst_in_n,
	cpu_clk,
	cpu_rst_n,
	fabric_clk,
	fabric_rst_n
);
	parameter SYNC_STAGES = 2;
	input wire clk_in;
	input wire rst_in_n;
	output wire cpu_clk;
	output wire cpu_rst_n;
	output wire fabric_clk;
	output wire fabric_rst_n;
	assign cpu_clk = clk_in;
	assign fabric_clk = clk_in;
	reg [SYNC_STAGES - 1:0] cpu_rst_sync;
	always @(posedge cpu_clk or negedge rst_in_n)
		if (!rst_in_n)
			cpu_rst_sync <= 1'sb0;
		else
			cpu_rst_sync <= {cpu_rst_sync[SYNC_STAGES - 2:0], 1'b1};
	assign cpu_rst_n = cpu_rst_sync[SYNC_STAGES - 1];
	reg [SYNC_STAGES - 1:0] fabric_rst_sync;
	always @(posedge fabric_clk or negedge rst_in_n)
		if (!rst_in_n)
			fabric_rst_sync <= 1'sb0;
		else
			fabric_rst_sync <= {fabric_rst_sync[SYNC_STAGES - 2:0], 1'b1};
	assign fabric_rst_n = fabric_rst_sync[SYNC_STAGES - 1];
endmodule
module async_fifo (
	wr_clk,
	wr_rst_n,
	wr_en,
	wr_data,
	wr_full,
	rd_clk,
	rd_rst_n,
	rd_en,
	rd_data,
	rd_empty
);
	parameter DATA_WIDTH = 128;
	parameter ADDR_WIDTH = 4;
	input wire wr_clk;
	input wire wr_rst_n;
	input wire wr_en;
	input wire [DATA_WIDTH - 1:0] wr_data;
	output wire wr_full;
	input wire rd_clk;
	input wire rd_rst_n;
	input wire rd_en;
	output wire [DATA_WIDTH - 1:0] rd_data;
	output wire rd_empty;
	localparam DEPTH = 1 << ADDR_WIDTH;
	reg [DATA_WIDTH - 1:0] mem [0:DEPTH - 1];
	reg [ADDR_WIDTH:0] wr_ptr;
	reg [ADDR_WIDTH:0] rd_ptr;
	reg [ADDR_WIDTH:0] wr_ptr_sync1;
	reg [ADDR_WIDTH:0] wr_ptr_sync2;
	reg [ADDR_WIDTH:0] rd_ptr_sync1;
	reg [ADDR_WIDTH:0] rd_ptr_sync2;
	always @(posedge wr_clk or negedge wr_rst_n)
		if (!wr_rst_n)
			wr_ptr <= 0;
		else if (wr_en && !wr_full) begin
			mem[wr_ptr[ADDR_WIDTH - 1:0]] <= wr_data;
			wr_ptr <= wr_ptr + 1;
		end
	always @(posedge rd_clk or negedge rd_rst_n)
		if (!rd_rst_n)
			rd_ptr <= 0;
		else if (rd_en && !rd_empty)
			rd_ptr <= rd_ptr + 1;
	assign rd_data = mem[rd_ptr[ADDR_WIDTH - 1:0]];
	always @(posedge wr_clk or negedge wr_rst_n)
		if (!wr_rst_n) begin
			rd_ptr_sync1 <= 0;
			rd_ptr_sync2 <= 0;
		end
		else begin
			rd_ptr_sync1 <= rd_ptr;
			rd_ptr_sync2 <= rd_ptr_sync1;
		end
	always @(posedge rd_clk or negedge rd_rst_n)
		if (!rd_rst_n) begin
			wr_ptr_sync1 <= 0;
			wr_ptr_sync2 <= 0;
		end
		else begin
			wr_ptr_sync1 <= wr_ptr;
			wr_ptr_sync2 <= wr_ptr_sync1;
		end
	assign wr_full = (wr_ptr[ADDR_WIDTH] != rd_ptr_sync2[ADDR_WIDTH]) && (wr_ptr[ADDR_WIDTH - 1:0] == rd_ptr_sync2[ADDR_WIDTH - 1:0]);
	assign rd_empty = rd_ptr == wr_ptr_sync2;
endmodule
module axi_cdc_bridge (
	cpu_clk,
	cpu_rst_n,
	fabric_clk,
	fabric_rst_n,
	s_axi_awid,
	s_axi_awaddr,
	s_axi_awvalid,
	s_axi_awready,
	s_axi_wdata,
	s_axi_wvalid,
	s_axi_wready,
	s_axi_bid,
	s_axi_bvalid,
	s_axi_bready,
	s_axi_arid,
	s_axi_araddr,
	s_axi_arvalid,
	s_axi_arready,
	s_axi_rid,
	s_axi_rdata,
	s_axi_rvalid,
	s_axi_rready,
	m_axi_awid,
	m_axi_awaddr,
	m_axi_awvalid,
	m_axi_awready,
	m_axi_wdata,
	m_axi_wvalid,
	m_axi_wready,
	m_axi_bid,
	m_axi_bvalid,
	m_axi_bready,
	m_axi_arid,
	m_axi_araddr,
	m_axi_arvalid,
	m_axi_arready,
	m_axi_rid,
	m_axi_rdata,
	m_axi_rvalid,
	m_axi_rready
);
	parameter DATA_WIDTH = 128;
	parameter ADDR_WIDTH = 32;
	parameter ID_WIDTH = 4;
	input wire cpu_clk;
	input wire cpu_rst_n;
	input wire fabric_clk;
	input wire fabric_rst_n;
	input wire [ID_WIDTH - 1:0] s_axi_awid;
	input wire [ADDR_WIDTH - 1:0] s_axi_awaddr;
	input wire s_axi_awvalid;
	output wire s_axi_awready;
	input wire [DATA_WIDTH - 1:0] s_axi_wdata;
	input wire s_axi_wvalid;
	output wire s_axi_wready;
	output wire [ID_WIDTH - 1:0] s_axi_bid;
	output wire s_axi_bvalid;
	input wire s_axi_bready;
	input wire [ID_WIDTH - 1:0] s_axi_arid;
	input wire [ADDR_WIDTH - 1:0] s_axi_araddr;
	input wire s_axi_arvalid;
	output wire s_axi_arready;
	output wire [ID_WIDTH - 1:0] s_axi_rid;
	output wire [DATA_WIDTH - 1:0] s_axi_rdata;
	output wire s_axi_rvalid;
	input wire s_axi_rready;
	output wire [ID_WIDTH - 1:0] m_axi_awid;
	output wire [ADDR_WIDTH - 1:0] m_axi_awaddr;
	output wire m_axi_awvalid;
	input wire m_axi_awready;
	output wire [DATA_WIDTH - 1:0] m_axi_wdata;
	output wire m_axi_wvalid;
	input wire m_axi_wready;
	input wire [ID_WIDTH - 1:0] m_axi_bid;
	input wire m_axi_bvalid;
	output wire m_axi_bready;
	output wire [ID_WIDTH - 1:0] m_axi_arid;
	output wire [ADDR_WIDTH - 1:0] m_axi_araddr;
	output wire m_axi_arvalid;
	input wire m_axi_arready;
	input wire [ID_WIDTH - 1:0] m_axi_rid;
	input wire [DATA_WIDTH - 1:0] m_axi_rdata;
	input wire m_axi_rvalid;
	output wire m_axi_rready;
	localparam AW_WIDTH = ID_WIDTH + ADDR_WIDTH;
	wire [AW_WIDTH - 1:0] aw_wdata;
	wire [AW_WIDTH - 1:0] aw_rdata;
	wire aw_full;
	wire aw_empty;
	wire aw_wr_en;
	wire aw_rd_en;
	assign aw_wdata = {s_axi_awid, s_axi_awaddr};
	assign s_axi_awready = !aw_full;
	assign aw_wr_en = s_axi_awvalid && s_axi_awready;
	assign m_axi_awvalid = !aw_empty;
	assign aw_rd_en = m_axi_awvalid && m_axi_awready;
	assign {m_axi_awid, m_axi_awaddr} = aw_rdata;
	async_fifo #(
		.DATA_WIDTH(AW_WIDTH),
		.ADDR_WIDTH(4)
	) aw_fifo(
		.wr_clk(cpu_clk),
		.wr_rst_n(cpu_rst_n),
		.wr_en(aw_wr_en),
		.wr_data(aw_wdata),
		.wr_full(aw_full),
		.rd_clk(fabric_clk),
		.rd_rst_n(fabric_rst_n),
		.rd_en(aw_rd_en),
		.rd_data(aw_rdata),
		.rd_empty(aw_empty)
	);
	localparam W_WIDTH = DATA_WIDTH;
	wire [W_WIDTH - 1:0] w_wdata;
	wire [W_WIDTH - 1:0] w_rdata;
	wire w_full;
	wire w_empty;
	wire w_wr_en;
	wire w_rd_en;
	assign w_wdata = s_axi_wdata;
	assign s_axi_wready = !w_full;
	assign w_wr_en = s_axi_wvalid && s_axi_wready;
	assign m_axi_wvalid = !w_empty;
	assign w_rd_en = m_axi_wvalid && m_axi_wready;
	assign m_axi_wdata = w_rdata;
	async_fifo #(
		.DATA_WIDTH(W_WIDTH),
		.ADDR_WIDTH(4)
	) w_fifo(
		.wr_clk(cpu_clk),
		.wr_rst_n(cpu_rst_n),
		.wr_en(w_wr_en),
		.wr_data(w_wdata),
		.wr_full(w_full),
		.rd_clk(fabric_clk),
		.rd_rst_n(fabric_rst_n),
		.rd_en(w_rd_en),
		.rd_data(w_rdata),
		.rd_empty(w_empty)
	);
	localparam B_WIDTH = ID_WIDTH;
	wire [B_WIDTH - 1:0] b_wdata;
	wire [B_WIDTH - 1:0] b_rdata;
	wire b_full;
	wire b_empty;
	wire b_wr_en;
	wire b_rd_en;
	assign b_wdata = m_axi_bid;
	assign m_axi_bready = !b_full;
	assign b_wr_en = m_axi_bvalid && m_axi_bready;
	assign s_axi_bvalid = !b_empty;
	assign b_rd_en = s_axi_bvalid && s_axi_bready;
	assign s_axi_bid = b_rdata;
	async_fifo #(
		.DATA_WIDTH(B_WIDTH),
		.ADDR_WIDTH(4)
	) b_fifo(
		.wr_clk(fabric_clk),
		.wr_rst_n(fabric_rst_n),
		.wr_en(b_wr_en),
		.wr_data(b_wdata),
		.wr_full(b_full),
		.rd_clk(cpu_clk),
		.rd_rst_n(cpu_rst_n),
		.rd_en(b_rd_en),
		.rd_data(b_rdata),
		.rd_empty(b_empty)
	);
	localparam AR_WIDTH = ID_WIDTH + ADDR_WIDTH;
	wire [AR_WIDTH - 1:0] ar_wdata;
	wire [AR_WIDTH - 1:0] ar_rdata;
	wire ar_full;
	wire ar_empty;
	wire ar_wr_en;
	wire ar_rd_en;
	assign ar_wdata = {s_axi_arid, s_axi_araddr};
	assign s_axi_arready = !ar_full;
	assign ar_wr_en = s_axi_arvalid && s_axi_arready;
	assign m_axi_arvalid = !ar_empty;
	assign ar_rd_en = m_axi_arvalid && m_axi_arready;
	assign {m_axi_arid, m_axi_araddr} = ar_rdata;
	async_fifo #(
		.DATA_WIDTH(AR_WIDTH),
		.ADDR_WIDTH(4)
	) ar_fifo(
		.wr_clk(cpu_clk),
		.wr_rst_n(cpu_rst_n),
		.wr_en(ar_wr_en),
		.wr_data(ar_wdata),
		.wr_full(ar_full),
		.rd_clk(fabric_clk),
		.rd_rst_n(fabric_rst_n),
		.rd_en(ar_rd_en),
		.rd_data(ar_rdata),
		.rd_empty(ar_empty)
	);
	localparam R_WIDTH = ID_WIDTH + DATA_WIDTH;
	wire [R_WIDTH - 1:0] r_wdata;
	wire [R_WIDTH - 1:0] r_rdata;
	wire r_full;
	wire r_empty;
	wire r_wr_en;
	wire r_rd_en;
	assign r_wdata = {m_axi_rid, m_axi_rdata};
	assign m_axi_rready = !r_full;
	assign r_wr_en = m_axi_rvalid && m_axi_rready;
	assign s_axi_rvalid = !r_empty;
	assign r_rd_en = s_axi_rvalid && s_axi_rready;
	assign {s_axi_rid, s_axi_rdata} = r_rdata;
	async_fifo #(
		.DATA_WIDTH(R_WIDTH),
		.ADDR_WIDTH(4)
	) r_fifo(
		.wr_clk(fabric_clk),
		.wr_rst_n(fabric_rst_n),
		.wr_en(r_wr_en),
		.wr_data(r_wdata),
		.wr_full(r_full),
		.rd_clk(cpu_clk),
		.rd_rst_n(cpu_rst_n),
		.rd_en(r_rd_en),
		.rd_data(r_rdata),
		.rd_empty(r_empty)
	);
endmodule
module axi_crossbar (
	clk,
	rst_n,
	m_awaddr,
	m_awvalid,
	m_awready,
	m_wdata,
	m_wstrb,
	m_wvalid,
	m_wready,
	m_bvalid,
	m_bready,
	m_araddr,
	m_arvalid,
	m_arready,
	m_rdata,
	m_rvalid,
	m_rready,
	s_awaddr,
	s_awvalid,
	s_awready,
	s_wdata,
	s_wstrb,
	s_wvalid,
	s_wready,
	s_bvalid,
	s_bready,
	s_araddr,
	s_arvalid,
	s_arready,
	s_rdata,
	s_rvalid,
	s_rready
);
	reg _sv2v_0;
	parameter DATA_WIDTH = 128;
	parameter ADDR_WIDTH = 32;
	parameter ID_WIDTH = 4;
	parameter NUM_MASTERS = 8;
	parameter NUM_SLAVES = 8;
	input wire clk;
	input wire rst_n;
	input wire [(NUM_MASTERS * ADDR_WIDTH) - 1:0] m_awaddr;
	input wire [NUM_MASTERS - 1:0] m_awvalid;
	output reg [NUM_MASTERS - 1:0] m_awready;
	input wire [(NUM_MASTERS * DATA_WIDTH) - 1:0] m_wdata;
	input wire [(NUM_MASTERS * (DATA_WIDTH / 8)) - 1:0] m_wstrb;
	input wire [NUM_MASTERS - 1:0] m_wvalid;
	output reg [NUM_MASTERS - 1:0] m_wready;
	output reg [NUM_MASTERS - 1:0] m_bvalid;
	input wire [NUM_MASTERS - 1:0] m_bready;
	input wire [(NUM_MASTERS * ADDR_WIDTH) - 1:0] m_araddr;
	input wire [NUM_MASTERS - 1:0] m_arvalid;
	output reg [NUM_MASTERS - 1:0] m_arready;
	output reg [(NUM_MASTERS * DATA_WIDTH) - 1:0] m_rdata;
	output reg [NUM_MASTERS - 1:0] m_rvalid;
	input wire [NUM_MASTERS - 1:0] m_rready;
	output reg [(NUM_SLAVES * ADDR_WIDTH) - 1:0] s_awaddr;
	output reg [NUM_SLAVES - 1:0] s_awvalid;
	input wire [NUM_SLAVES - 1:0] s_awready;
	output reg [(NUM_SLAVES * DATA_WIDTH) - 1:0] s_wdata;
	output reg [(NUM_SLAVES * (DATA_WIDTH / 8)) - 1:0] s_wstrb;
	output reg [NUM_SLAVES - 1:0] s_wvalid;
	input wire [NUM_SLAVES - 1:0] s_wready;
	input wire [NUM_SLAVES - 1:0] s_bvalid;
	output reg [NUM_SLAVES - 1:0] s_bready;
	output reg [(NUM_SLAVES * ADDR_WIDTH) - 1:0] s_araddr;
	output reg [NUM_SLAVES - 1:0] s_arvalid;
	input wire [NUM_SLAVES - 1:0] s_arready;
	input wire [(NUM_SLAVES * DATA_WIDTH) - 1:0] s_rdata;
	input wire [NUM_SLAVES - 1:0] s_rvalid;
	output reg [NUM_SLAVES - 1:0] s_rready;
	localparam signed [31:0] MW = $clog2(NUM_MASTERS);
	function automatic [2:0] decode_address;
		input reg [ADDR_WIDTH - 1:0] addr;
		if (addr[31:24] == 8'h00)
			decode_address = 3'd0;
		else if ((((addr[31:24] == 8'h10) || (addr[31:24] == 8'h11)) || (addr[31:24] == 8'h12)) || (addr[31:24] == 8'h13))
			decode_address = 3'd1;
		else if (addr[31:24] == 8'h20)
			decode_address = 3'd2;
		else if (addr[31:24] == 8'h30)
			decode_address = 3'd3;
		else if (addr[31:24] == 8'h40)
			decode_address = 3'd4;
		else if (addr[31:24] == 8'h50)
			decode_address = 3'd5;
		else if (addr[31:24] == 8'h60)
			decode_address = 3'd6;
		else
			decode_address = 3'd7;
	endfunction
	function automatic signed [MW - 1:0] sv2v_cast_73DDD_signed;
		input reg signed [MW - 1:0] inp;
		sv2v_cast_73DDD_signed = inp;
	endfunction
	function automatic [MW:0] rr_pick;
		input reg [NUM_MASTERS - 1:0] req;
		input reg [MW - 1:0] ptr;
		reg [MW - 1:0] idx;
		begin
			rr_pick = 1'sb0;
			begin : sv2v_autoblock_1
				reg signed [31:0] k;
				for (k = NUM_MASTERS - 1; k >= 0; k = k - 1)
					begin
						idx = ptr + sv2v_cast_73DDD_signed(k);
						if (req[idx])
							rr_pick = {1'b1, idx};
					end
			end
		end
	endfunction
	reg [NUM_SLAVES - 1:0] wr_busy;
	reg [(NUM_SLAVES * MW) - 1:0] wr_owner;
	reg [(NUM_SLAVES * MW) - 1:0] wr_rr_ptr;
	reg [NUM_MASTERS - 1:0] m_wr_outstanding;
	reg [(NUM_SLAVES * NUM_MASTERS) - 1:0] wr_req;
	function automatic signed [2:0] sv2v_cast_3_signed;
		input reg signed [2:0] inp;
		sv2v_cast_3_signed = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_2
			reg signed [31:0] mm;
			for (mm = 0; mm < NUM_MASTERS; mm = mm + 1)
				begin
					m_wr_outstanding[mm] = 1'b0;
					begin : sv2v_autoblock_3
						reg signed [31:0] ss;
						for (ss = 0; ss < NUM_SLAVES; ss = ss + 1)
							if (wr_busy[ss] && (wr_owner[ss * MW+:MW] == sv2v_cast_73DDD_signed(mm)))
								m_wr_outstanding[mm] = 1'b1;
					end
				end
		end
		begin : sv2v_autoblock_4
			reg signed [31:0] ss;
			for (ss = 0; ss < NUM_SLAVES; ss = ss + 1)
				begin : sv2v_autoblock_5
					reg signed [31:0] mm;
					for (mm = 0; mm < NUM_MASTERS; mm = mm + 1)
						wr_req[(ss * NUM_MASTERS) + mm] = (m_awvalid[mm] && !m_wr_outstanding[mm]) && (decode_address(m_awaddr[mm * ADDR_WIDTH+:ADDR_WIDTH]) == sv2v_cast_3_signed(ss));
				end
		end
	end
	reg [NUM_SLAVES - 1:0] wr_act;
	reg [(NUM_SLAVES * MW) - 1:0] wr_gnt;
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_6
			reg signed [31:0] ss;
			for (ss = 0; ss < NUM_SLAVES; ss = ss + 1)
				begin : sv2v_autoblock_7
					reg [MW:0] pick;
					pick = rr_pick(wr_req[ss * NUM_MASTERS+:NUM_MASTERS], wr_rr_ptr[ss * MW+:MW]);
					if (wr_busy[ss]) begin
						wr_act[ss] = 1'b1;
						wr_gnt[ss * MW+:MW] = wr_owner[ss * MW+:MW];
					end
					else begin
						wr_act[ss] = pick[MW];
						wr_gnt[ss * MW+:MW] = pick[MW - 1:0];
					end
				end
		end
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			wr_busy <= 1'sb0;
			wr_owner <= 1'sb0;
			wr_rr_ptr <= 1'sb0;
		end
		else begin : sv2v_autoblock_8
			reg signed [31:0] ss;
			for (ss = 0; ss < NUM_SLAVES; ss = ss + 1)
				if ((!wr_busy[ss] && s_awvalid[ss]) && s_awready[ss]) begin
					wr_busy[ss] <= 1'b1;
					wr_owner[ss * MW+:MW] <= wr_gnt[ss * MW+:MW];
				end
				else if ((wr_busy[ss] && s_bvalid[ss]) && s_bready[ss]) begin
					wr_busy[ss] <= 1'b0;
					wr_rr_ptr[ss * MW+:MW] <= wr_owner[ss * MW+:MW] + sv2v_cast_73DDD_signed(1);
				end
		end
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_9
			reg signed [31:0] ss;
			for (ss = 0; ss < NUM_SLAVES; ss = ss + 1)
				if (wr_act[ss]) begin
					s_awaddr[ss * ADDR_WIDTH+:ADDR_WIDTH] = m_awaddr[wr_gnt[ss * MW+:MW] * ADDR_WIDTH+:ADDR_WIDTH];
					s_awvalid[ss] = !wr_busy[ss] && m_awvalid[wr_gnt[ss * MW+:MW]];
					s_wdata[ss * DATA_WIDTH+:DATA_WIDTH] = m_wdata[wr_gnt[ss * MW+:MW] * DATA_WIDTH+:DATA_WIDTH];
					s_wstrb[ss * (DATA_WIDTH / 8)+:DATA_WIDTH / 8] = m_wstrb[wr_gnt[ss * MW+:MW] * (DATA_WIDTH / 8)+:DATA_WIDTH / 8];
					s_wvalid[ss] = m_wvalid[wr_gnt[ss * MW+:MW]];
					s_bready[ss] = m_bready[wr_gnt[ss * MW+:MW]];
				end
				else begin
					s_awaddr[ss * ADDR_WIDTH+:ADDR_WIDTH] = 1'sb0;
					s_awvalid[ss] = 1'b0;
					s_wdata[ss * DATA_WIDTH+:DATA_WIDTH] = 1'sb0;
					s_wstrb[ss * (DATA_WIDTH / 8)+:DATA_WIDTH / 8] = 1'sb0;
					s_wvalid[ss] = 1'b0;
					s_bready[ss] = 1'b0;
				end
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_10
			reg signed [31:0] mm;
			for (mm = 0; mm < NUM_MASTERS; mm = mm + 1)
				begin
					m_awready[mm] = 1'b0;
					m_wready[mm] = 1'b0;
					m_bvalid[mm] = 1'b0;
					begin : sv2v_autoblock_11
						reg signed [31:0] ss;
						for (ss = 0; ss < NUM_SLAVES; ss = ss + 1)
							if (wr_act[ss] && (wr_gnt[ss * MW+:MW] == sv2v_cast_73DDD_signed(mm))) begin
								m_awready[mm] = m_awready[mm] | (!wr_busy[ss] && s_awready[ss]);
								m_wready[mm] = m_wready[mm] | s_wready[ss];
								m_bvalid[mm] = m_bvalid[mm] | s_bvalid[ss];
							end
					end
				end
		end
	end
	reg [NUM_SLAVES - 1:0] rd_busy;
	reg [(NUM_SLAVES * MW) - 1:0] rd_owner;
	reg [(NUM_SLAVES * MW) - 1:0] rd_rr_ptr;
	reg [NUM_MASTERS - 1:0] m_rd_outstanding;
	reg [(NUM_SLAVES * NUM_MASTERS) - 1:0] rd_req;
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_12
			reg signed [31:0] mm;
			for (mm = 0; mm < NUM_MASTERS; mm = mm + 1)
				begin
					m_rd_outstanding[mm] = 1'b0;
					begin : sv2v_autoblock_13
						reg signed [31:0] ss;
						for (ss = 0; ss < NUM_SLAVES; ss = ss + 1)
							if (rd_busy[ss] && (rd_owner[ss * MW+:MW] == sv2v_cast_73DDD_signed(mm)))
								m_rd_outstanding[mm] = 1'b1;
					end
				end
		end
		begin : sv2v_autoblock_14
			reg signed [31:0] ss;
			for (ss = 0; ss < NUM_SLAVES; ss = ss + 1)
				begin : sv2v_autoblock_15
					reg signed [31:0] mm;
					for (mm = 0; mm < NUM_MASTERS; mm = mm + 1)
						rd_req[(ss * NUM_MASTERS) + mm] = (m_arvalid[mm] && !m_rd_outstanding[mm]) && (decode_address(m_araddr[mm * ADDR_WIDTH+:ADDR_WIDTH]) == sv2v_cast_3_signed(ss));
				end
		end
	end
	reg [NUM_SLAVES - 1:0] rd_act;
	reg [(NUM_SLAVES * MW) - 1:0] rd_gnt;
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_16
			reg signed [31:0] ss;
			for (ss = 0; ss < NUM_SLAVES; ss = ss + 1)
				begin : sv2v_autoblock_17
					reg [MW:0] pick;
					pick = rr_pick(rd_req[ss * NUM_MASTERS+:NUM_MASTERS], rd_rr_ptr[ss * MW+:MW]);
					if (rd_busy[ss]) begin
						rd_act[ss] = 1'b1;
						rd_gnt[ss * MW+:MW] = rd_owner[ss * MW+:MW];
					end
					else begin
						rd_act[ss] = pick[MW];
						rd_gnt[ss * MW+:MW] = pick[MW - 1:0];
					end
				end
		end
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			rd_busy <= 1'sb0;
			rd_owner <= 1'sb0;
			rd_rr_ptr <= 1'sb0;
		end
		else begin : sv2v_autoblock_18
			reg signed [31:0] ss;
			for (ss = 0; ss < NUM_SLAVES; ss = ss + 1)
				if ((!rd_busy[ss] && s_arvalid[ss]) && s_arready[ss]) begin
					rd_busy[ss] <= 1'b1;
					rd_owner[ss * MW+:MW] <= rd_gnt[ss * MW+:MW];
				end
				else if ((rd_busy[ss] && s_rvalid[ss]) && s_rready[ss]) begin
					rd_busy[ss] <= 1'b0;
					rd_rr_ptr[ss * MW+:MW] <= rd_owner[ss * MW+:MW] + sv2v_cast_73DDD_signed(1);
				end
		end
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_19
			reg signed [31:0] ss;
			for (ss = 0; ss < NUM_SLAVES; ss = ss + 1)
				if (rd_act[ss]) begin
					s_araddr[ss * ADDR_WIDTH+:ADDR_WIDTH] = m_araddr[rd_gnt[ss * MW+:MW] * ADDR_WIDTH+:ADDR_WIDTH];
					s_arvalid[ss] = !rd_busy[ss] && m_arvalid[rd_gnt[ss * MW+:MW]];
					s_rready[ss] = m_rready[rd_gnt[ss * MW+:MW]];
				end
				else begin
					s_araddr[ss * ADDR_WIDTH+:ADDR_WIDTH] = 1'sb0;
					s_arvalid[ss] = 1'b0;
					s_rready[ss] = 1'b0;
				end
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_20
			reg signed [31:0] mm;
			for (mm = 0; mm < NUM_MASTERS; mm = mm + 1)
				begin
					m_arready[mm] = 1'b0;
					m_rvalid[mm] = 1'b0;
					m_rdata[mm * DATA_WIDTH+:DATA_WIDTH] = 1'sb0;
					begin : sv2v_autoblock_21
						reg signed [31:0] ss;
						for (ss = 0; ss < NUM_SLAVES; ss = ss + 1)
							if (rd_act[ss] && (rd_gnt[ss * MW+:MW] == sv2v_cast_73DDD_signed(mm))) begin
								m_arready[mm] = m_arready[mm] | (!rd_busy[ss] && s_arready[ss]);
								if (s_rvalid[ss]) begin
									m_rvalid[mm] = 1'b1;
									m_rdata[mm * DATA_WIDTH+:DATA_WIDTH] = s_rdata[ss * DATA_WIDTH+:DATA_WIDTH];
								end
							end
					end
				end
		end
	end
	initial _sv2v_0 = 0;
endmodule
module boot_rom (
	clk,
	rst_n,
	s_axi_araddr,
	s_axi_arvalid,
	s_axi_arready,
	s_axi_rdata,
	s_axi_rvalid,
	s_axi_rready,
	s_axi_awaddr,
	s_axi_awvalid,
	s_axi_awready,
	s_axi_wdata,
	s_axi_wvalid,
	s_axi_wready,
	s_axi_bvalid,
	s_axi_bready
);
	parameter ADDR_WIDTH = 32;
	parameter DATA_WIDTH = 128;
	parameter ROM_SIZE = 65536;
	input wire clk;
	input wire rst_n;
	input wire [ADDR_WIDTH - 1:0] s_axi_araddr;
	input wire s_axi_arvalid;
	output wire s_axi_arready;
	output reg [DATA_WIDTH - 1:0] s_axi_rdata;
	output reg s_axi_rvalid;
	input wire s_axi_rready;
	input wire [ADDR_WIDTH - 1:0] s_axi_awaddr;
	input wire s_axi_awvalid;
	output wire s_axi_awready;
	input wire [DATA_WIDTH - 1:0] s_axi_wdata;
	input wire s_axi_wvalid;
	output wire s_axi_wready;
	output reg s_axi_bvalid;
	input wire s_axi_bready;
	localparam ROM_DEPTH = ROM_SIZE / (DATA_WIDTH / 8);
	reg [DATA_WIDTH - 1:0] rom_mem [0:ROM_DEPTH - 1];
	initial begin : sv2v_autoblock_1
		integer i;
		for (i = 0; i < ROM_DEPTH; i = i + 1)
			rom_mem[i] = 1'sb0;
		$readmemh("/home/yashwanth/aurora_v1/boot/aurora_boot.hex", rom_mem);
	end
	wire [15:0] read_addr;
	assign read_addr = s_axi_araddr[19:4];
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			s_axi_rdata <= 1'sb0;
			s_axi_rvalid <= 1'b0;
		end
		else if (s_axi_arvalid && s_axi_arready) begin
			s_axi_rdata <= (sv2v_cast_32(read_addr) < ROM_DEPTH ? rom_mem[read_addr[$clog2(ROM_DEPTH) - 1:0]] : {4 {32'hdeadbeef}});
			s_axi_rvalid <= 1'b1;
		end
		else if (s_axi_rready)
			s_axi_rvalid <= 1'b0;
	assign s_axi_arready = !s_axi_rvalid || s_axi_rready;
	assign s_axi_awready = 1'b1;
	assign s_axi_wready = 1'b1;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			s_axi_bvalid <= 1'b0;
		else if (s_axi_awvalid && s_axi_wvalid)
			s_axi_bvalid <= 1'b1;
		else if (s_axi_bready)
			s_axi_bvalid <= 1'b0;
endmodule
module sram_bank_array (
	clk,
	rst_n,
	awaddr,
	awvalid,
	awready,
	wdata,
	wstrb,
	wvalid,
	wready,
	bvalid,
	bready,
	araddr,
	arvalid,
	arready,
	rdata,
	rvalid,
	rready
);
	parameter DATA_WIDTH = 128;
	parameter ADDR_WIDTH = 32;
	parameter NUM_BANKS = 8;
	parameter BANK_DEPTH = 32768;
	input wire clk;
	input wire rst_n;
	input wire [ADDR_WIDTH - 1:0] awaddr;
	input wire awvalid;
	output wire awready;
	input wire [DATA_WIDTH - 1:0] wdata;
	input wire [(DATA_WIDTH / 8) - 1:0] wstrb;
	input wire wvalid;
	output wire wready;
	output wire bvalid;
	input wire bready;
	input wire [ADDR_WIDTH - 1:0] araddr;
	input wire arvalid;
	output wire arready;
	output wire [DATA_WIDTH - 1:0] rdata;
	output wire rvalid;
	input wire rready;
	reg [DATA_WIDTH - 1:0] bank_mem [NUM_BANKS - 1:0][BANK_DEPTH - 1:0];
	localparam signed [31:0] WORD_OFF = $clog2(DATA_WIDTH / 8);
	localparam signed [31:0] IDX_W = $clog2(BANK_DEPTH);
	localparam signed [31:0] BANK_W = (NUM_BANKS > 1 ? $clog2(NUM_BANKS) : 1);
	wire [BANK_W - 1:0] write_bank;
	wire [BANK_W - 1:0] read_bank;
	wire [IDX_W - 1:0] write_index;
	wire [IDX_W - 1:0] read_index;
	assign write_index = awaddr[WORD_OFF+:IDX_W];
	assign read_index = araddr[WORD_OFF+:IDX_W];
	assign write_bank = (NUM_BANKS > 1 ? awaddr[WORD_OFF + IDX_W+:BANK_W] : {BANK_W {1'sb0}});
	assign read_bank = (NUM_BANKS > 1 ? araddr[WORD_OFF + IDX_W+:BANK_W] : {BANK_W {1'sb0}});
	assign awready = 1'b1;
	assign wready = 1'b1;
	always @(posedge clk)
		if (awvalid && wvalid) begin : sv2v_autoblock_1
			reg signed [31:0] b;
			for (b = 0; b < (DATA_WIDTH / 8); b = b + 1)
				if (wstrb[b])
					bank_mem[write_bank][write_index][8 * b+:8] <= wdata[8 * b+:8];
		end
	reg bvalid_reg;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			bvalid_reg <= 0;
		else if (awvalid && wvalid)
			bvalid_reg <= 1;
		else if (bready)
			bvalid_reg <= 0;
	assign bvalid = bvalid_reg;
	assign arready = 1'b1;
	reg [DATA_WIDTH - 1:0] rdata_reg;
	reg rvalid_reg;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			rvalid_reg <= 0;
		else if (arvalid) begin
			rdata_reg <= bank_mem[read_bank][read_index];
			rvalid_reg <= 1;
		end
		else if (rready)
			rvalid_reg <= 0;
	assign rdata = rdata_reg;
	assign rvalid = rvalid_reg;
endmodule
module dma_engine_complete (
	clk,
	rst_n,
	s_axil_awaddr,
	s_axil_awvalid,
	s_axil_awready,
	s_axil_wdata,
	s_axil_wvalid,
	s_axil_wready,
	s_axil_bvalid,
	s_axil_bready,
	s_axil_araddr,
	s_axil_arvalid,
	s_axil_arready,
	s_axil_rdata,
	s_axil_rvalid,
	s_axil_rready,
	m_axi_araddr,
	m_axi_arlen,
	m_axi_arsize,
	m_axi_arvalid,
	m_axi_arready,
	m_axi_rdata,
	m_axi_rlast,
	m_axi_rvalid,
	m_axi_rready,
	m_axi_awaddr,
	m_axi_awlen,
	m_axi_awsize,
	m_axi_awvalid,
	m_axi_awready,
	m_axi_wdata,
	m_axi_wlast,
	m_axi_wvalid,
	m_axi_wready,
	m_axi_bvalid,
	m_axi_bready,
	irq
);
	reg _sv2v_0;
	parameter ADDR_WIDTH = 32;
	parameter DATA_WIDTH = 128;
	parameter CHANNEL_ID = 0;
	input wire clk;
	input wire rst_n;
	input wire [ADDR_WIDTH - 1:0] s_axil_awaddr;
	input wire s_axil_awvalid;
	output wire s_axil_awready;
	input wire [31:0] s_axil_wdata;
	input wire s_axil_wvalid;
	output wire s_axil_wready;
	output reg s_axil_bvalid;
	input wire s_axil_bready;
	input wire [ADDR_WIDTH - 1:0] s_axil_araddr;
	input wire s_axil_arvalid;
	output wire s_axil_arready;
	output reg [31:0] s_axil_rdata;
	output reg s_axil_rvalid;
	input wire s_axil_rready;
	output wire [ADDR_WIDTH - 1:0] m_axi_araddr;
	output wire [7:0] m_axi_arlen;
	output wire [2:0] m_axi_arsize;
	output wire m_axi_arvalid;
	input wire m_axi_arready;
	input wire [DATA_WIDTH - 1:0] m_axi_rdata;
	input wire m_axi_rlast;
	input wire m_axi_rvalid;
	output wire m_axi_rready;
	output wire [ADDR_WIDTH - 1:0] m_axi_awaddr;
	output wire [7:0] m_axi_awlen;
	output wire [2:0] m_axi_awsize;
	output wire m_axi_awvalid;
	input wire m_axi_awready;
	output wire [DATA_WIDTH - 1:0] m_axi_wdata;
	output wire m_axi_wlast;
	output wire m_axi_wvalid;
	input wire m_axi_wready;
	input wire m_axi_bvalid;
	output wire m_axi_bready;
	output wire irq;
	localparam [7:0] REG_CONTROL = 8'h00;
	localparam [7:0] REG_STATUS = 8'h04;
	localparam [7:0] REG_SRC_ADDR = 8'h08;
	localparam [7:0] REG_DST_ADDR = 8'h0c;
	localparam [7:0] REG_WIDTH = 8'h10;
	localparam [7:0] REG_HEIGHT = 8'h14;
	localparam [7:0] REG_SRC_STRIDE = 8'h18;
	localparam [7:0] REG_DST_STRIDE = 8'h1c;
	localparam [7:0] REG_INT_ENABLE = 8'h20;
	localparam [7:0] REG_INT_STATUS = 8'h24;
	reg [31:0] ctrl_reg;
	wire [31:0] status_reg;
	reg [31:0] src_addr_reg;
	reg [31:0] dst_addr_reg;
	reg [31:0] width_reg;
	reg [31:0] height_reg;
	reg [31:0] src_stride_reg;
	reg [31:0] dst_stride_reg;
	reg [31:0] int_enable_reg;
	reg [31:0] int_status_reg;
	wire ctrl_start = ctrl_reg[0];
	wire ctrl_stop = ctrl_reg[1];
	wire ctrl_mode_2d = ctrl_reg[8];
	wire status_idle;
	wire status_busy;
	wire status_done;
	wire status_error;
	assign status_reg = {28'h0000000, status_error, status_done, status_busy, status_idle};
	reg [3:0] state;
	reg [3:0] next_state;
	reg [ADDR_WIDTH - 1:0] current_src;
	reg [ADDR_WIDTH - 1:0] current_dst;
	reg [15:0] bytes_remaining;
	reg [15:0] rows_remaining;
	reg [DATA_WIDTH - 1:0] fifo_data [0:15];
	reg [3:0] fifo_wr_ptr;
	reg [3:0] fifo_rd_ptr;
	reg [4:0] fifo_count;
	wire fifo_full = fifo_count == 16;
	wire fifo_empty = fifo_count == 0;
	wire [7:0] wr_addr;
	assign wr_addr = s_axil_awaddr[7:0];
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			ctrl_reg <= 1'sb0;
			src_addr_reg <= 1'sb0;
			dst_addr_reg <= 1'sb0;
			width_reg <= 1'sb0;
			height_reg <= 32'h00000001;
			src_stride_reg <= 1'sb0;
			dst_stride_reg <= 1'sb0;
			int_enable_reg <= 1'sb0;
		end
		else begin
			ctrl_reg[0] <= 1'b0;
			if (s_axil_awvalid && s_axil_wvalid)
				case (wr_addr)
					REG_CONTROL: ctrl_reg <= s_axil_wdata;
					REG_SRC_ADDR: src_addr_reg <= s_axil_wdata;
					REG_DST_ADDR: dst_addr_reg <= s_axil_wdata;
					REG_WIDTH: width_reg <= s_axil_wdata;
					REG_HEIGHT: height_reg <= s_axil_wdata;
					REG_SRC_STRIDE: src_stride_reg <= s_axil_wdata;
					REG_DST_STRIDE: dst_stride_reg <= s_axil_wdata;
					REG_INT_ENABLE: int_enable_reg <= s_axil_wdata;
					default:
						;
				endcase
		end
	assign s_axil_awready = 1'b1;
	assign s_axil_wready = 1'b1;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			s_axil_bvalid <= 1'b0;
		else if (s_axil_awvalid && s_axil_wvalid)
			s_axil_bvalid <= 1'b1;
		else if (s_axil_bready)
			s_axil_bvalid <= 1'b0;
	wire [7:0] rd_addr;
	assign rd_addr = s_axil_araddr[7:0];
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			s_axil_rdata <= 1'sb0;
			s_axil_rvalid <= 1'b0;
		end
		else if (s_axil_arvalid) begin
			case (rd_addr)
				REG_CONTROL: s_axil_rdata <= ctrl_reg;
				REG_STATUS: s_axil_rdata <= status_reg;
				REG_SRC_ADDR: s_axil_rdata <= src_addr_reg;
				REG_DST_ADDR: s_axil_rdata <= dst_addr_reg;
				REG_WIDTH: s_axil_rdata <= width_reg;
				REG_HEIGHT: s_axil_rdata <= height_reg;
				REG_SRC_STRIDE: s_axil_rdata <= src_stride_reg;
				REG_DST_STRIDE: s_axil_rdata <= dst_stride_reg;
				REG_INT_ENABLE: s_axil_rdata <= int_enable_reg;
				REG_INT_STATUS: s_axil_rdata <= int_status_reg;
				default: s_axil_rdata <= 32'hdeadbeef;
			endcase
			s_axil_rvalid <= 1'b1;
		end
		else if (s_axil_rready)
			s_axil_rvalid <= 1'b0;
	assign s_axil_arready = 1'b1;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			state <= 4'h0;
		else
			state <= next_state;
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = state;
		case (state)
			4'h0:
				if (ctrl_start)
					next_state = 4'h1;
			4'h1:
				if (m_axi_arvalid && m_axi_arready)
					next_state = 4'h2;
			4'h2:
				if (m_axi_rvalid && m_axi_rlast)
					next_state = 4'h3;
			4'h3:
				if (m_axi_awvalid && m_axi_awready)
					next_state = 4'h4;
			4'h4:
				if ((m_axi_wvalid && m_axi_wlast) && m_axi_wready)
					next_state = 4'h5;
			4'h5:
				if (m_axi_bvalid) begin
					if (ctrl_mode_2d && (rows_remaining > 1))
						next_state = 4'h6;
					else
						next_state = 4'h7;
				end
			4'h6: next_state = 4'h1;
			4'h7: next_state = 4'h0;
			4'h8: next_state = 4'h0;
			default: next_state = 4'h0;
		endcase
		if (ctrl_stop)
			next_state = 4'h0;
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			current_src <= 1'sb0;
			current_dst <= 1'sb0;
			bytes_remaining <= 1'sb0;
			rows_remaining <= 1'sb0;
		end
		else
			case (state)
				4'h0:
					if (ctrl_start) begin
						current_src <= src_addr_reg;
						current_dst <= dst_addr_reg;
						bytes_remaining <= width_reg[15:0];
						rows_remaining <= height_reg[15:0];
					end
				4'h6: begin
					current_src <= current_src + src_stride_reg;
					current_dst <= current_dst + dst_stride_reg;
					bytes_remaining <= width_reg[15:0];
					rows_remaining <= rows_remaining - 1;
				end
				default:
					;
			endcase
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			fifo_wr_ptr <= 1'sb0;
			fifo_rd_ptr <= 1'sb0;
			fifo_count <= 1'sb0;
		end
		else begin
			if ((m_axi_rvalid && m_axi_rready) && !fifo_full) begin
				fifo_data[fifo_wr_ptr] <= m_axi_rdata;
				fifo_wr_ptr <= fifo_wr_ptr + 1;
				fifo_count <= fifo_count + 1;
			end
			if ((m_axi_wvalid && m_axi_wready) && !fifo_empty) begin
				fifo_rd_ptr <= fifo_rd_ptr + 1;
				fifo_count <= fifo_count - 1;
			end
			if (((m_axi_rvalid && m_axi_rready) && m_axi_wvalid) && m_axi_wready)
				fifo_count <= fifo_count;
			if (state == 4'h0) begin
				fifo_wr_ptr <= 1'sb0;
				fifo_rd_ptr <= 1'sb0;
				fifo_count <= 1'sb0;
			end
		end
	wire [7:0] burst_len;
	function automatic [7:0] sv2v_cast_8;
		input reg [7:0] inp;
		sv2v_cast_8 = inp;
	endfunction
	assign burst_len = (bytes_remaining > 16'd256 ? 8'd15 : sv2v_cast_8((bytes_remaining >> 4) - 16'd1));
	assign m_axi_araddr = current_src;
	assign m_axi_arlen = burst_len;
	assign m_axi_arsize = 3'b100;
	assign m_axi_arvalid = state == 4'h1;
	assign m_axi_rready = !fifo_full && (state == 4'h2);
	assign m_axi_awaddr = current_dst;
	assign m_axi_awlen = burst_len;
	assign m_axi_awsize = 3'b100;
	assign m_axi_awvalid = state == 4'h3;
	assign m_axi_wdata = fifo_data[fifo_rd_ptr];
	assign m_axi_wlast = sv2v_cast_8(fifo_rd_ptr) == burst_len;
	assign m_axi_wvalid = !fifo_empty && (state == 4'h4);
	assign m_axi_bready = state == 4'h5;
	assign status_idle = state == 4'h0;
	assign status_busy = ((state != 4'h0) && (state != 4'h7)) && (state != 4'h8);
	assign status_done = state == 4'h7;
	assign status_error = state == 4'h8;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			int_status_reg <= 1'sb0;
		else begin
			if (state == 4'h7)
				int_status_reg[0] <= 1'b1;
			if (state == 4'h8)
				int_status_reg[1] <= 1'b1;
			if ((s_axil_awvalid && s_axil_wvalid) && (wr_addr == REG_INT_STATUS))
				int_status_reg <= int_status_reg & ~s_axil_wdata;
		end
	assign irq = |(int_status_reg & int_enable_reg);
	initial _sv2v_0 = 0;
endmodule
module uart (
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
	uart_rxd,
	uart_txd,
	irq
);
	parameter CLK_FREQ = 200000000;
	parameter BAUD_RATE = 115200;
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
	input wire uart_rxd;
	output reg uart_txd;
	output wire irq;
	localparam REG_DATA = 8'h00;
	localparam REG_STATUS = 8'h04;
	localparam REG_CONTROL = 8'h08;
	localparam REG_DIVISOR = 8'h0c;
	localparam DIVISOR = CLK_FREQ / BAUD_RATE;
	reg [15:0] baud_counter;
	reg baud_tick;
	function automatic signed [15:0] sv2v_cast_16_signed;
		input reg signed [15:0] inp;
		sv2v_cast_16_signed = inp;
	endfunction
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			baud_counter <= 1'sb0;
			baud_tick <= 1'b0;
		end
		else if (baud_counter >= sv2v_cast_16_signed(DIVISOR - 1)) begin
			baud_counter <= 1'sb0;
			baud_tick <= 1'b1;
		end
		else begin
			baud_counter <= baud_counter + 1;
			baud_tick <= 1'b0;
		end
	reg [7:0] tx_fifo [0:15];
	reg [3:0] tx_wr_ptr;
	reg [3:0] tx_rd_ptr;
	reg [4:0] tx_count;
	wire tx_full = tx_count == 16;
	wire tx_empty = tx_count == 0;
	reg tx_pop;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			tx_wr_ptr <= 1'sb0;
			tx_rd_ptr <= 1'sb0;
			tx_count <= 1'sb0;
		end
		else begin
			if (((s_axi_awvalid && s_axi_wvalid) && (s_axi_awaddr[7:0] == REG_DATA)) && !tx_full) begin
				tx_fifo[tx_wr_ptr] <= s_axi_wdata[7:0];
				tx_wr_ptr <= tx_wr_ptr + 1;
				tx_count <= tx_count + 1;
			end
			if (tx_pop && !tx_empty) begin
				tx_rd_ptr <= tx_rd_ptr + 1;
				tx_count <= tx_count - 1;
			end
			if ((((s_axi_awvalid && s_axi_wvalid) && (s_axi_awaddr[7:0] == REG_DATA)) && !tx_full) && (tx_pop && !tx_empty))
				tx_count <= tx_count;
		end
	reg [7:0] rx_fifo [0:15];
	reg [3:0] rx_wr_ptr;
	reg [3:0] rx_rd_ptr;
	reg [4:0] rx_count;
	wire rx_full = rx_count == 16;
	wire rx_empty = rx_count == 0;
	reg [7:0] rx_data;
	reg rx_push;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			rx_wr_ptr <= 1'sb0;
			rx_rd_ptr <= 1'sb0;
			rx_count <= 1'sb0;
		end
		else begin
			if (rx_push && !rx_full) begin
				rx_fifo[rx_wr_ptr] <= rx_data;
				rx_wr_ptr <= rx_wr_ptr + 1;
				rx_count <= rx_count + 1;
			end
			if ((s_axi_arvalid && (s_axi_araddr[7:0] == REG_DATA)) && !rx_empty) begin
				rx_rd_ptr <= rx_rd_ptr + 1;
				rx_count <= rx_count - 1;
			end
			if ((rx_push && !rx_full) && ((s_axi_arvalid && (s_axi_araddr[7:0] == REG_DATA)) && !rx_empty))
				rx_count <= rx_count;
		end
	reg [2:0] tx_state;
	reg [7:0] tx_shift_reg;
	reg [2:0] tx_bit_count;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			tx_state <= 3'd0;
			uart_txd <= 1'b1;
			tx_shift_reg <= 1'sb0;
			tx_bit_count <= 1'sb0;
			tx_pop <= 1'b0;
		end
		else begin
			tx_pop <= 1'b0;
			case (tx_state)
				3'd0: begin
					uart_txd <= 1'b1;
					if (!tx_empty) begin
						tx_shift_reg <= tx_fifo[tx_rd_ptr];
						tx_pop <= 1'b1;
						tx_state <= 3'd1;
					end
				end
				3'd1:
					if (baud_tick) begin
						uart_txd <= 1'b0;
						tx_bit_count <= 1'sb0;
						tx_state <= 3'd2;
					end
				3'd2:
					if (baud_tick) begin
						uart_txd <= tx_shift_reg[0];
						tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
						tx_bit_count <= tx_bit_count + 1;
						if (tx_bit_count == 7)
							tx_state <= 3'd3;
					end
				3'd3:
					if (baud_tick) begin
						uart_txd <= 1'b1;
						tx_state <= 3'd0;
					end
				default: tx_state <= 3'd0;
			endcase
		end
	reg [2:0] rx_state;
	reg [7:0] rx_shift_reg;
	reg [2:0] rx_bit_count;
	reg [1:0] rxd_sync;
	always @(posedge clk) rxd_sync <= {rxd_sync[0], uart_rxd};
	wire rxd = rxd_sync[1];
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			rx_state <= 3'd0;
			rx_shift_reg <= 1'sb0;
			rx_bit_count <= 1'sb0;
			rx_push <= 1'b0;
			rx_data <= 1'sb0;
		end
		else begin
			rx_push <= 1'b0;
			case (rx_state)
				3'd0:
					if (!rxd)
						rx_state <= 3'd1;
				3'd1:
					if (baud_tick) begin
						if (!rxd) begin
							rx_bit_count <= 1'sb0;
							rx_state <= 3'd2;
						end
						else
							rx_state <= 3'd0;
					end
				3'd2:
					if (baud_tick) begin
						rx_shift_reg <= {rxd, rx_shift_reg[7:1]};
						rx_bit_count <= rx_bit_count + 1;
						if (rx_bit_count == 7)
							rx_state <= 3'd3;
					end
				3'd3:
					if (baud_tick) begin
						if (rxd) begin
							rx_data <= rx_shift_reg;
							rx_push <= 1'b1;
						end
						rx_state <= 3'd0;
					end
				default: rx_state <= 3'd0;
			endcase
		end
	assign s_axi_awready = 1'b1;
	assign s_axi_wready = 1'b1;
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
			case (s_axi_araddr[7:0])
				REG_DATA: s_axi_rdata <= {24'h000000, rx_fifo[rx_rd_ptr]};
				REG_STATUS: s_axi_rdata <= {26'h0000000, rx_full, rx_empty, tx_full, tx_empty, 2'b00};
				REG_CONTROL: s_axi_rdata <= 32'h00000000;
				REG_DIVISOR: s_axi_rdata <= DIVISOR;
				default: s_axi_rdata <= 32'hdeadbeef;
			endcase
			s_axi_rvalid <= 1'b1;
		end
		else if (s_axi_rready)
			s_axi_rvalid <= 1'b0;
	assign irq = !rx_empty;
endmodule
module gpio (
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
	gpio_in,
	gpio_out,
	gpio_oe,
	irq
);
	parameter NUM_PINS = 32;
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
	input wire [NUM_PINS - 1:0] gpio_in;
	output wire [NUM_PINS - 1:0] gpio_out;
	output wire [NUM_PINS - 1:0] gpio_oe;
	output wire irq;
	localparam REG_DATA_OUT = 8'h00;
	localparam REG_DATA_IN = 8'h04;
	localparam REG_DIR = 8'h08;
	localparam REG_INT_EN = 8'h0c;
	localparam REG_INT_MASK = 8'h10;
	localparam REG_INT_STAT = 8'h14;
	reg [NUM_PINS - 1:0] data_out_reg;
	reg [NUM_PINS - 1:0] data_in_reg;
	reg [NUM_PINS - 1:0] dir_reg;
	reg [NUM_PINS - 1:0] int_en_reg;
	reg [NUM_PINS - 1:0] int_mask_reg;
	reg [NUM_PINS - 1:0] int_stat_reg;
	reg [NUM_PINS - 1:0] gpio_in_sync1;
	reg [NUM_PINS - 1:0] gpio_in_sync2;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			gpio_in_sync1 <= 1'sb0;
			gpio_in_sync2 <= 1'sb0;
		end
		else begin
			gpio_in_sync1 <= gpio_in;
			gpio_in_sync2 <= gpio_in_sync1;
		end
	always @(posedge clk) data_in_reg <= gpio_in_sync2;
	assign gpio_out = data_out_reg;
	assign gpio_oe = dir_reg;
	reg [NUM_PINS - 1:0] gpio_in_prev;
	wire [NUM_PINS - 1:0] rising_edge;
	wire [NUM_PINS - 1:0] falling_edge;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			gpio_in_prev <= 1'sb0;
		else
			gpio_in_prev <= gpio_in_sync2;
	assign rising_edge = gpio_in_sync2 & ~gpio_in_prev;
	assign falling_edge = ~gpio_in_sync2 & gpio_in_prev;
	assign s_axi_awready = 1'b1;
	assign s_axi_wready = 1'b1;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			data_out_reg <= 1'sb0;
			dir_reg <= 1'sb0;
			int_en_reg <= 1'sb0;
			int_mask_reg <= 1'sb0;
		end
		else if (s_axi_awvalid && s_axi_wvalid)
			case (s_axi_awaddr[7:0])
				REG_DATA_OUT: data_out_reg <= s_axi_wdata[NUM_PINS - 1:0];
				REG_DIR: dir_reg <= s_axi_wdata[NUM_PINS - 1:0];
				REG_INT_EN: int_en_reg <= s_axi_wdata[NUM_PINS - 1:0];
				REG_INT_MASK: int_mask_reg <= s_axi_wdata[NUM_PINS - 1:0];
				default:
					;
			endcase
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
			case (s_axi_araddr[7:0])
				REG_DATA_OUT: s_axi_rdata <= {{32 - NUM_PINS {1'b0}}, data_out_reg};
				REG_DATA_IN: s_axi_rdata <= {{32 - NUM_PINS {1'b0}}, data_in_reg};
				REG_DIR: s_axi_rdata <= {{32 - NUM_PINS {1'b0}}, dir_reg};
				REG_INT_EN: s_axi_rdata <= {{32 - NUM_PINS {1'b0}}, int_en_reg};
				REG_INT_MASK: s_axi_rdata <= {{32 - NUM_PINS {1'b0}}, int_mask_reg};
				REG_INT_STAT: s_axi_rdata <= {{32 - NUM_PINS {1'b0}}, int_stat_reg};
				default: s_axi_rdata <= 32'hdeadbeef;
			endcase
			s_axi_rvalid <= 1'b1;
		end
		else if (s_axi_rready)
			s_axi_rvalid <= 1'b0;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			int_stat_reg <= 1'sb0;
		else begin
			int_stat_reg <= int_stat_reg | ((rising_edge | falling_edge) & int_en_reg);
			if ((s_axi_awvalid && s_axi_wvalid) && (s_axi_awaddr[7:0] == REG_INT_STAT))
				int_stat_reg <= int_stat_reg & ~s_axi_wdata[NUM_PINS - 1:0];
		end
	assign irq = |(int_stat_reg & ~int_mask_reg);
endmodule
module timer (
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
	pwm_out,
	irq
);
	parameter CLK_FREQ = 200000000;
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
	output reg pwm_out;
	output wire irq;
	localparam REG_CONTROL = 8'h00;
	localparam REG_STATUS = 8'h04;
	localparam REG_COUNT = 8'h08;
	localparam REG_COMPARE = 8'h0c;
	localparam REG_RELOAD = 8'h10;
	localparam REG_PRESCALE = 8'h14;
	localparam REG_INT_EN = 8'h18;
	reg [31:0] control_reg;
	wire [31:0] status_reg;
	reg [31:0] count_reg;
	reg [31:0] compare_reg;
	reg [31:0] reload_reg;
	reg [31:0] prescale_reg;
	reg [31:0] int_en_reg;
	wire timer_enable = control_reg[0];
	wire count_down = control_reg[1];
	wire pwm_enable = control_reg[2];
	wire auto_reload = control_reg[3];
	reg overflow_flag;
	reg compare_match_flag;
	assign status_reg = {30'h00000000, compare_match_flag, overflow_flag};
	reg [31:0] prescale_counter;
	reg prescale_tick;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			prescale_counter <= 1'sb0;
			prescale_tick <= 1'b0;
		end
		else if (prescale_counter >= prescale_reg) begin
			prescale_counter <= 1'sb0;
			prescale_tick <= 1'b1;
		end
		else begin
			prescale_counter <= prescale_counter + 1;
			prescale_tick <= 1'b0;
		end
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			count_reg <= 1'sb0;
			overflow_flag <= 1'b0;
			compare_match_flag <= 1'b0;
		end
		else begin
			if ((s_axi_awvalid && s_axi_wvalid) && (s_axi_awaddr[7:0] == REG_COUNT))
				count_reg <= s_axi_wdata;
			else if (timer_enable && prescale_tick) begin
				if (count_down) begin
					if (count_reg == 0) begin
						overflow_flag <= 1'b1;
						count_reg <= (auto_reload ? reload_reg : 32'hffffffff);
					end
					else
						count_reg <= count_reg - 1;
				end
				else if (count_reg == 32'hffffffff) begin
					overflow_flag <= 1'b1;
					count_reg <= (auto_reload ? reload_reg : 32'h00000000);
				end
				else
					count_reg <= count_reg + 1;
				if (count_reg == compare_reg)
					compare_match_flag <= 1'b1;
			end
			if ((s_axi_awvalid && s_axi_wvalid) && (s_axi_awaddr[7:0] == REG_STATUS)) begin
				if (s_axi_wdata[0])
					overflow_flag <= 1'b0;
				if (s_axi_wdata[1])
					compare_match_flag <= 1'b0;
			end
		end
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			pwm_out <= 1'b0;
		else if (pwm_enable) begin
			if (count_reg < compare_reg)
				pwm_out <= 1'b1;
			else
				pwm_out <= 1'b0;
		end
		else
			pwm_out <= 1'b0;
	assign s_axi_awready = 1'b1;
	assign s_axi_wready = 1'b1;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			control_reg <= 1'sb0;
			compare_reg <= 1'sb0;
			reload_reg <= 1'sb0;
			prescale_reg <= 32'd199;
			int_en_reg <= 1'sb0;
		end
		else if (s_axi_awvalid && s_axi_wvalid)
			case (s_axi_awaddr[7:0])
				REG_CONTROL: control_reg <= s_axi_wdata;
				REG_COMPARE: compare_reg <= s_axi_wdata;
				REG_RELOAD: reload_reg <= s_axi_wdata;
				REG_PRESCALE: prescale_reg <= s_axi_wdata;
				REG_INT_EN: int_en_reg <= s_axi_wdata;
				default:
					;
			endcase
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
			case (s_axi_araddr[7:0])
				REG_CONTROL: s_axi_rdata <= control_reg;
				REG_STATUS: s_axi_rdata <= status_reg;
				REG_COUNT: s_axi_rdata <= count_reg;
				REG_COMPARE: s_axi_rdata <= compare_reg;
				REG_RELOAD: s_axi_rdata <= reload_reg;
				REG_PRESCALE: s_axi_rdata <= prescale_reg;
				REG_INT_EN: s_axi_rdata <= int_en_reg;
				default: s_axi_rdata <= 32'hdeadbeef;
			endcase
			s_axi_rvalid <= 1'b1;
		end
		else if (s_axi_rready)
			s_axi_rvalid <= 1'b0;
	assign irq = (overflow_flag & int_en_reg[0]) | (compare_match_flag & int_en_reg[1]);
endmodule
module interrupt_controller (
	clk,
	rst_n,
	irq_sources,
	clear,
	irq_out
);
	parameter NUM_IRQ = 16;
	input wire clk;
	input wire rst_n;
	input wire [NUM_IRQ - 1:0] irq_sources;
	input wire clear;
	output wire irq_out;
	reg [NUM_IRQ - 1:0] irq_pending;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			irq_pending <= 1'sb0;
		else begin
			irq_pending <= irq_pending | irq_sources;
			if (clear)
				irq_pending <= 1'sb0;
		end
	assign irq_out = |irq_pending;
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
	assign porta_word_addr = porta_addr[15:4];
	assign portb_word_addr = portb_addr[15:4];
	always @(posedge clk) begin
		if (porta_wr_en)
			mem[porta_word_addr] <= porta_wr_data;
		porta_rd_data <= mem[porta_word_addr];
	end
	always @(posedge clk)
		if (portb_rd_en)
			portb_rd_data <= mem[portb_word_addr];
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
	assign core_sel_rd = s_axi_araddr[6:5];
	assign reg_offset_rd = s_axi_araddr[4:0];
	assign s_axi_arready = 1'b1;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			s_axi_rdata <= 1'sb0;
			s_axi_rvalid <= 1'b0;
		end
		else if (s_axi_arvalid) begin
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
module cpu_cluster_top (
	clk,
	rst_n,
	irq,
	timer_irq,
	m_axi_awid,
	m_axi_awaddr,
	m_axi_awlen,
	m_axi_awsize,
	m_axi_awburst,
	m_axi_awvalid,
	m_axi_awready,
	m_axi_wdata,
	m_axi_wstrb,
	m_axi_wlast,
	m_axi_wvalid,
	m_axi_wready,
	m_axi_bid,
	m_axi_bresp,
	m_axi_bvalid,
	m_axi_bready,
	m_axi_arid,
	m_axi_araddr,
	m_axi_arlen,
	m_axi_arsize,
	m_axi_arburst,
	m_axi_arvalid,
	m_axi_arready,
	m_axi_rid,
	m_axi_rdata,
	m_axi_rresp,
	m_axi_rlast,
	m_axi_rvalid,
	m_axi_rready
);
	parameter NUM_CORES = 4;
	parameter ADDR_WIDTH = 32;
	parameter DATA_WIDTH = 128;
	parameter ID_WIDTH = 4;
	parameter [31:0] BOOT_ADDR = 32'h00000000;
	input wire clk;
	input wire rst_n;
	input wire [NUM_CORES - 1:0] irq;
	input wire [NUM_CORES - 1:0] timer_irq;
	output wire [(NUM_CORES * ID_WIDTH) - 1:0] m_axi_awid;
	output wire [(NUM_CORES * ADDR_WIDTH) - 1:0] m_axi_awaddr;
	output wire [(NUM_CORES * 8) - 1:0] m_axi_awlen;
	output wire [(NUM_CORES * 3) - 1:0] m_axi_awsize;
	output wire [(NUM_CORES * 2) - 1:0] m_axi_awburst;
	output wire [NUM_CORES - 1:0] m_axi_awvalid;
	input wire [NUM_CORES - 1:0] m_axi_awready;
	output wire [(NUM_CORES * DATA_WIDTH) - 1:0] m_axi_wdata;
	output wire [(NUM_CORES * 16) - 1:0] m_axi_wstrb;
	output wire [NUM_CORES - 1:0] m_axi_wlast;
	output wire [NUM_CORES - 1:0] m_axi_wvalid;
	input wire [NUM_CORES - 1:0] m_axi_wready;
	input wire [(NUM_CORES * ID_WIDTH) - 1:0] m_axi_bid;
	input wire [(NUM_CORES * 2) - 1:0] m_axi_bresp;
	input wire [NUM_CORES - 1:0] m_axi_bvalid;
	output wire [NUM_CORES - 1:0] m_axi_bready;
	output wire [(NUM_CORES * ID_WIDTH) - 1:0] m_axi_arid;
	output wire [(NUM_CORES * ADDR_WIDTH) - 1:0] m_axi_araddr;
	output wire [(NUM_CORES * 8) - 1:0] m_axi_arlen;
	output wire [(NUM_CORES * 3) - 1:0] m_axi_arsize;
	output wire [(NUM_CORES * 2) - 1:0] m_axi_arburst;
	output wire [NUM_CORES - 1:0] m_axi_arvalid;
	input wire [NUM_CORES - 1:0] m_axi_arready;
	input wire [(NUM_CORES * ID_WIDTH) - 1:0] m_axi_rid;
	input wire [(NUM_CORES * DATA_WIDTH) - 1:0] m_axi_rdata;
	input wire [(NUM_CORES * 2) - 1:0] m_axi_rresp;
	input wire [NUM_CORES - 1:0] m_axi_rlast;
	input wire [NUM_CORES - 1:0] m_axi_rvalid;
	output wire [NUM_CORES - 1:0] m_axi_rready;
	assign m_axi_awid = {NUM_CORES * ID_WIDTH {1'b0}};
	assign m_axi_awaddr = {NUM_CORES * ADDR_WIDTH {1'b0}};
	assign m_axi_awlen = {NUM_CORES * 8 {1'b0}};
	assign m_axi_awsize = {NUM_CORES * 3 {1'b0}};
	assign m_axi_awburst = {NUM_CORES * 2 {1'b0}};
	assign m_axi_awvalid = {NUM_CORES {1'b0}};
	assign m_axi_wdata = {NUM_CORES * DATA_WIDTH {1'b0}};
	assign m_axi_wstrb = {NUM_CORES * 16 {1'b0}};
	assign m_axi_wlast = {NUM_CORES {1'b0}};
	assign m_axi_wvalid = {NUM_CORES {1'b0}};
	assign m_axi_bready = {NUM_CORES {1'b0}};
	assign m_axi_arid = {NUM_CORES * ID_WIDTH {1'b0}};
	assign m_axi_araddr = {NUM_CORES * ADDR_WIDTH {1'b0}};
	assign m_axi_arlen = {NUM_CORES * 8 {1'b0}};
	assign m_axi_arsize = {NUM_CORES * 3 {1'b0}};
	assign m_axi_arburst = {NUM_CORES * 2 {1'b0}};
	assign m_axi_arvalid = {NUM_CORES {1'b0}};
	assign m_axi_rready = {NUM_CORES {1'b0}};
endmodule
module aurora_soc_top (
	clk,
	rst_n,
	uart_rxd,
	uart_txd,
	gpio_in,
	gpio_out,
	gpio_oe,
	timer_pwm,
	global_irq
);
	parameter DATA_WIDTH = 128;
	parameter ADDR_WIDTH = 32;
	parameter ID_WIDTH = 4;
	parameter NUM_CPU = 4;
	parameter NUM_DMA = 4;
	input wire clk;
	input wire rst_n;
	input wire uart_rxd;
	output wire uart_txd;
	input wire [31:0] gpio_in;
	output wire [31:0] gpio_out;
	output wire [31:0] gpio_oe;
	output wire timer_pwm;
	output wire global_irq;
	wire cpu_clk;
	wire cpu_rst_n;
	wire fabric_clk;
	wire fabric_rst_n;
	clock_reset_controller clk_rst(
		.clk_in(clk),
		.rst_in_n(rst_n),
		.cpu_clk(cpu_clk),
		.cpu_rst_n(cpu_rst_n),
		.fabric_clk(fabric_clk),
		.fabric_rst_n(fabric_rst_n)
	);
	wire uart_irq;
	wire gpio_irq;
	wire timer_irq_periph;
	wire [3:0] tensor_irq;
	wire global_irq_int;
	localparam NM = 8;
	localparam NS = 8;
	wire [(8 * ADDR_WIDTH) - 1:0] xm_awaddr;
	wire [(8 * ADDR_WIDTH) - 1:0] xm_araddr;
	wire [7:0] xm_awvalid;
	wire [7:0] xm_awready;
	wire [(8 * DATA_WIDTH) - 1:0] xm_wdata;
	wire [(8 * DATA_WIDTH) - 1:0] xm_rdata;
	wire [(8 * (DATA_WIDTH / 8)) - 1:0] xm_wstrb;
	wire [7:0] xm_wvalid;
	wire [7:0] xm_wready;
	wire [7:0] xm_bvalid;
	wire [7:0] xm_bready;
	wire [7:0] xm_arvalid;
	wire [7:0] xm_arready;
	wire [7:0] xm_rvalid;
	wire [7:0] xm_rready;
	wire [(8 * ADDR_WIDTH) - 1:0] xs_awaddr;
	wire [(8 * ADDR_WIDTH) - 1:0] xs_araddr;
	wire [7:0] xs_awvalid;
	wire [7:0] xs_awready;
	wire [(8 * DATA_WIDTH) - 1:0] xs_wdata;
	wire [(8 * DATA_WIDTH) - 1:0] xs_rdata;
	wire [(8 * (DATA_WIDTH / 8)) - 1:0] xs_wstrb;
	wire [7:0] xs_wvalid;
	wire [7:0] xs_wready;
	wire [7:0] xs_bvalid;
	wire [7:0] xs_bready;
	wire [7:0] xs_arvalid;
	wire [7:0] xs_arready;
	wire [7:0] xs_rvalid;
	wire [7:0] xs_rready;
	function automatic [31:0] lane32;
		input reg [DATA_WIDTH - 1:0] beat;
		input reg [3:2] sel;
		lane32 = beat[32 * sel+:32];
	endfunction
	wire [(NUM_CPU * ID_WIDTH) - 1:0] cpu_axi_awid;
	wire [(NUM_CPU * ADDR_WIDTH) - 1:0] cpu_axi_awaddr;
	wire [(NUM_CPU * 8) - 1:0] cpu_axi_awlen;
	wire [(NUM_CPU * 3) - 1:0] cpu_axi_awsize;
	wire [(NUM_CPU * 2) - 1:0] cpu_axi_awburst;
	wire [NUM_CPU - 1:0] cpu_axi_awvalid;
	wire [NUM_CPU - 1:0] cpu_axi_awready;
	wire [(NUM_CPU * DATA_WIDTH) - 1:0] cpu_axi_wdata;
	wire [(NUM_CPU * 16) - 1:0] cpu_axi_wstrb;
	wire [NUM_CPU - 1:0] cpu_axi_wlast;
	wire [NUM_CPU - 1:0] cpu_axi_wvalid;
	wire [NUM_CPU - 1:0] cpu_axi_wready;
	wire [(NUM_CPU * ID_WIDTH) - 1:0] cpu_axi_bid;
	wire [(NUM_CPU * 2) - 1:0] cpu_axi_bresp;
	wire [NUM_CPU - 1:0] cpu_axi_bvalid;
	wire [NUM_CPU - 1:0] cpu_axi_bready;
	wire [(NUM_CPU * ID_WIDTH) - 1:0] cpu_axi_arid;
	wire [(NUM_CPU * ADDR_WIDTH) - 1:0] cpu_axi_araddr;
	wire [(NUM_CPU * 8) - 1:0] cpu_axi_arlen;
	wire [(NUM_CPU * 3) - 1:0] cpu_axi_arsize;
	wire [(NUM_CPU * 2) - 1:0] cpu_axi_arburst;
	wire [NUM_CPU - 1:0] cpu_axi_arvalid;
	wire [NUM_CPU - 1:0] cpu_axi_arready;
	wire [(NUM_CPU * ID_WIDTH) - 1:0] cpu_axi_rid;
	wire [(NUM_CPU * DATA_WIDTH) - 1:0] cpu_axi_rdata;
	wire [(NUM_CPU * 2) - 1:0] cpu_axi_rresp;
	wire [NUM_CPU - 1:0] cpu_axi_rlast;
	wire [NUM_CPU - 1:0] cpu_axi_rvalid;
	wire [NUM_CPU - 1:0] cpu_axi_rready;
	wire [NUM_CPU - 1:0] cpu_trap;
	wire [(NUM_CPU * 32) - 1:0] cpu_pc;
	cpu_cluster_top #(
		.NUM_CORES(NUM_CPU),
		.ADDR_WIDTH(ADDR_WIDTH),
		.DATA_WIDTH(DATA_WIDTH),
		.ID_WIDTH(ID_WIDTH),
		.BOOT_ADDR(32'h00000000)
	) cpu_cluster(
		.clk(cpu_clk),
		.rst_n(cpu_rst_n),
		.irq({NUM_CPU {global_irq_int}}),
		.timer_irq({NUM_CPU {timer_irq_periph}}),
		.m_axi_awid(cpu_axi_awid),
		.m_axi_awaddr(cpu_axi_awaddr),
		.m_axi_awlen(cpu_axi_awlen),
		.m_axi_awsize(cpu_axi_awsize),
		.m_axi_awburst(cpu_axi_awburst),
		.m_axi_awvalid(cpu_axi_awvalid),
		.m_axi_awready(cpu_axi_awready),
		.m_axi_wdata(cpu_axi_wdata),
		.m_axi_wstrb(cpu_axi_wstrb),
		.m_axi_wlast(cpu_axi_wlast),
		.m_axi_wvalid(cpu_axi_wvalid),
		.m_axi_wready(cpu_axi_wready),
		.m_axi_bid(cpu_axi_bid),
		.m_axi_bresp(cpu_axi_bresp),
		.m_axi_bvalid(cpu_axi_bvalid),
		.m_axi_bready(cpu_axi_bready),
		.m_axi_arid(cpu_axi_arid),
		.m_axi_araddr(cpu_axi_araddr),
		.m_axi_arlen(cpu_axi_arlen),
		.m_axi_arsize(cpu_axi_arsize),
		.m_axi_arburst(cpu_axi_arburst),
		.m_axi_arvalid(cpu_axi_arvalid),
		.m_axi_arready(cpu_axi_arready),
		.m_axi_rid(cpu_axi_rid),
		.m_axi_rdata(cpu_axi_rdata),
		.m_axi_rresp(cpu_axi_rresp),
		.m_axi_rlast(cpu_axi_rlast),
		.m_axi_rvalid(cpu_axi_rvalid),
		.m_axi_rready(cpu_axi_rready)
	);
	genvar _gv_ci_1;
	generate
		for (_gv_ci_1 = 0; _gv_ci_1 < NUM_CPU; _gv_ci_1 = _gv_ci_1 + 1) begin : CPU_XBAR_WIRE
			localparam ci = _gv_ci_1;
			assign xm_awaddr[ci * ADDR_WIDTH+:ADDR_WIDTH] = cpu_axi_awaddr[ci * ADDR_WIDTH+:ADDR_WIDTH];
			assign xm_awvalid[ci] = cpu_axi_awvalid[ci];
			assign cpu_axi_awready[ci] = xm_awready[ci];
			assign xm_wdata[ci * DATA_WIDTH+:DATA_WIDTH] = cpu_axi_wdata[ci * DATA_WIDTH+:DATA_WIDTH];
			assign xm_wstrb[ci * (DATA_WIDTH / 8)+:DATA_WIDTH / 8] = cpu_axi_wstrb[ci * 16+:16];
			assign xm_wvalid[ci] = cpu_axi_wvalid[ci];
			assign cpu_axi_wready[ci] = xm_wready[ci];
			assign cpu_axi_bvalid[ci] = xm_bvalid[ci];
			assign xm_bready[ci] = cpu_axi_bready[ci];
			assign xm_araddr[ci * ADDR_WIDTH+:ADDR_WIDTH] = cpu_axi_araddr[ci * ADDR_WIDTH+:ADDR_WIDTH];
			assign xm_arvalid[ci] = cpu_axi_arvalid[ci];
			assign cpu_axi_arready[ci] = xm_arready[ci];
			assign cpu_axi_rdata[ci * DATA_WIDTH+:DATA_WIDTH] = xm_rdata[ci * DATA_WIDTH+:DATA_WIDTH];
			assign cpu_axi_rvalid[ci] = xm_rvalid[ci];
			assign xm_rready[ci] = cpu_axi_rready[ci];
			assign cpu_axi_bid[ci * ID_WIDTH+:ID_WIDTH] = 1'sb0;
			assign cpu_axi_bresp[ci * 2+:2] = 1'sb0;
			assign cpu_axi_rid[ci * ID_WIDTH+:ID_WIDTH] = 1'sb0;
			assign cpu_axi_rresp[ci * 2+:2] = 1'sb0;
			assign cpu_axi_rlast[ci] = 1'b1;
		end
	endgenerate
	wire [NUM_DMA - 1:0] dma_irq;
	wire [(NUM_DMA * ADDR_WIDTH) - 1:0] dma_araddr;
	wire [(NUM_DMA * ADDR_WIDTH) - 1:0] dma_awaddr;
	wire [NUM_DMA - 1:0] dma_arvalid;
	wire [NUM_DMA - 1:0] dma_awvalid;
	wire [NUM_DMA - 1:0] dma_arready;
	wire [NUM_DMA - 1:0] dma_awready;
	wire [(NUM_DMA * DATA_WIDTH) - 1:0] dma_wdata;
	wire [(NUM_DMA * DATA_WIDTH) - 1:0] dma_rdata;
	wire [NUM_DMA - 1:0] dma_wvalid;
	wire [NUM_DMA - 1:0] dma_wready;
	wire [NUM_DMA - 1:0] dma_bvalid;
	wire [NUM_DMA - 1:0] dma_bready;
	wire [NUM_DMA - 1:0] dma_rvalid;
	wire [NUM_DMA - 1:0] dma_rready;
	genvar _gv_di_1;
	wire [NUM_DMA - 1:0] dma_s_arready;
	wire [NUM_DMA - 1:0] dma_s_arvalid;
	wire [NUM_DMA - 1:0] dma_s_awready;
	wire [NUM_DMA - 1:0] dma_s_awvalid;
	wire [NUM_DMA - 1:0] dma_s_bready;
	wire [NUM_DMA - 1:0] dma_s_bvalid;
	wire [(NUM_DMA * 32) - 1:0] dma_s_rdata;
	wire [NUM_DMA - 1:0] dma_s_rready;
	wire [NUM_DMA - 1:0] dma_s_rvalid;
	wire [NUM_DMA - 1:0] dma_s_wready;
	wire [NUM_DMA - 1:0] dma_s_wvalid;
	generate
		for (_gv_di_1 = 0; _gv_di_1 < NUM_DMA; _gv_di_1 = _gv_di_1 + 1) begin : DMA_GEN
			localparam di = _gv_di_1;
			dma_engine_complete #(
				.ADDR_WIDTH(ADDR_WIDTH),
				.DATA_WIDTH(DATA_WIDTH),
				.CHANNEL_ID(di)
			) dma(
				.clk(fabric_clk),
				.rst_n(fabric_rst_n),
				.s_axil_awaddr(xs_awaddr[6 * ADDR_WIDTH+:ADDR_WIDTH]),
				.s_axil_awvalid(dma_s_awvalid[di]),
				.s_axil_awready(dma_s_awready[di]),
				.s_axil_wdata(lane32(xs_wdata[6 * DATA_WIDTH+:DATA_WIDTH], xs_awaddr[(6 * ADDR_WIDTH) + 3-:2])),
				.s_axil_wvalid(dma_s_wvalid[di]),
				.s_axil_wready(dma_s_wready[di]),
				.s_axil_bvalid(dma_s_bvalid[di]),
				.s_axil_bready(dma_s_bready[di]),
				.s_axil_araddr(xs_araddr[6 * ADDR_WIDTH+:ADDR_WIDTH]),
				.s_axil_arvalid(dma_s_arvalid[di]),
				.s_axil_arready(dma_s_arready[di]),
				.s_axil_rdata(dma_s_rdata[di * 32+:32]),
				.s_axil_rvalid(dma_s_rvalid[di]),
				.s_axil_rready(dma_s_rready[di]),
				.m_axi_araddr(dma_araddr[di * ADDR_WIDTH+:ADDR_WIDTH]),
				.m_axi_arlen(),
				.m_axi_arsize(),
				.m_axi_arvalid(dma_arvalid[di]),
				.m_axi_arready(dma_arready[di]),
				.m_axi_rdata(dma_rdata[di * DATA_WIDTH+:DATA_WIDTH]),
				.m_axi_rlast(1'b1),
				.m_axi_rvalid(dma_rvalid[di]),
				.m_axi_rready(dma_rready[di]),
				.m_axi_awaddr(dma_awaddr[di * ADDR_WIDTH+:ADDR_WIDTH]),
				.m_axi_awlen(),
				.m_axi_awsize(),
				.m_axi_awvalid(dma_awvalid[di]),
				.m_axi_awready(dma_awready[di]),
				.m_axi_wdata(dma_wdata[di * DATA_WIDTH+:DATA_WIDTH]),
				.m_axi_wlast(),
				.m_axi_wvalid(dma_wvalid[di]),
				.m_axi_wready(dma_wready[di]),
				.m_axi_bvalid(dma_bvalid[di]),
				.m_axi_bready(dma_bready[di]),
				.irq(dma_irq[di])
			);
			assign xm_araddr[(NUM_CPU + di) * ADDR_WIDTH+:ADDR_WIDTH] = dma_araddr[di * ADDR_WIDTH+:ADDR_WIDTH];
			assign xm_arvalid[NUM_CPU + di] = dma_arvalid[di];
			assign dma_arready[di] = xm_arready[NUM_CPU + di];
			assign dma_rdata[di * DATA_WIDTH+:DATA_WIDTH] = xm_rdata[(NUM_CPU + di) * DATA_WIDTH+:DATA_WIDTH];
			assign dma_rvalid[di] = xm_rvalid[NUM_CPU + di];
			assign xm_rready[NUM_CPU + di] = dma_rready[di];
			assign xm_awaddr[(NUM_CPU + di) * ADDR_WIDTH+:ADDR_WIDTH] = dma_awaddr[di * ADDR_WIDTH+:ADDR_WIDTH];
			assign xm_awvalid[NUM_CPU + di] = dma_awvalid[di];
			assign dma_awready[di] = xm_awready[NUM_CPU + di];
			assign xm_wdata[(NUM_CPU + di) * DATA_WIDTH+:DATA_WIDTH] = dma_wdata[di * DATA_WIDTH+:DATA_WIDTH];
			assign xm_wstrb[(NUM_CPU + di) * (DATA_WIDTH / 8)+:DATA_WIDTH / 8] = 1'sb1;
			assign xm_wvalid[NUM_CPU + di] = dma_wvalid[di];
			assign dma_wready[di] = xm_wready[NUM_CPU + di];
			assign dma_bvalid[di] = xm_bvalid[NUM_CPU + di];
			assign xm_bready[NUM_CPU + di] = dma_bready[di];
		end
	endgenerate
	axi_crossbar #(
		.DATA_WIDTH(DATA_WIDTH),
		.ADDR_WIDTH(ADDR_WIDTH),
		.ID_WIDTH(ID_WIDTH),
		.NUM_MASTERS(NM),
		.NUM_SLAVES(NS)
	) crossbar(
		.clk(fabric_clk),
		.rst_n(fabric_rst_n),
		.m_awaddr(xm_awaddr),
		.m_awvalid(xm_awvalid),
		.m_awready(xm_awready),
		.m_wdata(xm_wdata),
		.m_wstrb(xm_wstrb),
		.m_wvalid(xm_wvalid),
		.m_wready(xm_wready),
		.m_bvalid(xm_bvalid),
		.m_bready(xm_bready),
		.m_araddr(xm_araddr),
		.m_arvalid(xm_arvalid),
		.m_arready(xm_arready),
		.m_rdata(xm_rdata),
		.m_rvalid(xm_rvalid),
		.m_rready(xm_rready),
		.s_awaddr(xs_awaddr),
		.s_awvalid(xs_awvalid),
		.s_awready(xs_awready),
		.s_wdata(xs_wdata),
		.s_wstrb(xs_wstrb),
		.s_wvalid(xs_wvalid),
		.s_wready(xs_wready),
		.s_bvalid(xs_bvalid),
		.s_bready(xs_bready),
		.s_araddr(xs_araddr),
		.s_arvalid(xs_arvalid),
		.s_arready(xs_arready),
		.s_rdata(xs_rdata),
		.s_rvalid(xs_rvalid),
		.s_rready(xs_rready)
	);
	boot_rom #(
		.ADDR_WIDTH(ADDR_WIDTH),
		.DATA_WIDTH(DATA_WIDTH),
		.ROM_SIZE(1024)
	) boot_rom_inst(
		.clk(fabric_clk),
		.rst_n(fabric_rst_n),
		.s_axi_araddr(xs_araddr[0+:ADDR_WIDTH]),
		.s_axi_arvalid(xs_arvalid[0]),
		.s_axi_arready(xs_arready[0]),
		.s_axi_rdata(xs_rdata[0+:DATA_WIDTH]),
		.s_axi_rvalid(xs_rvalid[0]),
		.s_axi_rready(xs_rready[0]),
		.s_axi_awaddr(xs_awaddr[0+:ADDR_WIDTH]),
		.s_axi_awvalid(xs_awvalid[0]),
		.s_axi_awready(xs_awready[0]),
		.s_axi_wdata(xs_wdata[0+:DATA_WIDTH]),
		.s_axi_wvalid(xs_wvalid[0]),
		.s_axi_wready(xs_wready[0]),
		.s_axi_bvalid(xs_bvalid[0]),
		.s_axi_bready(xs_bready[0])
	);
	sram_bank_array #(
		.DATA_WIDTH(DATA_WIDTH),
		.ADDR_WIDTH(ADDR_WIDTH),
		.NUM_BANKS(2),
		.BANK_DEPTH(256)
	) sram(
		.clk(fabric_clk),
		.rst_n(fabric_rst_n),
		.awaddr(xs_awaddr[ADDR_WIDTH+:ADDR_WIDTH]),
		.awvalid(xs_awvalid[1]),
		.awready(xs_awready[1]),
		.wdata(xs_wdata[DATA_WIDTH+:DATA_WIDTH]),
		.wstrb(xs_wstrb[DATA_WIDTH / 8+:DATA_WIDTH / 8]),
		.wvalid(xs_wvalid[1]),
		.wready(xs_wready[1]),
		.bvalid(xs_bvalid[1]),
		.bready(xs_bready[1]),
		.araddr(xs_araddr[ADDR_WIDTH+:ADDR_WIDTH]),
		.arvalid(xs_arvalid[1]),
		.arready(xs_arready[1]),
		.rdata(xs_rdata[DATA_WIDTH+:DATA_WIDTH]),
		.rvalid(xs_rvalid[1]),
		.rready(xs_rready[1])
	);
	wire [31:0] uart_rdata32;
	uart #(
		.CLK_FREQ(200000000),
		.BAUD_RATE(115200)
	) uart_inst(
		.clk(fabric_clk),
		.rst_n(fabric_rst_n),
		.s_axi_awaddr(xs_awaddr[2 * ADDR_WIDTH+:ADDR_WIDTH]),
		.s_axi_awvalid(xs_awvalid[2]),
		.s_axi_awready(xs_awready[2]),
		.s_axi_wdata(lane32(xs_wdata[2 * DATA_WIDTH+:DATA_WIDTH], xs_awaddr[(2 * ADDR_WIDTH) + 3-:2])),
		.s_axi_wvalid(xs_wvalid[2]),
		.s_axi_wready(xs_wready[2]),
		.s_axi_bvalid(xs_bvalid[2]),
		.s_axi_bready(xs_bready[2]),
		.s_axi_araddr(xs_araddr[2 * ADDR_WIDTH+:ADDR_WIDTH]),
		.s_axi_arvalid(xs_arvalid[2]),
		.s_axi_arready(xs_arready[2]),
		.s_axi_rdata(uart_rdata32),
		.s_axi_rvalid(xs_rvalid[2]),
		.s_axi_rready(xs_rready[2]),
		.uart_rxd(uart_rxd),
		.uart_txd(uart_txd),
		.irq(uart_irq)
	);
	assign xs_rdata[2 * DATA_WIDTH+:DATA_WIDTH] = {4 {uart_rdata32}};
	wire [31:0] gpio_rdata32;
	gpio #(.NUM_PINS(32)) gpio_inst(
		.clk(fabric_clk),
		.rst_n(fabric_rst_n),
		.s_axi_awaddr(xs_awaddr[3 * ADDR_WIDTH+:ADDR_WIDTH]),
		.s_axi_awvalid(xs_awvalid[3]),
		.s_axi_awready(xs_awready[3]),
		.s_axi_wdata(lane32(xs_wdata[3 * DATA_WIDTH+:DATA_WIDTH], xs_awaddr[(3 * ADDR_WIDTH) + 3-:2])),
		.s_axi_wvalid(xs_wvalid[3]),
		.s_axi_wready(xs_wready[3]),
		.s_axi_bvalid(xs_bvalid[3]),
		.s_axi_bready(xs_bready[3]),
		.s_axi_araddr(xs_araddr[3 * ADDR_WIDTH+:ADDR_WIDTH]),
		.s_axi_arvalid(xs_arvalid[3]),
		.s_axi_arready(xs_arready[3]),
		.s_axi_rdata(gpio_rdata32),
		.s_axi_rvalid(xs_rvalid[3]),
		.s_axi_rready(xs_rready[3]),
		.gpio_in(gpio_in),
		.gpio_out(gpio_out),
		.gpio_oe(gpio_oe),
		.irq(gpio_irq)
	);
	assign xs_rdata[3 * DATA_WIDTH+:DATA_WIDTH] = {4 {gpio_rdata32}};
	wire [31:0] timer_rdata32;
	timer #(.CLK_FREQ(200000000)) timer_inst(
		.clk(fabric_clk),
		.rst_n(fabric_rst_n),
		.s_axi_awaddr(xs_awaddr[4 * ADDR_WIDTH+:ADDR_WIDTH]),
		.s_axi_awvalid(xs_awvalid[4]),
		.s_axi_awready(xs_awready[4]),
		.s_axi_wdata(lane32(xs_wdata[4 * DATA_WIDTH+:DATA_WIDTH], xs_awaddr[(4 * ADDR_WIDTH) + 3-:2])),
		.s_axi_wvalid(xs_wvalid[4]),
		.s_axi_wready(xs_wready[4]),
		.s_axi_bvalid(xs_bvalid[4]),
		.s_axi_bready(xs_bready[4]),
		.s_axi_araddr(xs_araddr[4 * ADDR_WIDTH+:ADDR_WIDTH]),
		.s_axi_arvalid(xs_arvalid[4]),
		.s_axi_arready(xs_arready[4]),
		.s_axi_rdata(timer_rdata32),
		.s_axi_rvalid(xs_rvalid[4]),
		.s_axi_rready(xs_rready[4]),
		.pwm_out(timer_pwm),
		.irq(timer_irq_periph)
	);
	assign xs_rdata[4 * DATA_WIDTH+:DATA_WIDTH] = {4 {timer_rdata32}};
	wire [31:0] tensor_rdata32;
	tensor_cluster_top #(
		.NUM_CORES(4),
		.DATA_WIDTH(16),
		.SIZE(16)
	) tensor_cluster(
		.clk(fabric_clk),
		.rst_n(fabric_rst_n),
		.s_axi_awaddr(xs_awaddr[(5 * ADDR_WIDTH) + 31-:32]),
		.s_axi_awvalid(xs_awvalid[5]),
		.s_axi_awready(xs_awready[5]),
		.s_axi_wdata(lane32(xs_wdata[5 * DATA_WIDTH+:DATA_WIDTH], xs_awaddr[(5 * ADDR_WIDTH) + 3-:2])),
		.s_axi_wvalid(xs_wvalid[5]),
		.s_axi_wready(xs_wready[5]),
		.s_axi_bvalid(xs_bvalid[5]),
		.s_axi_bready(xs_bready[5]),
		.s_axi_araddr(xs_araddr[(5 * ADDR_WIDTH) + 31-:32]),
		.s_axi_arvalid(xs_arvalid[5]),
		.s_axi_arready(xs_arready[5]),
		.s_axi_rdata(tensor_rdata32),
		.s_axi_rvalid(xs_rvalid[5]),
		.s_axi_rready(xs_rready[5]),
		.core_done_irq(tensor_irq)
	);
	assign xs_rdata[5 * DATA_WIDTH+:DATA_WIDTH] = {4 {tensor_rdata32}};
	assign xs_awready[6] = |dma_s_awready;
	assign xs_wready[6] = |dma_s_wready;
	assign xs_bvalid[6] = |dma_s_bvalid;
	assign xs_arready[6] = |dma_s_arready;
	assign xs_rvalid[6] = |dma_s_rvalid;
	assign xs_rdata[6 * DATA_WIDTH+:DATA_WIDTH] = {4 {dma_s_rdata[xs_araddr[(6 * ADDR_WIDTH) + 9-:2] * 32+:32]}};
	genvar _gv_di2_1;
	generate
		for (_gv_di2_1 = 0; _gv_di2_1 < NUM_DMA; _gv_di2_1 = _gv_di2_1 + 1) begin : DMA_REG_DEMUX
			localparam di2 = _gv_di2_1;
			assign dma_s_awvalid[di2] = xs_awvalid[6] && (xs_awaddr[(6 * ADDR_WIDTH) + 9-:2] == di2[1:0]);
			assign dma_s_wvalid[di2] = xs_wvalid[6] && (xs_awaddr[(6 * ADDR_WIDTH) + 9-:2] == di2[1:0]);
			assign dma_s_bready[di2] = xs_bready[6] && (xs_awaddr[(6 * ADDR_WIDTH) + 9-:2] == di2[1:0]);
			assign dma_s_arvalid[di2] = xs_arvalid[6] && (xs_araddr[(6 * ADDR_WIDTH) + 9-:2] == di2[1:0]);
			assign dma_s_rready[di2] = xs_rready[6] && (xs_araddr[(6 * ADDR_WIDTH) + 9-:2] == di2[1:0]);
		end
	endgenerate
	reg rsvd_bvalid;
	reg rsvd_rvalid;
	always @(posedge fabric_clk or negedge fabric_rst_n)
		if (!fabric_rst_n) begin
			rsvd_bvalid <= 1'b0;
			rsvd_rvalid <= 1'b0;
		end
		else begin
			if (xs_awvalid[7] && xs_wvalid[7])
				rsvd_bvalid <= 1'b1;
			else if (rsvd_bvalid && xs_bready[7])
				rsvd_bvalid <= 1'b0;
			if (xs_arvalid[7])
				rsvd_rvalid <= 1'b1;
			else if (rsvd_rvalid && xs_rready[7])
				rsvd_rvalid <= 1'b0;
		end
	assign xs_awready[7] = 1'b1;
	assign xs_wready[7] = 1'b1;
	assign xs_bvalid[7] = rsvd_bvalid;
	assign xs_arready[7] = 1'b1;
	assign xs_rdata[7 * DATA_WIDTH+:DATA_WIDTH] = 1'sb0;
	assign xs_rvalid[7] = rsvd_rvalid;
	wire [15:0] irq_sources;
	assign irq_sources = {4'h0, dma_irq, tensor_irq, timer_irq_periph, gpio_irq, uart_irq, 1'b0};
	interrupt_controller #(.NUM_IRQ(16)) irq_ctrl(
		.clk(cpu_clk),
		.rst_n(cpu_rst_n),
		.irq_sources(irq_sources),
		.clear(1'b0),
		.irq_out(global_irq_int)
	);
	assign global_irq = global_irq_int;
endmodule
