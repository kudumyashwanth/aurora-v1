`timescale 1ns/1ps
module sram_bank_array
#(
    parameter DATA_WIDTH = 128,
    parameter ADDR_WIDTH = 32,
    parameter NUM_BANKS  = 8,
    parameter BANK_DEPTH = 32768
)
(
    input logic clk,
    input logic rst_n,

    // WRITE ADDRESS
    input  logic [ADDR_WIDTH-1:0] awaddr,
    input  logic                  awvalid,
    output logic                  awready,

    // WRITE DATA
    input  logic [DATA_WIDTH-1:0]   wdata,
    input  logic [DATA_WIDTH/8-1:0] wstrb,
    input  logic                    wvalid,
    output logic                    wready,

    // WRITE RESPONSE
    output logic                  bvalid,
    input  logic                  bready,

    // READ ADDRESS
    input  logic [ADDR_WIDTH-1:0] araddr,
    input  logic                  arvalid,
    output logic                  arready,

    // READ DATA
    output logic [DATA_WIDTH-1:0] rdata,
    output logic                  rvalid,
    input  logic                  rready
);

////////////////////////////////////////////////////
// BANK MEMORY
////////////////////////////////////////////////////

logic [DATA_WIDTH-1:0] bank_mem [NUM_BANKS-1:0][BANK_DEPTH-1:0];

////////////////////////////////////////////////////
// ADDRESS DECODE
////////////////////////////////////////////////////

localparam int WORD_OFF = $clog2(DATA_WIDTH/8);                 // 16-byte word → 4
localparam int IDX_W    = $clog2(BANK_DEPTH);                   // word index bits
localparam int BANK_W   = (NUM_BANKS > 1) ? $clog2(NUM_BANKS) : 1;

logic [BANK_W-1:0] write_bank;
logic [BANK_W-1:0] read_bank;

logic [IDX_W-1:0]  write_index;
logic [IDX_W-1:0]  read_index;

// Byte address → 128-bit (16-byte) word. Slices scale with BANK_DEPTH/NUM_BANKS:
//   index = addr[WORD_OFF +: IDX_W], bank = addr[WORD_OFF+IDX_W +: BANK_W]
assign write_index = awaddr[WORD_OFF +: IDX_W];
assign read_index  = araddr[WORD_OFF +: IDX_W];

assign write_bank  = (NUM_BANKS > 1) ? awaddr[WORD_OFF+IDX_W +: BANK_W] : '0;
assign read_bank   = (NUM_BANKS > 1) ? araddr[WORD_OFF+IDX_W +: BANK_W] : '0;

////////////////////////////////////////////////////
// WRITE LOGIC
////////////////////////////////////////////////////

assign awready = 1'b1;
assign wready  = 1'b1;

always_ff @(posedge clk)
begin

    if (awvalid && wvalid)
    begin
        for (int b = 0; b < DATA_WIDTH/8; b++)
            if (wstrb[b])
                bank_mem[write_bank][write_index][8*b +: 8] <= wdata[8*b +: 8];
    end

end

////////////////////////////////////////////////////
// WRITE RESPONSE
////////////////////////////////////////////////////

logic bvalid_reg;

always_ff @(posedge clk or negedge rst_n)
begin

    if (!rst_n)
        bvalid_reg <= 0;

    else if (awvalid && wvalid)
        bvalid_reg <= 1;

    else if (bready)
        bvalid_reg <= 0;

end

assign bvalid = bvalid_reg;

////////////////////////////////////////////////////
// READ LOGIC
////////////////////////////////////////////////////

assign arready = 1'b1;

logic [DATA_WIDTH-1:0] rdata_reg;
logic rvalid_reg;

always_ff @(posedge clk or negedge rst_n)
begin

    if (!rst_n)
    begin
        rvalid_reg <= 0;
    end

    else if (arvalid)
    begin
        rdata_reg  <= bank_mem[read_bank][read_index];
        rvalid_reg <= 1;
    end

    else if (rready)
    begin
        rvalid_reg <= 0;
    end

end

assign rdata  = rdata_reg;
assign rvalid = rvalid_reg;

endmodule
