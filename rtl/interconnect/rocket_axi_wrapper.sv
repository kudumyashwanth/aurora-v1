// rocket_axi_wrapper.sv — Aurora v1
// Adapts the hardened Rocket-AXI4 macro's memory master (RocketAXITileTop.mem_axi4_0_*,
// 64-bit data, 32-bit addr, 4-bit id, SINGLE-BEAT — bursts already fragmented away in the
// Chisel wrapper) onto the Aurora 128-bit single-beat fabric, exactly like cva6_axi_wrapper:
//   * the 64-bit beat is placed on the addr[3] half of the 128-bit bus;
//   * the single in-flight AW/AR id is latched and reflected on B/R, because the fabric
//     (axi_crossbar) carries no IDs and Rocket demuxes responses by id.
// The fabric's "one outstanding txn per master per direction" rule is enforced downstream
// by the crossbar's awready/arready backpressure, so only one id is ever in flight here.
//
// This is a pure protocol adapter (no clock logic): it sits in the CPU clock domain between
// the Rocket macro and the axi_cdc_bridge that crosses 33MHz -> 50MHz.

`timescale 1ns/1ps

module rocket_axi_wrapper #(
    parameter int unsigned AURORA_AW = 32,
    parameter int unsigned AURORA_DW = 128,
    parameter int unsigned AURORA_IW = 4,
    parameter int unsigned ROCKET_DW = 64
) (
    // ---- Rocket macro AXI4 master side (this module is the slave) ----
    input  logic [AURORA_IW-1:0]    r_awid,
    input  logic [AURORA_AW-1:0]    r_awaddr,
    input  logic                    r_awvalid,
    output logic                    r_awready,

    input  logic [ROCKET_DW-1:0]    r_wdata,
    input  logic [ROCKET_DW/8-1:0]  r_wstrb,
    input  logic                    r_wvalid,
    output logic                    r_wready,

    output logic [AURORA_IW-1:0]    r_bid,
    output logic [1:0]              r_bresp,
    output logic                    r_bvalid,
    input  logic                    r_bready,

    input  logic [AURORA_IW-1:0]    r_arid,
    input  logic [AURORA_AW-1:0]    r_araddr,
    input  logic                    r_arvalid,
    output logic                    r_arready,

    output logic [AURORA_IW-1:0]    r_rid,
    output logic [ROCKET_DW-1:0]    r_rdata,
    output logic [1:0]              r_rresp,
    output logic                    r_rlast,
    output logic                    r_rvalid,
    input  logic                    r_rready,

    input  logic                    clk,
    input  logic                    rst_n,

    // ---- Aurora 128-bit fabric side (this module is the master, feeds axi_cdc_bridge) ----
    output logic [AURORA_IW-1:0]    f_awid,
    output logic [AURORA_AW-1:0]    f_awaddr,
    output logic                    f_awvalid,
    input  logic                    f_awready,

    output logic [AURORA_DW-1:0]    f_wdata,
    output logic [AURORA_DW/8-1:0]  f_wstrb,
    output logic                    f_wvalid,
    input  logic                    f_wready,

    input  logic [AURORA_IW-1:0]    f_bid,
    input  logic                    f_bvalid,
    output logic                    f_bready,

    output logic [AURORA_IW-1:0]    f_arid,
    output logic [AURORA_AW-1:0]    f_araddr,
    output logic                    f_arvalid,
    input  logic                    f_arready,

    input  logic [AURORA_IW-1:0]    f_rid,
    input  logic [AURORA_DW-1:0]    f_rdata,
    input  logic                    f_rvalid,
    output logic                    f_rready
);

    // Per-transaction lane/id tracking (NO backpressure to the macro).
    //
    // The fabric crossbar drops AXI IDs and returns only 128-bit data, so for each returning
    // R/B beat we must recover the originating transaction's id and 64-bit lane (addr[3], which
    // half of the 128-bit bus it lives on). A single latch is WRONG: the downstream
    // axi_cdc_bridge buffers several requests in its depth-16 async FIFOs, so the macro can have
    // many AR/AW in flight at once. Worse, gating AR/AW ready to force 1-outstanding deadlocks
    // Rocket's TLToAXI4 — it drives the independent AW and W channels in a pairing that an
    // AW-ready that waits on B completion desynchronises (it withholds a W).
    //
    // Instead: small in-order FIFOs, one slot per outstanding txn, written at request and read
    // at response. AXI keeps same-id responses in order and the single-slave-at-a-time fabric
    // returns reads/writes in issue order, so the FIFO head always matches the current response.
    // Depth 32 > max possible in flight (axi_cdc_bridge FIFO depth 16 + 1 at the crossbar, per
    // direction) so it never overflows and never needs to backpressure the macro.
    localparam int unsigned TD  = 32;
    localparam int unsigned TPW = 5;   // $clog2(TD)

    // read tracker: {lane, id} pushed at AR handshake, popped at R handshake
    logic [TPW-1:0]        rd_wp, rd_rp;
    logic [AURORA_IW:0]    rd_mem [0:TD-1];   // {lane, id}
    // write trackers: lane (popped at W) and id (popped at B), both pushed at AW handshake
    logic [TPW-1:0]        wl_wp, wl_rp, wi_rp;
    logic                  wl_mem [0:TD-1];
    logic [AURORA_IW-1:0]  wi_mem [0:TD-1];

    wire ar_fire = r_arvalid && r_arready;
    wire r_fire  = r_rvalid  && r_rready;   // single beat -> one R per AR
    wire aw_fire = r_awvalid && r_awready;
    wire w_fire  = r_wvalid  && r_wready;   // single beat -> one W per AW
    wire b_fire  = r_bvalid  && r_bready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_wp <= '0; rd_rp <= '0;
            wl_wp <= '0; wl_rp <= '0; wi_rp <= '0;
        end else begin
            if (ar_fire) begin rd_mem[rd_wp] <= {r_araddr[3], r_arid}; rd_wp <= rd_wp + 1'b1; end
            if (r_fire)  rd_rp <= rd_rp + 1'b1;
            if (aw_fire) begin
                wl_mem[wl_wp] <= r_awaddr[3];
                wi_mem[wl_wp] <= r_awid;
                wl_wp <= wl_wp + 1'b1;
            end
            if (w_fire) wl_rp <= wl_rp + 1'b1;
            if (b_fire) wi_rp <= wi_rp + 1'b1;
        end
    end

    // FWFT heads (valid whenever a response/W is in flight, which only happens after its request)
    wire                 rd_lane_h = rd_mem[rd_rp][AURORA_IW];
    wire [AURORA_IW-1:0] rd_id_h   = rd_mem[rd_rp][AURORA_IW-1:0];
    // W lane: if AW and W handshake the same cycle with an empty queue, use the live addr[3].
    wire                 wl_empty  = (wl_wp == wl_rp);
    wire                 wr_lane   = (wl_empty && aw_fire) ? r_awaddr[3] : wl_mem[wl_rp];

    // ---- Rocket -> fabric (AW/AR/W) : free flow, no gating ----
    assign f_awid    = r_awid;
    assign f_awaddr  = r_awaddr;
    assign f_awvalid = r_awvalid;
    assign r_awready = f_awready;

    assign f_wdata   = wr_lane ? {r_wdata, {ROCKET_DW{1'b0}}}
                               : {{ROCKET_DW{1'b0}}, r_wdata};
    assign f_wstrb   = wr_lane ? {r_wstrb, {(ROCKET_DW/8){1'b0}}}
                               : {{(ROCKET_DW/8){1'b0}}, r_wstrb};
    assign f_wvalid  = r_wvalid;
    assign r_wready  = f_wready;

    assign f_arid    = r_arid;
    assign f_araddr  = r_araddr;
    assign f_arvalid = r_arvalid;
    assign r_arready = f_arready;

    assign f_bready  = r_bready;
    assign f_rready  = r_rready;

    // ---- Fabric -> Rocket (B/R) ----
    assign r_bvalid  = f_bvalid;
    assign r_bid     = wi_mem[wi_rp];   // reflected per-txn (fabric carries no IDs)
    assign r_bresp   = 2'b00;           // crossbar gives no resp; OKAY

    assign r_rvalid  = f_rvalid;
    assign r_rid     = rd_id_h;         // reflected per-txn
    assign r_rdata   = rd_lane_h ? f_rdata[AURORA_DW-1:ROCKET_DW]
                                 : f_rdata[ROCKET_DW-1:0];
    assign r_rresp   = 2'b00;       // OKAY
    assign r_rlast   = 1'b1;        // single beat -> always last

endmodule
