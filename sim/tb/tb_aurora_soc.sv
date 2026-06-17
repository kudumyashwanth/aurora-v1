`timescale 1ns/1ps

/* verilator lint_off PINMISSING */
/* verilator lint_off WIDTH */
/* verilator lint_off CASEINCOMPLETE */
/* verilator lint_off UNUSED */

// Aurora v1 - Verilator-Compatible Testbench
// Simple C++-driven testbench that works with Verilator

module tb_aurora_soc (
    input logic clk,
    input logic rst_n
);

////////////////////////////////////////////////////
// PHYSICAL I/O SIGNALS
////////////////////////////////////////////////////

logic uart_rxd;
logic uart_txd;
logic [31:0] gpio_in;
logic [31:0] gpio_out;
logic [31:0] gpio_oe;
logic timer_pwm;
logic global_irq;

////////////////////////////////////////////////////
// DUT INSTANTIATION
////////////////////////////////////////////////////

aurora_soc_top dut (
    .clk(clk),
    .rst_n(rst_n),
    .uart_rxd(uart_rxd),
    .uart_txd(uart_txd),
    .gpio_in(gpio_in),
    .gpio_out(gpio_out),
    .gpio_oe(gpio_oe),
    .timer_pwm(timer_pwm),
    .global_irq(global_irq)
);

////////////////////////////////////////////////////
// STIMULUS
////////////////////////////////////////////////////

// UART RX idle high
assign uart_rxd = 1'b1;

// GPIO input pattern
assign gpio_in = 32'hAAAA_5555;

////////////////////////////////////////////////////
// MONITORING
////////////////////////////////////////////////////

// Track previous values for edge detection
logic uart_txd_prev;
logic [31:0] gpio_out_prev;
logic timer_pwm_prev;

always @(posedge clk) begin
    if (rst_n) begin
        uart_txd_prev <= uart_txd;
        gpio_out_prev <= gpio_out;
        timer_pwm_prev <= timer_pwm;
        
        // Detect GPIO changes
        if (gpio_out !== gpio_out_prev) begin
            $display("[%0t] GPIO Out: 0x%08h", $time, gpio_out);
        end
        
        // Detect PWM changes
        if (timer_pwm !== timer_pwm_prev) begin
            $display("[%0t] Timer PWM: %b", $time, timer_pwm);
        end
        
        // Detect interrupts
        if (global_irq) begin
            $display("[%0t] ⚡ INTERRUPT!", $time);
        end
    end
end

////////////////////////////////////////////////////
// SIMPLE STATUS OUTPUT
////////////////////////////////////////////////////

integer cycle_count;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        cycle_count <= 0;
    else
        cycle_count <= cycle_count + 1;
end

// Print periodic status
always @(posedge clk) begin
    if (rst_n && (cycle_count % 500000 == 0)) begin
        $display("[Cycle %0d] Aurora running...", cycle_count);
    end
end

////////////////////////////////////////////////////
// UART TX DECODER (115200 baud @ 200 MHz fabric clk)
////////////////////////////////////////////////////

localparam int UART_DIV = 200_000_000 / 115200;  // cycles per bit

integer  bit_cnt;
integer  baud_cnt;
logic [7:0] rx_shift;
logic    rx_active;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_active <= 1'b0;
        bit_cnt   <= 0;
        baud_cnt  <= 0;
        rx_shift  <= '0;
    end else if (!rx_active) begin
        if (uart_txd_prev && !uart_txd) begin   // start bit edge
            rx_active <= 1'b1;
            baud_cnt  <= UART_DIV + UART_DIV/2; // sample mid bit-0
            bit_cnt   <= 0;
        end
    end else begin
        if (baud_cnt == 0) begin
            rx_shift <= {uart_txd, rx_shift[7:1]};  // LSB first
            baud_cnt <= UART_DIV;
            if (bit_cnt == 7) begin
                rx_active <= 1'b0;
                $write("%c", {uart_txd, rx_shift[7:1]});
                $fflush;
            end else
                bit_cnt <= bit_cnt + 1;
        end else
            baud_cnt <= baud_cnt - 1;
    end
end

endmodule
