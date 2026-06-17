`timescale 1ns/1ps

// Aurora v1 - Timer Peripheral
// 32-bit up/down counter with compare and PWM output
// Multiple timer instances for flexibility

module timer
#(
    parameter CLK_FREQ = 200_000_000  // 200 MHz
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

    // Timer outputs
    output logic        pwm_out,
    output logic        irq
);

////////////////////////////////////////////////////
// REGISTER MAP
////////////////////////////////////////////////////
localparam REG_CONTROL  = 8'h00;  // [0]=enable, [1]=mode(0=up,1=down), [2]=PWM enable
localparam REG_STATUS   = 8'h04;  // [0]=overflow, [1]=compare match
localparam REG_COUNT    = 8'h08;  // Current counter value
localparam REG_COMPARE  = 8'h0C;  // Compare value
localparam REG_RELOAD   = 8'h10;  // Auto-reload value
localparam REG_PRESCALE = 8'h14;  // Prescaler value
localparam REG_INT_EN   = 8'h18;  // Interrupt enable

////////////////////////////////////////////////////
// CONTROL/STATUS REGISTERS
////////////////////////////////////////////////////

logic [31:0] control_reg;
logic [31:0] status_reg;
logic [31:0] count_reg;
logic [31:0] compare_reg;
logic [31:0] reload_reg;
logic [31:0] prescale_reg;
logic [31:0] int_en_reg;

wire timer_enable = control_reg[0];
wire count_down   = control_reg[1];
wire pwm_enable   = control_reg[2];
wire auto_reload  = control_reg[3];

logic overflow_flag;
logic compare_match_flag;

assign status_reg = {30'h0, compare_match_flag, overflow_flag};

////////////////////////////////////////////////////
// PRESCALER
////////////////////////////////////////////////////

logic [31:0] prescale_counter;
logic prescale_tick;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        prescale_counter <= '0;
        prescale_tick <= 1'b0;
    end
    else begin
        if (prescale_counter >= prescale_reg) begin
            prescale_counter <= '0;
            prescale_tick <= 1'b1;
        end
        else begin
            prescale_counter <= prescale_counter + 1;
            prescale_tick <= 1'b0;
        end
    end
end

////////////////////////////////////////////////////
// COUNTER LOGIC
////////////////////////////////////////////////////

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        count_reg <= '0;
        overflow_flag <= 1'b0;
        compare_match_flag <= 1'b0;
    end
    else begin
        // Software write to REG_COUNT takes priority over hardware increment
        if (s_axi_awvalid && s_axi_wvalid && (s_axi_awaddr[7:0] == REG_COUNT)) begin
            count_reg <= s_axi_wdata;
        end else if (timer_enable && prescale_tick) begin
            if (count_down) begin
                if (count_reg == 0) begin
                    overflow_flag <= 1'b1;
                    count_reg <= auto_reload ? reload_reg : 32'hFFFFFFFF;
                end else
                    count_reg <= count_reg - 1;
            end else begin
                if (count_reg == 32'hFFFFFFFF) begin
                    overflow_flag <= 1'b1;
                    count_reg <= auto_reload ? reload_reg : 32'h0;
                end else
                    count_reg <= count_reg + 1;
            end

            if (count_reg == compare_reg)
                compare_match_flag <= 1'b1;
        end

        // Clear status flags on write-1-clear
        if (s_axi_awvalid && s_axi_wvalid && (s_axi_awaddr[7:0] == REG_STATUS)) begin
            if (s_axi_wdata[0]) overflow_flag     <= 1'b0;
            if (s_axi_wdata[1]) compare_match_flag <= 1'b0;
        end
    end
end

////////////////////////////////////////////////////
// PWM OUTPUT GENERATION
////////////////////////////////////////////////////

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        pwm_out <= 1'b0;
    else if (pwm_enable) begin
        if (count_reg < compare_reg)
            pwm_out <= 1'b1;
        else
            pwm_out <= 1'b0;
    end
    else
        pwm_out <= 1'b0;
end

////////////////////////////////////////////////////
// REGISTER WRITE INTERFACE
////////////////////////////////////////////////////

assign s_axi_awready = 1'b1;
assign s_axi_wready = 1'b1;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        control_reg <= '0;
        compare_reg <= '0;
        reload_reg <= '0;
        prescale_reg <= 32'd199;  // Default: 1 MHz tick from 200 MHz clock
        int_en_reg <= '0;
    end
    else if (s_axi_awvalid && s_axi_wvalid) begin
        case (s_axi_awaddr[7:0])
            REG_CONTROL:  control_reg <= s_axi_wdata;
            // REG_COUNT write is handled in the counter always_ff above
            REG_COMPARE:  compare_reg <= s_axi_wdata;
            REG_RELOAD:   reload_reg <= s_axi_wdata;
            REG_PRESCALE: prescale_reg <= s_axi_wdata;
            REG_INT_EN:   int_en_reg <= s_axi_wdata;
            default: ;
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
            REG_CONTROL:  s_axi_rdata <= control_reg;
            REG_STATUS:   s_axi_rdata <= status_reg;
            REG_COUNT:    s_axi_rdata <= count_reg;
            REG_COMPARE:  s_axi_rdata <= compare_reg;
            REG_RELOAD:   s_axi_rdata <= reload_reg;
            REG_PRESCALE: s_axi_rdata <= prescale_reg;
            REG_INT_EN:   s_axi_rdata <= int_en_reg;
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

assign irq = ((overflow_flag & int_en_reg[0]) | 
              (compare_match_flag & int_en_reg[1]));

endmodule
