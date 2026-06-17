`timescale 1ns/1ps

// Aurora v1 - GPIO Peripheral
// 32 programmable I/O pins
// Input/Output/Tri-state control per pin

module gpio
#(
    parameter NUM_PINS = 32
)
(
    input  logic clk,
    input  logic rst_n,

    // AXI4-Lite Slave Interface
    input  logic [31:0] s_axi_awaddr,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,
    
    input  logic [31:0] s_axi_wdata,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,
    
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,
    
    input  logic [31:0] s_axi_araddr,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,
    
    output logic [31:0] s_axi_rdata,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    // GPIO Physical Interface
    input  logic [NUM_PINS-1:0]  gpio_in,
    output logic [NUM_PINS-1:0]  gpio_out,
    output logic [NUM_PINS-1:0]  gpio_oe,   // Output enable
    
    // Interrupt
    output logic irq
);

////////////////////////////////////////////////////
// REGISTER MAP
////////////////////////////////////////////////////
localparam REG_DATA_OUT = 8'h00;  // Output data register
localparam REG_DATA_IN  = 8'h04;  // Input data register (read-only)
localparam REG_DIR      = 8'h08;  // Direction: 0=input, 1=output
localparam REG_INT_EN   = 8'h0C;  // Interrupt enable (per pin)
localparam REG_INT_MASK = 8'h10;  // Interrupt mask
localparam REG_INT_STAT = 8'h14;  // Interrupt status (write-1-clear)

////////////////////////////////////////////////////
// CONTROL REGISTERS
////////////////////////////////////////////////////

logic [NUM_PINS-1:0] data_out_reg;
logic [NUM_PINS-1:0] data_in_reg;
logic [NUM_PINS-1:0] dir_reg;
logic [NUM_PINS-1:0] int_en_reg;
logic [NUM_PINS-1:0] int_mask_reg;
logic [NUM_PINS-1:0] int_stat_reg;

////////////////////////////////////////////////////
// INPUT SYNCHRONIZER (Prevent metastability)
////////////////////////////////////////////////////

logic [NUM_PINS-1:0] gpio_in_sync1;
logic [NUM_PINS-1:0] gpio_in_sync2;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        gpio_in_sync1 <= '0;
        gpio_in_sync2 <= '0;
    end
    else begin
        gpio_in_sync1 <= gpio_in;
        gpio_in_sync2 <= gpio_in_sync1;
    end
end

always_ff @(posedge clk) begin
    data_in_reg <= gpio_in_sync2;
end

////////////////////////////////////////////////////
// OUTPUT LOGIC
////////////////////////////////////////////////////

assign gpio_out = data_out_reg;
assign gpio_oe = dir_reg;

////////////////////////////////////////////////////
// EDGE DETECTION FOR INTERRUPTS
////////////////////////////////////////////////////

logic [NUM_PINS-1:0] gpio_in_prev;
logic [NUM_PINS-1:0] rising_edge;
logic [NUM_PINS-1:0] falling_edge;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        gpio_in_prev <= '0;
    else
        gpio_in_prev <= gpio_in_sync2;
end

assign rising_edge = gpio_in_sync2 & ~gpio_in_prev;
assign falling_edge = ~gpio_in_sync2 & gpio_in_prev;

////////////////////////////////////////////////////
// REGISTER WRITE INTERFACE
////////////////////////////////////////////////////

assign s_axi_awready = 1'b1;
assign s_axi_wready = 1'b1;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_out_reg <= '0;
        dir_reg <= '0;
        int_en_reg <= '0;
        int_mask_reg <= '0;
    end
    else if (s_axi_awvalid && s_axi_wvalid) begin
        case (s_axi_awaddr[7:0])
            REG_DATA_OUT: data_out_reg <= s_axi_wdata[NUM_PINS-1:0];
            REG_DIR:      dir_reg <= s_axi_wdata[NUM_PINS-1:0];
            REG_INT_EN:   int_en_reg <= s_axi_wdata[NUM_PINS-1:0];
            REG_INT_MASK: int_mask_reg <= s_axi_wdata[NUM_PINS-1:0];
            // REG_INT_STAT W1C is handled exclusively in the interrupt always_ff below
            default: ;  // writes to unmapped offsets are ignored
        endcase
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        s_axi_bvalid <= 1'b0;
    else if (s_axi_awvalid && s_axi_wvalid)
        s_axi_bvalid <= 1'b1;
    else if (s_axi_bready)
        s_axi_bvalid <= 1'b0;
end

////////////////////////////////////////////////////
// REGISTER READ INTERFACE
////////////////////////////////////////////////////

assign s_axi_arready = 1'b1;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s_axi_rdata <= '0;
        s_axi_rvalid <= 1'b0;
    end
    else if (s_axi_arvalid) begin
        case (s_axi_araddr[7:0])
            REG_DATA_OUT: s_axi_rdata <= {{(32-NUM_PINS){1'b0}}, data_out_reg};
            REG_DATA_IN:  s_axi_rdata <= {{(32-NUM_PINS){1'b0}}, data_in_reg};
            REG_DIR:      s_axi_rdata <= {{(32-NUM_PINS){1'b0}}, dir_reg};
            REG_INT_EN:   s_axi_rdata <= {{(32-NUM_PINS){1'b0}}, int_en_reg};
            REG_INT_MASK: s_axi_rdata <= {{(32-NUM_PINS){1'b0}}, int_mask_reg};
            REG_INT_STAT: s_axi_rdata <= {{(32-NUM_PINS){1'b0}}, int_stat_reg};
            default:      s_axi_rdata <= 32'hDEADBEEF;
        endcase
        s_axi_rvalid <= 1'b1;
    end
    else if (s_axi_rready)
        s_axi_rvalid <= 1'b0;
end

////////////////////////////////////////////////////
// INTERRUPT GENERATION
////////////////////////////////////////////////////

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        int_stat_reg <= '0;
    else begin
        // Set interrupt on rising/falling edge
        int_stat_reg <= int_stat_reg | ((rising_edge | falling_edge) & int_en_reg);
        
        // Clear on write-1-clear
        if (s_axi_awvalid && s_axi_wvalid && (s_axi_awaddr[7:0] == REG_INT_STAT))
            int_stat_reg <= int_stat_reg & ~s_axi_wdata[NUM_PINS-1:0];
    end
end

assign irq = |(int_stat_reg & ~int_mask_reg);

endmodule
