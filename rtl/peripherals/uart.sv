`timescale 1ns/1ps

// Aurora v1 - UART Peripheral
// 115200 baud, 8N1, with TX/RX FIFOs
// AXI4-Lite register interface

module uart
#(
    parameter CLK_FREQ = 200_000_000,  // 200 MHz
    parameter BAUD_RATE = 115200
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

    // UART Physical Interface
    input  logic        uart_rxd,
    output logic        uart_txd,
    
    // Interrupt
    output logic        irq
);

////////////////////////////////////////////////////
// REGISTER MAP
////////////////////////////////////////////////////
localparam REG_DATA   = 8'h00;  // TX/RX data register
localparam REG_STATUS = 8'h04;  // Status register
localparam REG_CONTROL = 8'h08; // Control register
localparam REG_DIVISOR = 8'h0C; // Baud rate divisor

////////////////////////////////////////////////////
// BAUD RATE GENERATOR
////////////////////////////////////////////////////

localparam DIVISOR = CLK_FREQ / BAUD_RATE;

logic [15:0] baud_counter;
logic baud_tick;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        baud_counter <= '0;
        baud_tick <= 1'b0;
    end
    else begin
        if (baud_counter >= 16'(DIVISOR - 1)) begin
            baud_counter <= '0;
            baud_tick <= 1'b1;
        end
        else begin
            baud_counter <= baud_counter + 1;
            baud_tick <= 1'b0;
        end
    end
end

////////////////////////////////////////////////////
// TX FIFO (16 deep)
////////////////////////////////////////////////////

logic [7:0] tx_fifo [0:15];
logic [3:0] tx_wr_ptr, tx_rd_ptr;
logic [4:0] tx_count;
wire tx_full = (tx_count == 16);
wire tx_empty = (tx_count == 0);

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_wr_ptr <= '0;
        tx_rd_ptr <= '0;
        tx_count <= '0;
    end
    else begin
        // Write to FIFO
        if (s_axi_awvalid && s_axi_wvalid && (s_axi_awaddr[7:0] == REG_DATA) && !tx_full) begin
            tx_fifo[tx_wr_ptr] <= s_axi_wdata[7:0];
            tx_wr_ptr <= tx_wr_ptr + 1;
            tx_count <= tx_count + 1;
        end
        
        // Read from FIFO (by TX state machine)
        if (tx_pop && !tx_empty) begin
            tx_rd_ptr <= tx_rd_ptr + 1;
            tx_count <= tx_count - 1;
        end
        
        // Handle simultaneous read/write
        if ((s_axi_awvalid && s_axi_wvalid && (s_axi_awaddr[7:0] == REG_DATA) && !tx_full) &&
            (tx_pop && !tx_empty))
            tx_count <= tx_count;
    end
end

////////////////////////////////////////////////////
// RX FIFO (16 deep)
////////////////////////////////////////////////////

logic [7:0] rx_fifo [0:15];
logic [3:0] rx_wr_ptr, rx_rd_ptr;
logic [4:0] rx_count;
wire rx_full = (rx_count == 16);
wire rx_empty = (rx_count == 0);

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_wr_ptr <= '0;
        rx_rd_ptr <= '0;
        rx_count <= '0;
    end
    else begin
        // Write to FIFO (from RX state machine)
        if (rx_push && !rx_full) begin
            rx_fifo[rx_wr_ptr] <= rx_data;
            rx_wr_ptr <= rx_wr_ptr + 1;
            rx_count <= rx_count + 1;
        end
        
        // Read from FIFO (by software)
        if (s_axi_arvalid && (s_axi_araddr[7:0] == REG_DATA) && !rx_empty) begin
            rx_rd_ptr <= rx_rd_ptr + 1;
            rx_count <= rx_count - 1;
        end
        
        // Handle simultaneous read/write
        if ((rx_push && !rx_full) && 
            (s_axi_arvalid && (s_axi_araddr[7:0] == REG_DATA) && !rx_empty))
            rx_count <= rx_count;
    end
end

////////////////////////////////////////////////////
// UART TX STATE MACHINE
////////////////////////////////////////////////////

typedef enum logic [2:0] {
    TX_IDLE,
    TX_START,
    TX_DATA,
    TX_STOP
} tx_state_t;

tx_state_t tx_state;
logic [7:0] tx_shift_reg;
logic [2:0] tx_bit_count;
logic tx_pop;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_state <= TX_IDLE;
        uart_txd <= 1'b1;
        tx_shift_reg <= '0;
        tx_bit_count <= '0;
        tx_pop <= 1'b0;
    end
    else begin
        tx_pop <= 1'b0;
        
        case (tx_state)
            TX_IDLE: begin
                uart_txd <= 1'b1;
                if (!tx_empty) begin
                    tx_shift_reg <= tx_fifo[tx_rd_ptr];
                    tx_pop <= 1'b1;
                    tx_state <= TX_START;
                end
            end
            
            TX_START: begin
                if (baud_tick) begin
                    uart_txd <= 1'b0;  // Start bit
                    tx_bit_count <= '0;
                    tx_state <= TX_DATA;
                end
            end
            
            TX_DATA: begin
                if (baud_tick) begin
                    uart_txd <= tx_shift_reg[0];
                    tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
                    tx_bit_count <= tx_bit_count + 1;
                    
                    if (tx_bit_count == 7)
                        tx_state <= TX_STOP;
                end
            end
            
            TX_STOP: begin
                if (baud_tick) begin
                    uart_txd <= 1'b1;  // Stop bit
                    tx_state <= TX_IDLE;
                end
            end

            default: tx_state <= TX_IDLE;
        endcase
    end
end

////////////////////////////////////////////////////
// UART RX STATE MACHINE
////////////////////////////////////////////////////

typedef enum logic [2:0] {
    RX_IDLE,
    RX_START,
    RX_DATA,
    RX_STOP
} rx_state_t;

rx_state_t rx_state;
logic [7:0] rx_shift_reg;
logic [2:0] rx_bit_count;
logic [7:0] rx_data;
logic rx_push;

// RX synchronizer (prevent metastability)
logic [1:0] rxd_sync;
always_ff @(posedge clk) begin
    rxd_sync <= {rxd_sync[0], uart_rxd};
end
wire rxd = rxd_sync[1];

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_state <= RX_IDLE;
        rx_shift_reg <= '0;
        rx_bit_count <= '0;
        rx_push <= 1'b0;
        rx_data <= '0;
    end
    else begin
        rx_push <= 1'b0;
        
        case (rx_state)
            RX_IDLE: begin
                if (!rxd) begin  // Start bit detected
                    rx_state <= RX_START;
                end
            end
            
            RX_START: begin
                if (baud_tick) begin
                    if (!rxd) begin  // Validate start bit
                        rx_bit_count <= '0;
                        rx_state <= RX_DATA;
                    end
                    else
                        rx_state <= RX_IDLE;  // False start
                end
            end
            
            RX_DATA: begin
                if (baud_tick) begin
                    rx_shift_reg <= {rxd, rx_shift_reg[7:1]};
                    rx_bit_count <= rx_bit_count + 1;
                    
                    if (rx_bit_count == 7)
                        rx_state <= RX_STOP;
                end
            end
            
            RX_STOP: begin
                if (baud_tick) begin
                    if (rxd) begin  // Valid stop bit
                        rx_data <= rx_shift_reg;
                        rx_push <= 1'b1;
                    end
                    rx_state <= RX_IDLE;
                end
            end

            default: rx_state <= RX_IDLE;
        endcase
    end
end

////////////////////////////////////////////////////
// REGISTER INTERFACE
////////////////////////////////////////////////////

// Write
assign s_axi_awready = 1'b1;
assign s_axi_wready = 1'b1;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        s_axi_bvalid <= 1'b0;
    else if (s_axi_awvalid && s_axi_wvalid)
        s_axi_bvalid <= 1'b1;
    else if (s_axi_bready)
        s_axi_bvalid <= 1'b0;
end

// Read
assign s_axi_arready = 1'b1;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s_axi_rdata <= '0;
        s_axi_rvalid <= 1'b0;
    end
    else if (s_axi_arvalid) begin
        case (s_axi_araddr[7:0])
            REG_DATA:    s_axi_rdata <= {24'h0, rx_fifo[rx_rd_ptr]};
            REG_STATUS:  s_axi_rdata <= {26'h0, rx_full, rx_empty, tx_full, tx_empty, 2'b00};
            REG_CONTROL: s_axi_rdata <= 32'h0;
            REG_DIVISOR: s_axi_rdata <= DIVISOR;
            default:     s_axi_rdata <= 32'hDEADBEEF;
        endcase
        s_axi_rvalid <= 1'b1;
    end
    else if (s_axi_rready)
        s_axi_rvalid <= 1'b0;
end

// Interrupt when RX has data
assign irq = !rx_empty;

endmodule
