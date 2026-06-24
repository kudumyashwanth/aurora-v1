`timescale 1ns/1ps
/* verilator lint_off WIDTH */
/* verilator lint_off UNUSED */

// Simple burst-capable AXI4 RAM BFM (INCR bursts, 1 outstanding read + 1 write).
// 64-bit data, byte-strobed writes, 1-cycle-ish handshake. For sim only.
// Address indexes a word array by (addr - BASE) >> 3, masked to DEPTH.
module axi4_ram_bfm #(
    parameter ADDR_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter DEPTH      = 1<<20,   // 64-bit words
    parameter [63:0] BASE = 0,
    parameter INIT_HEX   = ""       // optional $readmemh file (64-bit words from BASE)
) (
    input  logic clk, rst_n,
    // AW
    input  logic [ID_WIDTH-1:0]   awid,  input logic [ADDR_WIDTH-1:0] awaddr,
    input  logic [7:0]            awlen, input logic [2:0] awsize, input logic [1:0] awburst,
    input  logic                  awvalid, output logic awready,
    // W
    input  logic [63:0]           wdata, input logic [7:0] wstrb, input logic wlast,
    input  logic                  wvalid, output logic wready,
    // B
    output logic [ID_WIDTH-1:0]   bid, output logic [1:0] bresp, output logic bvalid, input logic bready,
    // AR
    input  logic [ID_WIDTH-1:0]   arid, input logic [ADDR_WIDTH-1:0] araddr,
    input  logic [7:0]            arlen, input logic [2:0] arsize, input logic [1:0] arburst,
    input  logic                  arvalid, output logic arready,
    // R
    output logic [ID_WIDTH-1:0]   rid, output logic [63:0] rdata, output logic [1:0] rresp,
    output logic                  rlast, output logic rvalid, input logic rready,
    // sideband: write observation (for UART capture)
    output logic                  wr_fire, output logic [ADDR_WIDTH-1:0] wr_addr, output logic [63:0] wr_data
);
    logic [63:0] mem [0:DEPTH-1];
    initial if (INIT_HEX != "") $readmemh(INIT_HEX, mem);

    function automatic logic [31:0] idx(logic [ADDR_WIDTH-1:0] a);
        idx = (a - BASE[ADDR_WIDTH-1:0]) >> 3;
    endfunction

    // ---- READ ----
    typedef enum logic [1:0] {R_IDLE, R_DATA} rs_t; rs_t rs;
    logic [ADDR_WIDTH-1:0] r_addr; logic [7:0] r_cnt; logic [ID_WIDTH-1:0] r_id;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin rs<=R_IDLE; r_cnt<=0; r_addr<=0; r_id<=0; end
        else case (rs)
            R_IDLE: if (arvalid) begin r_addr<=araddr; r_cnt<=arlen; r_id<=arid; rs<=R_DATA; end
            R_DATA: if (rready) begin
                if (r_cnt==0) rs<=R_IDLE;
                else begin r_cnt<=r_cnt-1; r_addr<=r_addr+8; end
            end
        endcase
    end
    assign arready = (rs==R_IDLE);
    assign rvalid  = (rs==R_DATA);
    assign rid     = r_id;
    assign rdata   = mem[idx(r_addr) & (DEPTH-1)];
    assign rresp   = 2'b00;
    assign rlast   = (r_cnt==0);

    // ---- WRITE ----
    typedef enum logic [1:0] {W_AW, W_DATA, W_RESP} ws_t; ws_t ws;
    logic [ADDR_WIDTH-1:0] w_addr; logic [ID_WIDTH-1:0] w_id;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin ws<=W_AW; w_addr<=0; w_id<=0; end
        else case (ws)
            W_AW: if (awvalid) begin w_addr<=awaddr; w_id<=awid; ws<=W_DATA; end
            W_DATA: if (wvalid) begin
                for (int b=0;b<8;b++) if (wstrb[b]) mem[idx(w_addr) & (DEPTH-1)][b*8+:8] <= wdata[b*8+:8];
                w_addr <= w_addr + 8;
                if (wlast) ws<=W_RESP;
            end
            W_RESP: if (bready) ws<=W_AW;
        endcase
    end
    assign awready = (ws==W_AW);
    assign wready  = (ws==W_DATA);
    assign bvalid  = (ws==W_RESP);
    assign bid     = w_id;
    assign bresp   = 2'b00;

    assign wr_fire = (ws==W_DATA) && wvalid;
    assign wr_addr = w_addr;
    assign wr_data = wdata;
endmodule
