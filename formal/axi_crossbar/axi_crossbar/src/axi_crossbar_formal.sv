// Formal verification harness for the Aurora AXI crossbar (current
// interface: single-beat, no IDs, wstrb routed, grant locking).
//
// Environment: NM nondeterministic masters obeying AXI valid/payload
// stability, NS slaves that only respond to transactions actually
// delivered to them. All checks observe the DUT boundary only — a shadow
// model reconstructs ownership from the handshakes, so no hierarchical
// references are needed.
//
// Checked properties:
//   P1  while a write/read transaction is open at slave s, no new AW/AR
//       beat is presented to s (grant lock, single outstanding per slave)
//   P2  responses are never spurious and never dropped: m_bvalid[m] iff
//       some slave with an open write owned by m is asserting B (same for R)
//   P3  decode integrity: any AW/AR presented at slave s decodes to s
//   P4  a master never owns two slaves in the same direction
//   P5  read data routing: the data a master receives equals the data the
//       responding slave is driving
//
// DATA_WIDTH is shrunk to 8: the datapath is pure routing, width carries
// no protocol behavior.

`default_nettype none

module axi_crossbar_formal (
    input wire clk,

    // free inputs (master side)
    input wire [1:0][31:0] m_awaddr,
    input wire [1:0]       m_awvalid,
    input wire [1:0][7:0]  m_wdata,
    input wire [1:0][0:0]  m_wstrb,
    input wire [1:0]       m_wvalid,
    input wire [1:0]       m_bready,
    input wire [1:0][31:0] m_araddr,
    input wire [1:0]       m_arvalid,
    input wire [1:0]       m_rready,

    // free inputs (slave side)
    input wire [7:0]       s_awready_e,
    input wire [7:0]       s_wready_e,
    input wire [7:0]       s_arready_e,
    input wire [7:0]       s_bvalid_e,
    input wire [7:0]       s_rvalid_e,
    input wire [7:0][7:0]  s_rdata
);

    localparam int NM = 2;
    localparam int NS = 8;
    localparam int DW = 8;

    // ----- reset: exactly one initial reset cycle -----
    logic init = 1'b1;
    always @(posedge clk) init <= 1'b0;
    wire rst_n = !init;

    logic f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;

    // ----- DUT boundary wires -----
    logic [NM-1:0] m_awready, m_wready, m_bvalid;
    logic [NM-1:0] m_arready, m_rvalid;
    logic [NM-1:0][DW-1:0] m_rdata;

    logic [NS-1:0][31:0]     s_awaddr, s_araddr;
    logic [NS-1:0]           s_awvalid, s_arvalid;
    logic [NS-1:0][DW-1:0]   s_wdata;
    logic [NS-1:0][DW/8-1:0] s_wstrb;
    logic [NS-1:0]           s_wvalid;
    logic [NS-1:0]           s_bready, s_rready;
    logic [NS-1:0]           s_bvalid, s_rvalid;

    axi_crossbar #(
        .DATA_WIDTH (DW),
        .ADDR_WIDTH (32),
        .NUM_MASTERS(NM),
        .NUM_SLAVES (NS)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .m_awaddr(m_awaddr), .m_awvalid(m_awvalid), .m_awready(m_awready),
        .m_wdata(m_wdata), .m_wstrb(m_wstrb), .m_wvalid(m_wvalid), .m_wready(m_wready),
        .m_bvalid(m_bvalid), .m_bready(m_bready),
        .m_araddr(m_araddr), .m_arvalid(m_arvalid), .m_arready(m_arready),
        .m_rdata(m_rdata), .m_rvalid(m_rvalid), .m_rready(m_rready),
        .s_awaddr(s_awaddr), .s_awvalid(s_awvalid), .s_awready(s_awready_e),
        .s_wdata(s_wdata), .s_wstrb(s_wstrb), .s_wvalid(s_wvalid), .s_wready(s_wready_e),
        .s_bvalid(s_bvalid), .s_bready(s_bready),
        .s_araddr(s_araddr), .s_arvalid(s_arvalid), .s_arready(s_arready_e),
        .s_rdata(s_rdata), .s_rvalid(s_rvalid), .s_rready(s_rready)
    );

    // local copy of the DUT's address decode (kept in sync by P3's intent)
    function automatic logic [2:0] decode_address(input logic [31:0] addr);
        begin
            if (addr[31:24] == 8'h00) decode_address = 3'd0;
            else if (addr[31:26] == 6'h04) decode_address = 3'd1;  // 0x10..0x13
            else if (addr[31:24] == 8'h20) decode_address = 3'd2;
            else if (addr[31:24] == 8'h30) decode_address = 3'd3;
            else if (addr[31:24] == 8'h40) decode_address = 3'd4;
            else if (addr[31:24] == 8'h50) decode_address = 3'd5;
            else if (addr[31:24] == 8'h60) decode_address = 3'd6;
            else decode_address = 3'd7;
        end
    endfunction

    // =====================================================================
    // Master environment assumptions (AXI valid/payload stability)
    // =====================================================================
    genvar m;
    generate for (m = 0; m < NM; m++) begin : MASTER_ENV
        always @(posedge clk) begin
            if (f_past_valid && rst_n) begin
                if ($past(m_awvalid[m] && !m_awready[m] && rst_n)) begin
                    assume (m_awvalid[m]);
                    assume ($stable(m_awaddr[m]));
                end
                if ($past(m_arvalid[m] && !m_arready[m] && rst_n)) begin
                    assume (m_arvalid[m]);
                    assume ($stable(m_araddr[m]));
                end
                if ($past(m_wvalid[m] && !m_wready[m] && rst_n)) begin
                    assume (m_wvalid[m]);
                    assume ($stable(m_wdata[m]));
                    assume ($stable(m_wstrb[m]));
                end
            end
            // single-beat contract: W accompanies AW
            assume (m_wvalid[m] == m_awvalid[m]);
        end
    end endgenerate

    // =====================================================================
    // Slave environment: respond only to delivered transactions
    // =====================================================================
    logic [NS-1:0] env_wr_open;   // AW accepted, B not yet returned
    logic [NS-1:0] env_rd_open;   // AR accepted, R not yet returned

    genvar s;
    generate for (s = 0; s < NS; s++) begin : SLAVE_ENV
        always @(posedge clk) begin
            if (!rst_n) begin
                env_wr_open[s] <= 1'b0;
                env_rd_open[s] <= 1'b0;
            end else begin
                if (s_awvalid[s] && s_awready_e[s]) env_wr_open[s] <= 1'b1;
                else if (s_bvalid[s] && s_bready[s]) env_wr_open[s] <= 1'b0;
                if (s_arvalid[s] && s_arready_e[s]) env_rd_open[s] <= 1'b1;
                else if (s_rvalid[s] && s_rready[s]) env_rd_open[s] <= 1'b0;
            end
        end

        assign s_bvalid[s] = s_bvalid_e[s] && env_wr_open[s];
        assign s_rvalid[s] = s_rvalid_e[s] && env_rd_open[s];
    end endgenerate

    // =====================================================================
    // Shadow ownership model (from boundary handshakes only)
    // =====================================================================
    logic [NS-1:0]      sh_wr_busy, sh_rd_busy;
    logic [NS-1:0][0:0] sh_wr_owner, sh_rd_owner;   // $clog2(NM)=1 bit

    generate for (s = 0; s < NS; s++) begin : SHADOW
        always @(posedge clk) begin
            if (!rst_n) begin
                sh_wr_busy[s] <= 1'b0;
                sh_rd_busy[s] <= 1'b0;
                sh_wr_owner[s] <= '0;
                sh_rd_owner[s] <= '0;
            end else begin
                if (!sh_wr_busy[s] && s_awvalid[s] && s_awready_e[s]) begin
                    sh_wr_busy[s] <= 1'b1;
                    // the accepting master is the one whose AW handshakes
                    // to this slave this cycle
                    for (int k = 0; k < NM; k++)
                        if (m_awvalid[k] && m_awready[k] &&
                            decode_address(m_awaddr[k]) == s[2:0])
                            sh_wr_owner[s] <= k[0];
                end else if (sh_wr_busy[s] && s_bvalid[s] && s_bready[s])
                    sh_wr_busy[s] <= 1'b0;

                if (!sh_rd_busy[s] && s_arvalid[s] && s_arready_e[s]) begin
                    sh_rd_busy[s] <= 1'b1;
                    for (int k = 0; k < NM; k++)
                        if (m_arvalid[k] && m_arready[k] &&
                            decode_address(m_araddr[k]) == s[2:0])
                            sh_rd_owner[s] <= k[0];
                end else if (sh_rd_busy[s] && s_rvalid[s] && s_rready[s])
                    sh_rd_busy[s] <= 1'b0;
            end
        end
    end endgenerate

    // =====================================================================
    // Properties
    // =====================================================================
    generate for (s = 0; s < NS; s++) begin : PROPS_SLAVE
        always @(posedge clk) begin
            if (rst_n) begin
                // P1: no new address beat while a transaction is open
                if (sh_wr_busy[s]) assert (!s_awvalid[s]);
                if (sh_rd_busy[s]) assert (!s_arvalid[s]);
                // P3: decode integrity
                if (s_awvalid[s]) assert (decode_address(s_awaddr[s]) == s[2:0]);
                if (s_arvalid[s]) assert (decode_address(s_araddr[s]) == s[2:0]);
            end
        end
    end endgenerate

    generate for (m = 0; m < NM; m++) begin : PROPS_MASTER
        logic resp_b_expect, resp_r_expect;
        logic [DW-1:0] resp_r_data;
        logic [3:0] wr_own_cnt, rd_own_cnt;

        always @(*) begin
            resp_b_expect = 1'b0;
            resp_r_expect = 1'b0;
            resp_r_data   = '0;
            wr_own_cnt    = '0;
            rd_own_cnt    = '0;
            for (int k = 0; k < NS; k++) begin
                if (sh_wr_busy[k] && (sh_wr_owner[k] == m[0])) begin
                    wr_own_cnt = wr_own_cnt + 1'b1;
                    if (s_bvalid[k]) resp_b_expect = 1'b1;
                end
                if (sh_rd_busy[k] && (sh_rd_owner[k] == m[0])) begin
                    rd_own_cnt = rd_own_cnt + 1'b1;
                    if (s_rvalid[k]) begin
                        resp_r_expect = 1'b1;
                        resp_r_data   = s_rdata[k];
                    end
                end
            end
        end

        always @(posedge clk) begin
            if (rst_n) begin
                // P2: responses exactly when an owned slave responds
                assert (m_bvalid[m] == resp_b_expect);
                assert (m_rvalid[m] == resp_r_expect);
                // P5: read data routed unmodified
                if (m_rvalid[m]) assert (m_rdata[m] == resp_r_data);
                // P4: single ownership per direction
                assert (wr_own_cnt <= 4'd1);
                assert (rd_own_cnt <= 4'd1);
            end
        end
    end endgenerate

    // =====================================================================
    // Covers — transactions complete for both masters
    // =====================================================================
    always @(posedge clk) begin
        if (rst_n) begin
            cover (m_bvalid[0] && m_bready[0]);
            cover (m_rvalid[0] && m_rready[0]);
            cover (m_bvalid[1] && m_bready[1]);
            cover (m_rvalid[1] && m_rready[1]);
        end
    end

endmodule
