`timescale 1ns/1ps

// Aurora v1 - Tensor Core Local Buffer
// 64KB dual-port SRAM per tensor core
// Supports double buffering for compute/load overlap

module tensor_local_buffer
#(
    parameter DATA_WIDTH = 128,
    parameter ADDR_WIDTH = 16,      // 64KB = 2^16 bytes
    parameter BUFFER_DEPTH = 4096   // 4096 x 128-bit = 64KB
)
(
    input  logic clk,
    input  logic rst_n,

    // ========================================
    // Port A: DMA Write Interface
    // ========================================
    input  logic [ADDR_WIDTH-1:0]  porta_addr,
    input  logic                   porta_wr_en,
    input  logic [DATA_WIDTH-1:0]  porta_wr_data,
    output logic [DATA_WIDTH-1:0]  porta_rd_data,

    // ========================================
    // Port B: Tensor Core Read Interface
    // ========================================
    input  logic [ADDR_WIDTH-1:0]  portb_addr,
    input  logic                   portb_rd_en,
    output logic [DATA_WIDTH-1:0]  portb_rd_data
);

////////////////////////////////////////////////////
// DUAL-PORT SRAM
////////////////////////////////////////////////////

logic [DATA_WIDTH-1:0] mem [0:BUFFER_DEPTH-1];

// Calculate word address (128-bit aligned)
logic [13:0] porta_word_addr;
logic [13:0] portb_word_addr;

assign porta_word_addr = porta_addr[15:4];  // Divide by 16 for 128-bit words
assign portb_word_addr = portb_addr[15:4];

////////////////////////////////////////////////////
// PORT A: Read/Write
////////////////////////////////////////////////////

always_ff @(posedge clk) begin
    if (porta_wr_en) begin
        mem[porta_word_addr] <= porta_wr_data;
    end
    porta_rd_data <= mem[porta_word_addr];
end

////////////////////////////////////////////////////
// PORT B: Read-Only
////////////////////////////////////////////////////

always_ff @(posedge clk) begin
    if (portb_rd_en) begin
        portb_rd_data <= mem[portb_word_addr];
    end
end

endmodule
