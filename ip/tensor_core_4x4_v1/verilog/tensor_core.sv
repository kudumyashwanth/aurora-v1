`timescale 1ns/1ps

module tensor_core
#(
    parameter DATA_WIDTH = 16,
    parameter SIZE = 16
)
(
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    
    // 2D array inputs matching systolic_array
    input  logic [SIZE-1:0][DATA_WIDTH-1:0] a_matrix,
    input  logic [SIZE-1:0][DATA_WIDTH-1:0] b_matrix,
    
    output logic done,
    output logic [SIZE-1:0][SIZE-1:0][31:0] result
);

////////////////////////////////////////////////////
// CONTROL FSM
////////////////////////////////////////////////////

typedef enum logic [1:0] {
    IDLE     = 2'b00,
    COMPUTE  = 2'b01,
    COMPLETE = 2'b10
} state_t;

state_t state, next_state;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

always_comb begin
    next_state = state;  // Default
    
    case (state)
        IDLE: begin
            if (start)
                next_state = COMPUTE;
        end
        
        COMPUTE: begin
            next_state = COMPLETE;
        end
        
        COMPLETE: begin
            next_state = IDLE;
        end
        
        default: begin
            next_state = IDLE;
        end
    endcase
end

////////////////////////////////////////////////////
// SYSTOLIC ARRAY INSTANTIATION
////////////////////////////////////////////////////

logic valid_compute;
logic compute_done;

assign valid_compute = (state == COMPUTE);

systolic_array_16x16 #(
    .DATA_WIDTH(DATA_WIDTH),
    .SIZE(SIZE)
) array_inst (
    .clk(clk),
    .rst_n(rst_n),
    .start(valid_compute),
    .a_matrix(a_matrix),
    .b_matrix(b_matrix),
    .result(result),
    .done(compute_done)
);

////////////////////////////////////////////////////
// DONE SIGNAL
////////////////////////////////////////////////////

assign done = (state == COMPLETE);

endmodule
