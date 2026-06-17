// cva6_axi_wrapper.sv — Aurora v1
// noc_req_t/noc_resp_t match ariane_axi::req_t/resp_t exactly.

`timescale 1ns/1ps
/* verilator lint_off PINMISSING */
/* verilator lint_off WIDTH      */
/* verilator lint_off UNUSED     */
/* verilator lint_off UNDRIVEN   */
/* verilator lint_off ASCRANGE   */

module cva6_axi_wrapper #(
    parameter logic [63:0] BOOT_ADDR = 64'h0000_0000_0000_0000,
    parameter logic [63:0] HART_ID   = 64'h0,
    parameter int unsigned AURORA_AW = 32,
    parameter int unsigned AURORA_DW = 128,
    parameter int unsigned AURORA_IW = 4
) (
    input  logic clk,
    input  logic rst_n,
    input  logic irq,
    input  logic timer_irq,
    input  logic ipi,

    output logic [AURORA_IW-1:0]   m_axi_awid,
    output logic [AURORA_AW-1:0]   m_axi_awaddr,
    output logic [7:0]             m_axi_awlen,
    output logic [2:0]             m_axi_awsize,
    output logic [1:0]             m_axi_awburst,
    output logic                   m_axi_awvalid,
    input  logic                   m_axi_awready,

    output logic [AURORA_DW-1:0]   m_axi_wdata,
    output logic [AURORA_DW/8-1:0] m_axi_wstrb,
    output logic                   m_axi_wlast,
    output logic                   m_axi_wvalid,
    input  logic                   m_axi_wready,

    input  logic [AURORA_IW-1:0]   m_axi_bid,
    input  logic [1:0]             m_axi_bresp,
    input  logic                   m_axi_bvalid,
    output logic                   m_axi_bready,

    output logic [AURORA_IW-1:0]   m_axi_arid,
    output logic [AURORA_AW-1:0]   m_axi_araddr,
    output logic [7:0]             m_axi_arlen,
    output logic [2:0]             m_axi_arsize,
    output logic [1:0]             m_axi_arburst,
    output logic                   m_axi_arvalid,
    input  logic                   m_axi_arready,

    input  logic [AURORA_IW-1:0]   m_axi_rid,
    input  logic [AURORA_DW-1:0]   m_axi_rdata,
    input  logic [1:0]             m_axi_rresp,
    input  logic                   m_axi_rlast,
    input  logic                   m_axi_rvalid,
    output logic                   m_axi_rready
);

// Synlig synth: build_config() is a package function Yosys can't evaluate at the
// top level. The i_cva6 instance below uses CVA6's own default config (the same
// cv64a6_imafdc_sv39), which Surelog resolves through the hierarchy. This wrapper
// only needs the AXI port widths, which are fixed for that config: 64/64/4/1.
localparam int unsigned CVA6_AW = 64;  // AxiAddrWidth (cv32a6_imac_sv32)
localparam int unsigned CVA6_DW = 64;  // AxiDataWidth
localparam int unsigned CVA6_IW = 4;   // AxiIdWidth
localparam int unsigned CVA6_UW = 32;  // AxiUserWidth (=XLEN for cv32a6)

// Exact mirror of ariane_axi::aw_chan_t
typedef struct packed {
    logic [CVA6_IW-1:0]  id;
    logic [CVA6_AW-1:0]  addr;
    logic [7:0]           len;
    logic [2:0]           size;
    logic [1:0]           burst;
    logic                 lock;
    logic [3:0]           cache;
    logic [2:0]           prot;
    logic [3:0]           qos;
    logic [3:0]           region;
    logic [5:0]           atop;
    logic [CVA6_UW-1:0]  user;
} aw_chan_t;

// Exact mirror of ariane_axi::w_chan_t
typedef struct packed {
    logic [CVA6_DW-1:0]    data;
    logic [CVA6_DW/8-1:0]  strb;
    logic                   last;
    logic [CVA6_UW-1:0]    user;
} w_chan_t;

// Exact mirror of ariane_axi::b_chan_t
typedef struct packed {
    logic [CVA6_IW-1:0]  id;
    logic [1:0]           resp;
    logic [CVA6_UW-1:0]  user;
} b_chan_t;

// Exact mirror of ariane_axi::ar_chan_t
typedef struct packed {
    logic [CVA6_IW-1:0]  id;
    logic [CVA6_AW-1:0]  addr;
    logic [7:0]           len;
    logic [2:0]           size;
    logic [1:0]           burst;
    logic                 lock;
    logic [3:0]           cache;
    logic [2:0]           prot;
    logic [3:0]           qos;
    logic [3:0]           region;
    logic [CVA6_UW-1:0]  user;
} ar_chan_t;

// Exact mirror of ariane_axi::r_chan_t
typedef struct packed {
    logic [CVA6_IW-1:0]  id;
    logic [CVA6_DW-1:0]  data;
    logic [1:0]           resp;
    logic                 last;
    logic [CVA6_UW-1:0]  user;
} r_chan_t;

// Exact mirror of ariane_axi::req_t
typedef struct packed {
    aw_chan_t  aw;
    logic      aw_valid;
    w_chan_t   w;
    logic      w_valid;
    logic      b_ready;
    ar_chan_t  ar;
    logic      ar_valid;
    logic      r_ready;
} noc_req_t;

// Exact mirror of ariane_axi::resp_t
// NOTE: b_valid and r_valid are FLAT fields alongside nested b/r structs
typedef struct packed {
    logic      aw_ready;
    logic      ar_ready;
    logic      w_ready;
    logic      b_valid;   // flat — used as axi_resp_i.b_valid
    b_chan_t   b;         // nested — used as axi_resp_i.b.id etc
    logic      r_valid;   // flat — used as axi_resp_i.r_valid
    r_chan_t   r;         // nested — used as axi_resp_i.r.data etc
} noc_resp_t;

noc_req_t  noc_req;
noc_resp_t noc_resp;

cva6 #(
    // Override with the Verilator-resolved constant config so Yosys never has to
    // evaluate build_config(). Overriding also suppresses cva6's default param.
    .CVA6Cfg    ( cva6_resolved_cfg_pkg::CVA6Cfg_RESOLVED ),
    .noc_req_t  ( noc_req_t  ),
    .noc_resp_t ( noc_resp_t )
) i_cva6 (
    .clk_i         ( clk          ),
    .rst_ni        ( rst_n        ),
    .boot_addr_i   ( BOOT_ADDR    ),
    .hart_id_i     ( HART_ID      ),
    .irq_i         ( {irq, 1'b0}  ),
    .ipi_i         ( ipi          ),
    .time_irq_i    ( timer_irq    ),
    .debug_req_i   ( 1'b0         ),
    .rvfi_probes_o (              ),
    .cvxif_req_o   (              ),
    .cvxif_resp_i  ( '0           ),
    .noc_req_o     ( noc_req      ),
    .noc_resp_i    ( noc_resp     )
);

// ------------------------------------------------------------------
// Transaction tracking.
// The Aurora crossbar carries no ID signals and allows exactly one
// outstanding transaction per master per direction, so the ID of the
// single in-flight AW/AR is latched here and reflected on B/R. CVA6's
// cache subsystem demuxes responses by ID (icache=0, bypass=1xxx,
// dcache=0111) — without this, every response routes to the icache
// adapter and the core deadlocks on its first data access.
// addr[3] is latched too: CVA6 drives a 64-bit beat that must land on
// the addressed half of the 128-bit fabric bus.
// ------------------------------------------------------------------
logic               wr_lane_q, rd_lane_q;
logic [CVA6_IW-1:0] wr_id_q,   rd_id_q;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_lane_q <= 1'b0;
        rd_lane_q <= 1'b0;
        wr_id_q   <= '0;
        rd_id_q   <= '0;
    end else begin
        if (noc_req.aw_valid && m_axi_awready) begin
            wr_lane_q <= noc_req.aw.addr[3];
            wr_id_q   <= noc_req.aw.id;
        end
        if (noc_req.ar_valid && m_axi_arready) begin
            rd_lane_q <= noc_req.ar.addr[3];
            rd_id_q   <= noc_req.ar.id;
        end
    end
end

// W may handshake in the same cycle as AW (use live addr) or later
// (use the latched lane).
logic wr_lane;
assign wr_lane = noc_req.aw_valid ? noc_req.aw.addr[3] : wr_lane_q;

// CVA6 → Aurora
assign m_axi_awid    = noc_req.aw.id[AURORA_IW-1:0];
assign m_axi_awaddr  = noc_req.aw.addr[AURORA_AW-1:0];
assign m_axi_awlen   = noc_req.aw.len;
assign m_axi_awsize  = noc_req.aw.size;
assign m_axi_awburst = noc_req.aw.burst;
assign m_axi_awvalid = noc_req.aw_valid;

assign m_axi_wdata   = wr_lane ? {noc_req.w.data, {CVA6_DW{1'b0}}}
                               : {{CVA6_DW{1'b0}}, noc_req.w.data};
assign m_axi_wstrb   = wr_lane ? {noc_req.w.strb, {(CVA6_DW/8){1'b0}}}
                               : {{(CVA6_DW/8){1'b0}}, noc_req.w.strb};
assign m_axi_wlast   = noc_req.w.last;
assign m_axi_wvalid  = noc_req.w_valid;
assign m_axi_bready  = noc_req.b_ready;

assign m_axi_arid    = noc_req.ar.id[AURORA_IW-1:0];
assign m_axi_araddr  = noc_req.ar.addr[AURORA_AW-1:0];
assign m_axi_arlen   = noc_req.ar.len;
assign m_axi_arsize  = noc_req.ar.size;
assign m_axi_arburst = noc_req.ar.burst;
assign m_axi_arvalid = noc_req.ar_valid;
assign m_axi_rready  = noc_req.r_ready;

// Aurora → CVA6
assign noc_resp.aw_ready = m_axi_awready;
assign noc_resp.ar_ready = m_axi_arready;
assign noc_resp.w_ready  = m_axi_wready;

assign noc_resp.b_valid  = m_axi_bvalid;
assign noc_resp.b.id     = wr_id_q;     // reflected — fabric carries no IDs
assign noc_resp.b.resp   = m_axi_bresp;
assign noc_resp.b.user   = '0;

assign noc_resp.r_valid  = m_axi_rvalid;
assign noc_resp.r.id     = rd_id_q;     // reflected — fabric carries no IDs
assign noc_resp.r.data   = rd_lane_q ? m_axi_rdata[AURORA_DW-1:CVA6_DW]
                                     : m_axi_rdata[CVA6_DW-1:0];
assign noc_resp.r.resp   = m_axi_rresp;
assign noc_resp.r.last   = m_axi_rlast;
assign noc_resp.r.user   = '0;

endmodule
