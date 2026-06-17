`timescale 1ns/1ps

module clock_reset_controller
#(
    parameter SYNC_STAGES = 2
)
(
    // Input clocks (from external source or PLL)
    input  logic clk_in,
    input  logic rst_in_n,

    // CPU clock domain (100 MHz)
    output logic cpu_clk,
    output logic cpu_rst_n,

    // Fabric clock domain (200 MHz)
    output logic fabric_clk,
    output logic fabric_rst_n
);

////////////////////////////////////////////////////
// CLOCK GENERATION
////////////////////////////////////////////////////

// In real chip, clocks would come from PLL
// For now, pass through input clock
// (Testbench will provide appropriate clocks)

assign cpu_clk    = clk_in;    // In real design: PLL output / 2
assign fabric_clk = clk_in;    // In real design: PLL output

////////////////////////////////////////////////////
// RESET SYNCHRONIZATION
////////////////////////////////////////////////////

// CPU domain reset synchronizer
logic [SYNC_STAGES-1:0] cpu_rst_sync;

always_ff @(posedge cpu_clk or negedge rst_in_n) begin
    if (!rst_in_n)
        cpu_rst_sync <= '0;
    else
        cpu_rst_sync <= {cpu_rst_sync[SYNC_STAGES-2:0], 1'b1};
end

assign cpu_rst_n = cpu_rst_sync[SYNC_STAGES-1];

// Fabric domain reset synchronizer
logic [SYNC_STAGES-1:0] fabric_rst_sync;

always_ff @(posedge fabric_clk or negedge rst_in_n) begin
    if (!rst_in_n)
        fabric_rst_sync <= '0;
    else
        fabric_rst_sync <= {fabric_rst_sync[SYNC_STAGES-2:0], 1'b1};
end

assign fabric_rst_n = fabric_rst_sync[SYNC_STAGES-1];

endmodule
