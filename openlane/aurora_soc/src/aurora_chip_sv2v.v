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
	s_axi_wstrb,
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
	m_axi_wstrb,
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
	input wire [(DATA_WIDTH / 8) - 1:0] s_axi_wstrb;
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
	output wire [(DATA_WIDTH / 8) - 1:0] m_axi_wstrb;
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
	localparam AWW_WIDTH = ((ID_WIDTH + ADDR_WIDTH) + (DATA_WIDTH / 8)) + DATA_WIDTH;
	reg aw_held;
	reg w_held;
	reg [ID_WIDTH - 1:0] awid_h;
	reg [ADDR_WIDTH - 1:0] awaddr_h;
	reg [(DATA_WIDTH / 8) - 1:0] wstrb_h;
	reg [DATA_WIDTH - 1:0] wdata_h;
	wire [AWW_WIDTH - 1:0] wr_wdata;
	wire [AWW_WIDTH - 1:0] wr_rdata;
	wire wr_full;
	wire wr_empty;
	wire wr_wr_en;
	wire wr_rd_en;
	wire aw_take = s_axi_awvalid && s_axi_awready;
	wire w_take = s_axi_wvalid && s_axi_wready;
	wire aw_avail = aw_held || aw_take;
	wire w_avail = w_held || w_take;
	assign s_axi_awready = !aw_held && !wr_full;
	assign s_axi_wready = !w_held && !wr_full;
	assign wr_wr_en = (aw_avail && w_avail) && !wr_full;
	always @(posedge cpu_clk or negedge cpu_rst_n)
		if (!cpu_rst_n) begin
			aw_held <= 1'b0;
			w_held <= 1'b0;
			awid_h <= 1'sb0;
			awaddr_h <= 1'sb0;
			wstrb_h <= 1'sb0;
			wdata_h <= 1'sb0;
		end
		else begin
			if (aw_take) begin
				awid_h <= s_axi_awid;
				awaddr_h <= s_axi_awaddr;
			end
			if (w_take) begin
				wstrb_h <= s_axi_wstrb;
				wdata_h <= s_axi_wdata;
			end
			if (wr_wr_en) begin
				aw_held <= 1'b0;
				w_held <= 1'b0;
			end
			else begin
				if (aw_take)
					aw_held <= 1'b1;
				if (w_take)
					w_held <= 1'b1;
			end
		end
	assign wr_wdata = {(aw_held ? awid_h : s_axi_awid), (aw_held ? awaddr_h : s_axi_awaddr), (w_held ? wstrb_h : s_axi_wstrb), (w_held ? wdata_h : s_axi_wdata)};
	reg m_aw_done;
	reg m_w_done;
	assign {m_axi_awid, m_axi_awaddr, m_axi_wstrb, m_axi_wdata} = wr_rdata;
	assign m_axi_awvalid = !wr_empty && !m_aw_done;
	assign m_axi_wvalid = !wr_empty && !m_w_done;
	wire m_aw_fire = m_axi_awvalid && m_axi_awready;
	wire m_w_fire = m_axi_wvalid && m_axi_wready;
	assign wr_rd_en = (!wr_empty && (m_aw_done || m_aw_fire)) && (m_w_done || m_w_fire);
	always @(posedge fabric_clk or negedge fabric_rst_n)
		if (!fabric_rst_n) begin
			m_aw_done <= 1'b0;
			m_w_done <= 1'b0;
		end
		else if (wr_rd_en) begin
			m_aw_done <= 1'b0;
			m_w_done <= 1'b0;
		end
		else begin
			if (m_aw_fire)
				m_aw_done <= 1'b1;
			if (m_w_fire)
				m_w_done <= 1'b1;
		end
	async_fifo #(
		.DATA_WIDTH(AWW_WIDTH),
		.ADDR_WIDTH(4)
	) wr_fifo(
		.wr_clk(cpu_clk),
		.wr_rst_n(cpu_rst_n),
		.wr_en(wr_wr_en),
		.wr_data(wr_wdata),
		.wr_full(wr_full),
		.rd_clk(fabric_clk),
		.rd_rst_n(fabric_rst_n),
		.rd_en(wr_rd_en),
		.rd_data(wr_rdata),
		.rd_empty(wr_empty)
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
		if ((addr[31:24] == 8'h00) || (addr[31:24] == 8'h80))
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
module rocket_axi_wrapper (
	r_awid,
	r_awaddr,
	r_awvalid,
	r_awready,
	r_wdata,
	r_wstrb,
	r_wvalid,
	r_wready,
	r_bid,
	r_bresp,
	r_bvalid,
	r_bready,
	r_arid,
	r_araddr,
	r_arvalid,
	r_arready,
	r_rid,
	r_rdata,
	r_rresp,
	r_rlast,
	r_rvalid,
	r_rready,
	clk,
	rst_n,
	f_awid,
	f_awaddr,
	f_awvalid,
	f_awready,
	f_wdata,
	f_wstrb,
	f_wvalid,
	f_wready,
	f_bid,
	f_bvalid,
	f_bready,
	f_arid,
	f_araddr,
	f_arvalid,
	f_arready,
	f_rid,
	f_rdata,
	f_rvalid,
	f_rready
);
	parameter [31:0] AURORA_AW = 32;
	parameter [31:0] AURORA_DW = 128;
	parameter [31:0] AURORA_IW = 4;
	parameter [31:0] ROCKET_DW = 64;
	input wire [AURORA_IW - 1:0] r_awid;
	input wire [AURORA_AW - 1:0] r_awaddr;
	input wire r_awvalid;
	output wire r_awready;
	input wire [ROCKET_DW - 1:0] r_wdata;
	input wire [(ROCKET_DW / 8) - 1:0] r_wstrb;
	input wire r_wvalid;
	output wire r_wready;
	output wire [AURORA_IW - 1:0] r_bid;
	output wire [1:0] r_bresp;
	output wire r_bvalid;
	input wire r_bready;
	input wire [AURORA_IW - 1:0] r_arid;
	input wire [AURORA_AW - 1:0] r_araddr;
	input wire r_arvalid;
	output wire r_arready;
	output wire [AURORA_IW - 1:0] r_rid;
	output wire [ROCKET_DW - 1:0] r_rdata;
	output wire [1:0] r_rresp;
	output wire r_rlast;
	output wire r_rvalid;
	input wire r_rready;
	input wire clk;
	input wire rst_n;
	output wire [AURORA_IW - 1:0] f_awid;
	output wire [AURORA_AW - 1:0] f_awaddr;
	output wire f_awvalid;
	input wire f_awready;
	output wire [AURORA_DW - 1:0] f_wdata;
	output wire [(AURORA_DW / 8) - 1:0] f_wstrb;
	output wire f_wvalid;
	input wire f_wready;
	input wire [AURORA_IW - 1:0] f_bid;
	input wire f_bvalid;
	output wire f_bready;
	output wire [AURORA_IW - 1:0] f_arid;
	output wire [AURORA_AW - 1:0] f_araddr;
	output wire f_arvalid;
	input wire f_arready;
	input wire [AURORA_IW - 1:0] f_rid;
	input wire [AURORA_DW - 1:0] f_rdata;
	input wire f_rvalid;
	output wire f_rready;
	localparam [31:0] TD = 32;
	localparam [31:0] TPW = 5;
	reg [4:0] rd_wp;
	reg [4:0] rd_rp;
	reg [AURORA_IW:0] rd_mem [0:31];
	reg [4:0] wl_wp;
	reg [4:0] wl_rp;
	reg [4:0] wi_rp;
	reg wl_mem [0:31];
	reg [AURORA_IW - 1:0] wi_mem [0:31];
	wire ar_fire = r_arvalid && r_arready;
	wire r_fire = r_rvalid && r_rready;
	wire aw_fire = r_awvalid && r_awready;
	wire w_fire = r_wvalid && r_wready;
	wire b_fire = r_bvalid && r_bready;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			rd_wp <= 1'sb0;
			rd_rp <= 1'sb0;
			wl_wp <= 1'sb0;
			wl_rp <= 1'sb0;
			wi_rp <= 1'sb0;
		end
		else begin
			if (ar_fire) begin
				rd_mem[rd_wp] <= {r_araddr[3], r_arid};
				rd_wp <= rd_wp + 1'b1;
			end
			if (r_fire)
				rd_rp <= rd_rp + 1'b1;
			if (aw_fire) begin
				wl_mem[wl_wp] <= r_awaddr[3];
				wi_mem[wl_wp] <= r_awid;
				wl_wp <= wl_wp + 1'b1;
			end
			if (w_fire)
				wl_rp <= wl_rp + 1'b1;
			if (b_fire)
				wi_rp <= wi_rp + 1'b1;
		end
	wire rd_lane_h = rd_mem[rd_rp][AURORA_IW];
	wire [AURORA_IW - 1:0] rd_id_h = rd_mem[rd_rp][AURORA_IW - 1:0];
	wire wl_empty = wl_wp == wl_rp;
	wire wr_lane = (wl_empty && aw_fire ? r_awaddr[3] : wl_mem[wl_rp]);
	assign f_awid = r_awid;
	assign f_awaddr = r_awaddr;
	assign f_awvalid = r_awvalid;
	assign r_awready = f_awready;
	assign f_wdata = (wr_lane ? {r_wdata, {ROCKET_DW {1'b0}}} : {{ROCKET_DW {1'b0}}, r_wdata});
	assign f_wstrb = (wr_lane ? {r_wstrb, {ROCKET_DW / 8 {1'b0}}} : {{ROCKET_DW / 8 {1'b0}}, r_wstrb});
	assign f_wvalid = r_wvalid;
	assign r_wready = f_wready;
	assign f_arid = r_arid;
	assign f_araddr = r_araddr;
	assign f_arvalid = r_arvalid;
	assign r_arready = f_arready;
	assign f_bready = r_bready;
	assign f_rready = r_rready;
	assign r_bvalid = f_bvalid;
	assign r_bid = wi_mem[wi_rp];
	assign r_bresp = 2'b00;
	assign r_rvalid = f_rvalid;
	assign r_rid = rd_id_h;
	assign r_rdata = (rd_lane_h ? f_rdata[AURORA_DW - 1:ROCKET_DW] : f_rdata[ROCKET_DW - 1:0]);
	assign r_rresp = 2'b00;
	assign r_rlast = 1'b1;
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
	reg bvalid_reg;
	wire wr_accept = (awvalid && wvalid) && !bvalid_reg;
	assign awready = wr_accept;
	assign wready = wr_accept;
	always @(posedge clk)
		if (wr_accept) begin : sv2v_autoblock_1
			reg signed [31:0] b;
			for (b = 0; b < (DATA_WIDTH / 8); b = b + 1)
				if (wstrb[b])
					bank_mem[write_bank][write_index][8 * b+:8] <= wdata[8 * b+:8];
		end
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			bvalid_reg <= 0;
		else if (wr_accept)
			bvalid_reg <= 1;
		else if (bvalid_reg && bready)
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
module aurora_soc_top_chip (
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
	wire [ID_WIDTH - 1:0] rk_awid;
	wire [ADDR_WIDTH - 1:0] rk_awaddr;
	wire rk_awvalid;
	wire rk_awready;
	wire [63:0] rk_wdata;
	wire [7:0] rk_wstrb;
	wire rk_wvalid;
	wire rk_wready;
	wire rk_wlast;
	wire [ID_WIDTH - 1:0] rk_bid;
	wire [1:0] rk_bresp;
	wire rk_bvalid;
	wire rk_bready;
	wire [ID_WIDTH - 1:0] rk_arid;
	wire [ADDR_WIDTH - 1:0] rk_araddr;
	wire rk_arvalid;
	wire rk_arready;
	wire [ID_WIDTH - 1:0] rk_rid;
	wire [63:0] rk_rdata;
	wire [1:0] rk_rresp;
	wire rk_rlast;
	wire rk_rvalid;
	wire rk_rready;
	wire [ID_WIDTH - 1:0] mm_awid;
	wire [30:0] mm_awaddr;
	wire mm_awvalid;
	wire mm_awready;
	wire [63:0] mm_wdata;
	wire [7:0] mm_wstrb;
	wire mm_wvalid;
	wire mm_wready;
	wire mm_wlast;
	wire [ID_WIDTH - 1:0] mm_bid;
	wire [1:0] mm_bresp;
	wire mm_bvalid;
	wire mm_bready;
	wire [ID_WIDTH - 1:0] mm_arid;
	wire [30:0] mm_araddr;
	wire mm_arvalid;
	wire mm_arready;
	wire [ID_WIDTH - 1:0] mm_rid;
	wire [63:0] mm_rdata;
	wire [1:0] mm_rresp;
	wire mm_rlast;
	wire mm_rvalid;
	wire mm_rready;
	RocketAXITileTop u_rocket(
		.clock(cpu_clk),
		.reset(~cpu_rst_n),
		.mem_axi4_0_aw_valid(rk_awvalid),
		.mem_axi4_0_aw_ready(rk_awready),
		.mem_axi4_0_aw_bits_id(rk_awid),
		.mem_axi4_0_aw_bits_addr(rk_awaddr),
		.mem_axi4_0_aw_bits_len(),
		.mem_axi4_0_aw_bits_size(),
		.mem_axi4_0_aw_bits_burst(),
		.mem_axi4_0_aw_bits_lock(),
		.mem_axi4_0_aw_bits_cache(),
		.mem_axi4_0_aw_bits_prot(),
		.mem_axi4_0_aw_bits_qos(),
		.mem_axi4_0_w_valid(rk_wvalid),
		.mem_axi4_0_w_ready(rk_wready),
		.mem_axi4_0_w_bits_data(rk_wdata),
		.mem_axi4_0_w_bits_strb(rk_wstrb),
		.mem_axi4_0_w_bits_last(rk_wlast),
		.mem_axi4_0_b_valid(rk_bvalid),
		.mem_axi4_0_b_ready(rk_bready),
		.mem_axi4_0_b_bits_id(rk_bid),
		.mem_axi4_0_b_bits_resp(rk_bresp),
		.mem_axi4_0_ar_valid(rk_arvalid),
		.mem_axi4_0_ar_ready(rk_arready),
		.mem_axi4_0_ar_bits_id(rk_arid),
		.mem_axi4_0_ar_bits_addr(rk_araddr),
		.mem_axi4_0_ar_bits_len(),
		.mem_axi4_0_ar_bits_size(),
		.mem_axi4_0_ar_bits_burst(),
		.mem_axi4_0_ar_bits_lock(),
		.mem_axi4_0_ar_bits_cache(),
		.mem_axi4_0_ar_bits_prot(),
		.mem_axi4_0_ar_bits_qos(),
		.mem_axi4_0_r_valid(rk_rvalid),
		.mem_axi4_0_r_ready(rk_rready),
		.mem_axi4_0_r_bits_id(rk_rid),
		.mem_axi4_0_r_bits_data(rk_rdata),
		.mem_axi4_0_r_bits_resp(rk_rresp),
		.mem_axi4_0_r_bits_last(rk_rlast),
		.mmio_axi4_0_aw_valid(mm_awvalid),
		.mmio_axi4_0_aw_ready(mm_awready),
		.mmio_axi4_0_aw_bits_id(mm_awid),
		.mmio_axi4_0_aw_bits_addr(mm_awaddr),
		.mmio_axi4_0_aw_bits_len(),
		.mmio_axi4_0_aw_bits_size(),
		.mmio_axi4_0_aw_bits_burst(),
		.mmio_axi4_0_aw_bits_lock(),
		.mmio_axi4_0_aw_bits_cache(),
		.mmio_axi4_0_aw_bits_prot(),
		.mmio_axi4_0_aw_bits_qos(),
		.mmio_axi4_0_w_valid(mm_wvalid),
		.mmio_axi4_0_w_ready(mm_wready),
		.mmio_axi4_0_w_bits_data(mm_wdata),
		.mmio_axi4_0_w_bits_strb(mm_wstrb),
		.mmio_axi4_0_w_bits_last(mm_wlast),
		.mmio_axi4_0_b_valid(mm_bvalid),
		.mmio_axi4_0_b_ready(mm_bready),
		.mmio_axi4_0_b_bits_id(mm_bid),
		.mmio_axi4_0_b_bits_resp(mm_bresp),
		.mmio_axi4_0_ar_valid(mm_arvalid),
		.mmio_axi4_0_ar_ready(mm_arready),
		.mmio_axi4_0_ar_bits_id(mm_arid),
		.mmio_axi4_0_ar_bits_addr(mm_araddr),
		.mmio_axi4_0_ar_bits_len(),
		.mmio_axi4_0_ar_bits_size(),
		.mmio_axi4_0_ar_bits_burst(),
		.mmio_axi4_0_ar_bits_lock(),
		.mmio_axi4_0_ar_bits_cache(),
		.mmio_axi4_0_ar_bits_prot(),
		.mmio_axi4_0_ar_bits_qos(),
		.mmio_axi4_0_r_valid(mm_rvalid),
		.mmio_axi4_0_r_ready(mm_rready),
		.mmio_axi4_0_r_bits_id(mm_rid),
		.mmio_axi4_0_r_bits_data(mm_rdata),
		.mmio_axi4_0_r_bits_resp(mm_rresp),
		.mmio_axi4_0_r_bits_last(mm_rlast)
	);
	wire [ID_WIDTH - 1:0] rw_awid;
	wire [ADDR_WIDTH - 1:0] rw_awaddr;
	wire rw_awvalid;
	wire rw_awready;
	wire [DATA_WIDTH - 1:0] rw_wdata;
	wire [(DATA_WIDTH / 8) - 1:0] rw_wstrb;
	wire rw_wvalid;
	wire rw_wready;
	wire [ID_WIDTH - 1:0] rw_bid;
	wire rw_bvalid;
	wire rw_bready;
	wire [ID_WIDTH - 1:0] rw_arid;
	wire [ADDR_WIDTH - 1:0] rw_araddr;
	wire rw_arvalid;
	wire rw_arready;
	wire [ID_WIDTH - 1:0] rw_rid;
	wire [DATA_WIDTH - 1:0] rw_rdata;
	wire rw_rvalid;
	wire rw_rready;
	rocket_axi_wrapper u_rocket_wrap(
		.clk(cpu_clk),
		.rst_n(cpu_rst_n),
		.r_awid(rk_awid),
		.r_awaddr(rk_awaddr),
		.r_awvalid(rk_awvalid),
		.r_awready(rk_awready),
		.r_wdata(rk_wdata),
		.r_wstrb(rk_wstrb),
		.r_wvalid(rk_wvalid),
		.r_wready(rk_wready),
		.r_bid(rk_bid),
		.r_bresp(rk_bresp),
		.r_bvalid(rk_bvalid),
		.r_bready(rk_bready),
		.r_arid(rk_arid),
		.r_araddr(rk_araddr),
		.r_arvalid(rk_arvalid),
		.r_arready(rk_arready),
		.r_rid(rk_rid),
		.r_rdata(rk_rdata),
		.r_rresp(rk_rresp),
		.r_rlast(rk_rlast),
		.r_rvalid(rk_rvalid),
		.r_rready(rk_rready),
		.f_awid(rw_awid),
		.f_awaddr(rw_awaddr),
		.f_awvalid(rw_awvalid),
		.f_awready(rw_awready),
		.f_wdata(rw_wdata),
		.f_wstrb(rw_wstrb),
		.f_wvalid(rw_wvalid),
		.f_wready(rw_wready),
		.f_bid(rw_bid),
		.f_bvalid(rw_bvalid),
		.f_bready(rw_bready),
		.f_arid(rw_arid),
		.f_araddr(rw_araddr),
		.f_arvalid(rw_arvalid),
		.f_arready(rw_arready),
		.f_rid(rw_rid),
		.f_rdata(rw_rdata),
		.f_rvalid(rw_rvalid),
		.f_rready(rw_rready)
	);
	localparam sv2v_uu_u_cpu_cdc_ID_WIDTH = ID_WIDTH;
	localparam [sv2v_uu_u_cpu_cdc_ID_WIDTH - 1:0] sv2v_uu_u_cpu_cdc_ext_m_axi_bid_0 = 1'sb0;
	localparam [sv2v_uu_u_cpu_cdc_ID_WIDTH - 1:0] sv2v_uu_u_cpu_cdc_ext_m_axi_rid_0 = 1'sb0;
	axi_cdc_bridge #(
		.DATA_WIDTH(DATA_WIDTH),
		.ADDR_WIDTH(ADDR_WIDTH),
		.ID_WIDTH(ID_WIDTH)
	) u_cpu_cdc(
		.cpu_clk(cpu_clk),
		.cpu_rst_n(cpu_rst_n),
		.fabric_clk(fabric_clk),
		.fabric_rst_n(fabric_rst_n),
		.s_axi_awid(rw_awid),
		.s_axi_awaddr(rw_awaddr),
		.s_axi_awvalid(rw_awvalid),
		.s_axi_awready(rw_awready),
		.s_axi_wdata(rw_wdata),
		.s_axi_wstrb(rw_wstrb),
		.s_axi_wvalid(rw_wvalid),
		.s_axi_wready(rw_wready),
		.s_axi_bid(rw_bid),
		.s_axi_bvalid(rw_bvalid),
		.s_axi_bready(rw_bready),
		.s_axi_arid(rw_arid),
		.s_axi_araddr(rw_araddr),
		.s_axi_arvalid(rw_arvalid),
		.s_axi_arready(rw_arready),
		.s_axi_rid(rw_rid),
		.s_axi_rdata(rw_rdata),
		.s_axi_rvalid(rw_rvalid),
		.s_axi_rready(rw_rready),
		.m_axi_awid(),
		.m_axi_awaddr(xm_awaddr[0+:ADDR_WIDTH]),
		.m_axi_awvalid(xm_awvalid[0]),
		.m_axi_awready(xm_awready[0]),
		.m_axi_wdata(xm_wdata[0+:DATA_WIDTH]),
		.m_axi_wstrb(xm_wstrb[0+:DATA_WIDTH / 8]),
		.m_axi_wvalid(xm_wvalid[0]),
		.m_axi_wready(xm_wready[0]),
		.m_axi_bid(sv2v_uu_u_cpu_cdc_ext_m_axi_bid_0),
		.m_axi_bvalid(xm_bvalid[0]),
		.m_axi_bready(xm_bready[0]),
		.m_axi_arid(),
		.m_axi_araddr(xm_araddr[0+:ADDR_WIDTH]),
		.m_axi_arvalid(xm_arvalid[0]),
		.m_axi_arready(xm_arready[0]),
		.m_axi_rid(sv2v_uu_u_cpu_cdc_ext_m_axi_rid_0),
		.m_axi_rdata(xm_rdata[0+:DATA_WIDTH]),
		.m_axi_rvalid(xm_rvalid[0]),
		.m_axi_rready(xm_rready[0])
	);
	wire [ID_WIDTH - 1:0] mw_awid;
	wire [ADDR_WIDTH - 1:0] mw_awaddr;
	wire mw_awvalid;
	wire mw_awready;
	wire [DATA_WIDTH - 1:0] mw_wdata;
	wire [(DATA_WIDTH / 8) - 1:0] mw_wstrb;
	wire mw_wvalid;
	wire mw_wready;
	wire [ID_WIDTH - 1:0] mw_bid;
	wire mw_bvalid;
	wire mw_bready;
	wire [ID_WIDTH - 1:0] mw_arid;
	wire [ADDR_WIDTH - 1:0] mw_araddr;
	wire mw_arvalid;
	wire mw_arready;
	wire [ID_WIDTH - 1:0] mw_rid;
	wire [DATA_WIDTH - 1:0] mw_rdata;
	wire mw_rvalid;
	wire mw_rready;
	rocket_axi_wrapper u_rocket_wrap_mmio(
		.clk(cpu_clk),
		.rst_n(cpu_rst_n),
		.r_awid(mm_awid),
		.r_awaddr({1'b0, mm_awaddr}),
		.r_awvalid(mm_awvalid),
		.r_awready(mm_awready),
		.r_wdata(mm_wdata),
		.r_wstrb(mm_wstrb),
		.r_wvalid(mm_wvalid),
		.r_wready(mm_wready),
		.r_bid(mm_bid),
		.r_bresp(mm_bresp),
		.r_bvalid(mm_bvalid),
		.r_bready(mm_bready),
		.r_arid(mm_arid),
		.r_araddr({1'b0, mm_araddr}),
		.r_arvalid(mm_arvalid),
		.r_arready(mm_arready),
		.r_rid(mm_rid),
		.r_rdata(mm_rdata),
		.r_rresp(mm_rresp),
		.r_rlast(mm_rlast),
		.r_rvalid(mm_rvalid),
		.r_rready(mm_rready),
		.f_awid(mw_awid),
		.f_awaddr(mw_awaddr),
		.f_awvalid(mw_awvalid),
		.f_awready(mw_awready),
		.f_wdata(mw_wdata),
		.f_wstrb(mw_wstrb),
		.f_wvalid(mw_wvalid),
		.f_wready(mw_wready),
		.f_bid(mw_bid),
		.f_bvalid(mw_bvalid),
		.f_bready(mw_bready),
		.f_arid(mw_arid),
		.f_araddr(mw_araddr),
		.f_arvalid(mw_arvalid),
		.f_arready(mw_arready),
		.f_rid(mw_rid),
		.f_rdata(mw_rdata),
		.f_rvalid(mw_rvalid),
		.f_rready(mw_rready)
	);
	localparam sv2v_uu_u_mmio_cdc_ID_WIDTH = ID_WIDTH;
	localparam [sv2v_uu_u_mmio_cdc_ID_WIDTH - 1:0] sv2v_uu_u_mmio_cdc_ext_m_axi_bid_0 = 1'sb0;
	localparam [sv2v_uu_u_mmio_cdc_ID_WIDTH - 1:0] sv2v_uu_u_mmio_cdc_ext_m_axi_rid_0 = 1'sb0;
	axi_cdc_bridge #(
		.DATA_WIDTH(DATA_WIDTH),
		.ADDR_WIDTH(ADDR_WIDTH),
		.ID_WIDTH(ID_WIDTH)
	) u_mmio_cdc(
		.cpu_clk(cpu_clk),
		.cpu_rst_n(cpu_rst_n),
		.fabric_clk(fabric_clk),
		.fabric_rst_n(fabric_rst_n),
		.s_axi_awid(mw_awid),
		.s_axi_awaddr(mw_awaddr),
		.s_axi_awvalid(mw_awvalid),
		.s_axi_awready(mw_awready),
		.s_axi_wdata(mw_wdata),
		.s_axi_wstrb(mw_wstrb),
		.s_axi_wvalid(mw_wvalid),
		.s_axi_wready(mw_wready),
		.s_axi_bid(mw_bid),
		.s_axi_bvalid(mw_bvalid),
		.s_axi_bready(mw_bready),
		.s_axi_arid(mw_arid),
		.s_axi_araddr(mw_araddr),
		.s_axi_arvalid(mw_arvalid),
		.s_axi_arready(mw_arready),
		.s_axi_rid(mw_rid),
		.s_axi_rdata(mw_rdata),
		.s_axi_rvalid(mw_rvalid),
		.s_axi_rready(mw_rready),
		.m_axi_awid(),
		.m_axi_awaddr(xm_awaddr[ADDR_WIDTH+:ADDR_WIDTH]),
		.m_axi_awvalid(xm_awvalid[1]),
		.m_axi_awready(xm_awready[1]),
		.m_axi_wdata(xm_wdata[DATA_WIDTH+:DATA_WIDTH]),
		.m_axi_wstrb(xm_wstrb[DATA_WIDTH / 8+:DATA_WIDTH / 8]),
		.m_axi_wvalid(xm_wvalid[1]),
		.m_axi_wready(xm_wready[1]),
		.m_axi_bid(sv2v_uu_u_mmio_cdc_ext_m_axi_bid_0),
		.m_axi_bvalid(xm_bvalid[1]),
		.m_axi_bready(xm_bready[1]),
		.m_axi_arid(),
		.m_axi_araddr(xm_araddr[ADDR_WIDTH+:ADDR_WIDTH]),
		.m_axi_arvalid(xm_arvalid[1]),
		.m_axi_arready(xm_arready[1]),
		.m_axi_rid(sv2v_uu_u_mmio_cdc_ext_m_axi_rid_0),
		.m_axi_rdata(xm_rdata[DATA_WIDTH+:DATA_WIDTH]),
		.m_axi_rvalid(xm_rvalid[1]),
		.m_axi_rready(xm_rready[1])
	);
	genvar _gv_mi_1;
	generate
		for (_gv_mi_1 = 2; _gv_mi_1 < NM; _gv_mi_1 = _gv_mi_1 + 1) begin : UNUSED_MASTERS
			localparam mi = _gv_mi_1;
			assign xm_awaddr[mi * ADDR_WIDTH+:ADDR_WIDTH] = 1'sb0;
			assign xm_awvalid[mi] = 1'b0;
			assign xm_wdata[mi * DATA_WIDTH+:DATA_WIDTH] = 1'sb0;
			assign xm_wstrb[mi * (DATA_WIDTH / 8)+:DATA_WIDTH / 8] = 1'sb0;
			assign xm_wvalid[mi] = 1'b0;
			assign xm_bready[mi] = 1'b0;
			assign xm_araddr[mi * ADDR_WIDTH+:ADDR_WIDTH] = 1'sb0;
			assign xm_arvalid[mi] = 1'b0;
			assign xm_rready[mi] = 1'b0;
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
		.BANK_DEPTH(64)
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
	wire uart_irq;
	wire gpio_irq;
	wire timer_irq_periph;
	wire tensor_irq;
	wire [31:0] uart_rdata32;
	wire [31:0] gpio_rdata32;
	wire [31:0] timer_rdata32;
	wire [31:0] tensor_rdata32;
	uart #(
		.CLK_FREQ(50000000),
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
	timer #(.CLK_FREQ(50000000)) timer_inst(
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
	tensor_core_hard u_tensor(
		.clk(fabric_clk),
		.rst_n(fabric_rst_n),
		.s_axi_awaddr(xs_awaddr[5 * ADDR_WIDTH+:ADDR_WIDTH]),
		.s_axi_awvalid(xs_awvalid[5]),
		.s_axi_awready(xs_awready[5]),
		.s_axi_wdata(lane32(xs_wdata[5 * DATA_WIDTH+:DATA_WIDTH], xs_awaddr[(5 * ADDR_WIDTH) + 3-:2])),
		.s_axi_wvalid(xs_wvalid[5]),
		.s_axi_wready(xs_wready[5]),
		.s_axi_bvalid(xs_bvalid[5]),
		.s_axi_bready(xs_bready[5]),
		.s_axi_araddr(xs_araddr[5 * ADDR_WIDTH+:ADDR_WIDTH]),
		.s_axi_arvalid(xs_arvalid[5]),
		.s_axi_arready(xs_arready[5]),
		.s_axi_rdata(tensor_rdata32),
		.s_axi_rvalid(xs_rvalid[5]),
		.s_axi_rready(xs_rready[5]),
		.core_done_irq(tensor_irq)
	);
	assign xs_rdata[5 * DATA_WIDTH+:DATA_WIDTH] = {4 {tensor_rdata32}};
	reg [7:6] rsvd_bvalid;
	reg [7:6] rsvd_rvalid;
	genvar _gv_si_1;
	generate
		for (_gv_si_1 = 6; _gv_si_1 < NS; _gv_si_1 = _gv_si_1 + 1) begin : ERR_SINK
			localparam si = _gv_si_1;
			always @(posedge fabric_clk or negedge fabric_rst_n)
				if (!fabric_rst_n) begin
					rsvd_bvalid[si] <= 1'b0;
					rsvd_rvalid[si] <= 1'b0;
				end
				else begin
					if (xs_awvalid[si] && xs_wvalid[si])
						rsvd_bvalid[si] <= 1'b1;
					else if (rsvd_bvalid[si] && xs_bready[si])
						rsvd_bvalid[si] <= 1'b0;
					if (xs_arvalid[si])
						rsvd_rvalid[si] <= 1'b1;
					else if (rsvd_rvalid[si] && xs_rready[si])
						rsvd_rvalid[si] <= 1'b0;
				end
			assign xs_awready[si] = 1'b1;
			assign xs_wready[si] = 1'b1;
			assign xs_bvalid[si] = rsvd_bvalid[si];
			assign xs_arready[si] = 1'b1;
			assign xs_rdata[si * DATA_WIDTH+:DATA_WIDTH] = 1'sb0;
			assign xs_rvalid[si] = rsvd_rvalid[si];
		end
	endgenerate
	wire [15:0] irq_sources;
	assign irq_sources = {11'h000, tensor_irq, timer_irq_periph, gpio_irq, uart_irq, 1'b0};
	interrupt_controller #(.NUM_IRQ(16)) irq_ctrl(
		.clk(fabric_clk),
		.rst_n(fabric_rst_n),
		.irq_sources(irq_sources),
		.clear(1'b0),
		.irq_out(global_irq)
	);
endmodule