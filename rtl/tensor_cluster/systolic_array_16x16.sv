`timescale 1ns/1ps

module systolic_array_16x16
#(
    parameter DATA_WIDTH = 16,
    parameter SIZE = 16
)
(
    input  logic clk,
    input  logic rst_n,
    input  logic start,

    // CORRECTED: Packed arrays to match tensor_core interface
    input  logic [SIZE-1:0][DATA_WIDTH-1:0] a_matrix,  // [15:0][15:0]
    input  logic [SIZE-1:0][DATA_WIDTH-1:0] b_matrix,  // [15:0][15:0]

    // CORRECTED: Output is 32-bit results (from MAC accumulation)
    output logic [SIZE-1:0][SIZE-1:0][31:0] result,    // [15:0][15:0][31:0]
    output logic done
);

// MAC outputs - 32-bit accumulated results
logic [31:0] mac_out [0:SIZE-1][0:SIZE-1];

// Valid signals for systolic dataflow
logic valid [0:SIZE-1][0:SIZE-1];

genvar i, j;

generate
    for(i = 0; i < SIZE; i++) begin : ROW
        for(j = 0; j < SIZE; j++) begin : COL
            
            // Instantiate MAC unit
            mac_unit #(
                .DATA_WIDTH(DATA_WIDTH)
            ) mac_inst (
                .clk(clk),
                .rst_n(rst_n),
                .a(a_matrix[i]),
                .b(b_matrix[j]),
                .valid_in(start),              // Simplified: all start together
                .result(mac_out[i][j]),
                .valid_out(valid[i][j])
            );
            
            // Assign MAC output to result
            assign result[i][j] = mac_out[i][j];
        end
    end
endgenerate

// Done when computation starts (simplified - real version would track completion)
assign done = start;

endmodule
