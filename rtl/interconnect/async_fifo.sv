`timescale 1ns/1ps
module async_fifo #(
    parameter DATA_WIDTH = 128,
    parameter ADDR_WIDTH = 4
)(
    input  logic wr_clk,
    input  logic wr_rst_n,
    input  logic wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic wr_full,

    input  logic rd_clk,
    input  logic rd_rst_n,
    input  logic rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic rd_empty
);

localparam DEPTH = 1 << ADDR_WIDTH;

logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

logic [ADDR_WIDTH:0] wr_ptr;
logic [ADDR_WIDTH:0] rd_ptr;

logic [ADDR_WIDTH:0] wr_ptr_sync1, wr_ptr_sync2;
logic [ADDR_WIDTH:0] rd_ptr_sync1, rd_ptr_sync2;

////////////////////////////////////////
// Write logic
////////////////////////////////////////

always_ff @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n)
        wr_ptr <= 0;
    else if (wr_en && !wr_full) begin
        mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
        wr_ptr <= wr_ptr + 1;
    end
end

////////////////////////////////////////
// Read logic
////////////////////////////////////////

always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n)
        rd_ptr <= 0;
    else if (rd_en && !rd_empty)
        rd_ptr <= rd_ptr + 1;
end

assign rd_data = mem[rd_ptr[ADDR_WIDTH-1:0]];

////////////////////////////////////////
// Pointer synchronization
////////////////////////////////////////

always_ff @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
        rd_ptr_sync1 <= 0;
        rd_ptr_sync2 <= 0;
    end else begin
        rd_ptr_sync1 <= rd_ptr;
        rd_ptr_sync2 <= rd_ptr_sync1;
    end
end

always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
        wr_ptr_sync1 <= 0;
        wr_ptr_sync2 <= 0;
    end else begin
        wr_ptr_sync1 <= wr_ptr;
        wr_ptr_sync2 <= wr_ptr_sync1;
    end
end

////////////////////////////////////////
// Status logic
////////////////////////////////////////

assign wr_full  = (wr_ptr[ADDR_WIDTH]    != rd_ptr_sync2[ADDR_WIDTH]) &&
                  (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr_sync2[ADDR_WIDTH-1:0]);

assign rd_empty = (rd_ptr == wr_ptr_sync2);

endmodule
