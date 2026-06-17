`timescale 1ns/1ps

// Aurora v1 - Tensor Core Local Buffer (HARDENED / SRAM-macro version)
//
// Synthesis-time replacement for rtl/tensor_cluster/tensor_local_buffer.sv.
// Same module name and port list -> drop-in for the synth filelist.
//
// 512 x 128-bit = 8 KB, built from 4x sky130_sram_2kbyte_1rw1r_32x512_8
// (each 512 x 32-bit). Port A (DMA write / read) -> the macro 1rw port;
// Port B (tensor read-only) -> the macro 1r port. Both ports are registered
// with 1-cycle read latency, matching the behavioral model the loader FSM
// was designed against.
//
// Demo-size note: the behavioral buffer is 4096-deep (64 KB), but the tensor
// matmul only ever touches entries 0-3, so 512-deep is functionally identical
// here and routable as 4 real macros instead of ~256k flops. BUFFER_DEPTH is
// kept as a parameter; re-tiling to full depth later is a macro-count change.

module tensor_local_buffer
#(
    parameter DATA_WIDTH   = 128,
    parameter ADDR_WIDTH   = 16,
    parameter BUFFER_DEPTH = 512   // 512 x 128-bit = 8 KB (4 macros wide, 1 deep)
)
(
    input  logic clk,
    input  logic rst_n,

    // Port A: DMA Write Interface (1rw)
    input  logic [ADDR_WIDTH-1:0]  porta_addr,
    input  logic                   porta_wr_en,
    input  logic [DATA_WIDTH-1:0]  porta_wr_data,
    output logic [DATA_WIDTH-1:0]  porta_rd_data,

    // Port B: Tensor Core Read Interface (1r)
    input  logic [ADDR_WIDTH-1:0]  portb_addr,
    input  logic                   portb_rd_en,
    output logic [DATA_WIDTH-1:0]  portb_rd_data
);

    localparam int MACRO_AW = 9;                 // sky130 macro: 512 deep
    localparam int N_MACRO  = DATA_WIDTH / 32;   // 128 / 32 = 4 macros wide

    // 128-bit word address: byte addr / 16, then index the 512-word depth.
    wire [MACRO_AW-1:0] porta_word_addr = porta_addr[MACRO_AW-1+4:4];
    wire [MACRO_AW-1:0] portb_word_addr = portb_addr[MACRO_AW-1+4:4];

    // Port A 1rw control: always selected; write when porta_wr_en, else read.
    wire        csb0 = 1'b0;             // active-low select (always on)
    wire        web0 = ~porta_wr_en;     // active-low write
    // Port B 1r control: selected only when reading.
    wire        csb1 = ~portb_rd_en;     // active-low select

    genvar m;
    generate
        for (m = 0; m < N_MACRO; m = m + 1) begin : g_bank
            sky130_sram_2kbyte_1rw1r_32x512_8 u_sram (
                .clk0  (clk),
                .csb0  (csb0),
                .web0  (web0),
                .wmask0(4'b1111),                       // full 32-bit word write
                .addr0 (porta_word_addr),
                .din0  (porta_wr_data[m*32 +: 32]),
                .dout0 (porta_rd_data[m*32 +: 32]),
                .clk1  (clk),
                .csb1  (csb1),
                .addr1 (portb_word_addr),
                .dout1 (portb_rd_data[m*32 +: 32])
            );
        end
    endgenerate

endmodule
