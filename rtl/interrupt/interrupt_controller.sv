`timescale 1ns/1ps
module interrupt_controller
#(
    parameter NUM_IRQ = 16
)
(
    input  logic clk,
    input  logic rst_n,

    input  logic [NUM_IRQ-1:0] irq_sources,

    input  logic clear,

    output logic irq_out
);

////////////////////////////////////////////////////
// IRQ REGISTER
////////////////////////////////////////////////////

logic [NUM_IRQ-1:0] irq_pending;

always_ff @(posedge clk or negedge rst_n)
begin

    if (!rst_n)
        irq_pending <= '0;

    else
    begin

        irq_pending <= irq_pending | irq_sources;

        if (clear)
            irq_pending <= '0;

    end

end

////////////////////////////////////////////////////
// IRQ OUTPUT
////////////////////////////////////////////////////

assign irq_out = |irq_pending;

endmodule
