`timescale 1ns/1ps

/* verilator lint_off PINMISSING */
/* verilator lint_off WIDTH */
/* verilator lint_off CASEINCOMPLETE */
/* verilator lint_off UNUSED */
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */

// Aurora v1 - macro-based chip TB (aurora_soc_top_chip: Rocket macro + tensor macro).
// Drives clk/rst_n from C++; decodes UART TX to stdout. UART runs on the 50MHz fabric clk.

module tb_aurora_chip (
    input logic clk,
    input logic rst_n
);

    logic uart_rxd;
    logic uart_txd;
    logic [31:0] gpio_in;
    logic [31:0] gpio_out;
    logic [31:0] gpio_oe;
    logic timer_pwm;
    logic global_irq;

    aurora_soc_top_chip dut (
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

    assign uart_rxd = 1'b1;
    assign gpio_in  = 32'hAAAA_5555;

    logic uart_txd_prev;
    logic [31:0] gpio_out_prev;

    always @(posedge clk) begin
        if (rst_n) begin
            uart_txd_prev <= uart_txd;
            gpio_out_prev <= gpio_out;
            if (gpio_out !== gpio_out_prev)
                $display("[%0t] GPIO Out: 0x%08h", $time, gpio_out);
            if (global_irq)
                $display("[%0t] INTERRUPT!", $time);
        end
    end

    integer cycle_count;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cycle_count <= 0;
        else        cycle_count <= cycle_count + 1;
    end
    always @(posedge clk) begin
        if (rst_n && (cycle_count % 200000 == 0))
            $display("[Cycle %0d] Aurora-chip running...", cycle_count);
    end

    // ---- UART output capture: decode the AXI write to UART DATA (@0x2000_0000 off 0x00),
    //      which is faster/cleaner than serial-decoding uart_txd. Mirror to stdout + a file. ----
    integer uart_fd;
    initial uart_fd = $fopen("uart_chip.txt", "w");
    always @(posedge clk) begin
        if (rst_n && dut.xs_awvalid[2] && dut.xs_wvalid[2] && dut.xs_awready[2] && dut.xs_wready[2]
            && (dut.xs_awaddr[2][7:0] == 8'h00)) begin
            $fwrite(uart_fd, "%c", dut.uart_inst.s_axi_wdata[7:0]);
            $fflush(uart_fd);
        end
    end

    // ---- pass/fail monitor: flag any Rocket trap (exc, non-interrupt) ----
    always @(posedge clk) begin
        if (rst_n
            && dut.u_rocket.tile_prci_domain.auto_element_reset_domain_rockettile_trace_source_out_insns_0_valid
            && dut.u_rocket.tile_prci_domain.auto_element_reset_domain_rockettile_trace_source_out_insns_0_exception
            && !dut.u_rocket.tile_prci_domain.auto_element_reset_domain_rockettile_trace_source_out_insns_0_interrupt)
            $display("[c%0d] *** ROCKET TRAP @PC=0x%0h cause=%0d ***", cycle_count,
                dut.u_rocket.tile_prci_domain.auto_element_reset_domain_rockettile_trace_source_out_insns_0_iaddr,
                dut.u_rocket.tile_prci_domain.auto_element_reset_domain_rockettile_trace_source_out_insns_0_cause);
    end

    // UART TX decoder: 115200 baud @ 50 MHz fabric clk
    localparam int UART_DIV = 50_000_000 / 115200;
    integer  bit_cnt, baud_cnt;
    logic [7:0] rx_shift;
    logic    rx_active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_active <= 1'b0; bit_cnt <= 0; baud_cnt <= 0; rx_shift <= '0;
        end else if (!rx_active) begin
            if (uart_txd_prev && !uart_txd) begin
                rx_active <= 1'b1; baud_cnt <= UART_DIV + UART_DIV/2; bit_cnt <= 0;
            end
        end else begin
            if (baud_cnt == 0) begin
                rx_shift <= {uart_txd, rx_shift[7:1]};
                baud_cnt <= UART_DIV;
                if (bit_cnt == 7) begin
                    rx_active <= 1'b0;
                    $write("%c", {uart_txd, rx_shift[7:1]});
                    $fflush;
                end else bit_cnt <= bit_cnt + 1;
            end else baud_cnt <= baud_cnt - 1;
        end
    end

endmodule
