`timescale 1ns/1ps
module mac_unit
#(
    parameter DATA_WIDTH = 16
)
(
    input  logic clk,
    input  logic rst_n,

    input  logic [DATA_WIDTH-1:0] a,
    input  logic [DATA_WIDTH-1:0] b,

    input  logic valid_in,

    output logic [31:0] result,
    output logic valid_out
);

logic [31:0] acc;

always_ff @(posedge clk or negedge rst_n)
begin

    if (!rst_n)
    begin
        acc <= 0;
        valid_out <= 0;
    end

    else if (valid_in)
    begin
        acc <= acc + (a * b);
        valid_out <= 1;
    end

    else
        valid_out <= 0;

end

assign result = acc;

endmodule
