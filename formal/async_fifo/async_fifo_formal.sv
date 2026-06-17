`default_nettype none

module async_fifo_formal #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 2 // Depth = 4
) (
    input logic wr_clk,
    input logic rd_clk,
    input logic wr_rst_n,
    input logic rd_rst_n,
    input logic wr_en,
    input logic rd_en,
    input logic [DATA_WIDTH-1:0] wr_data
);

    logic wr_full, rd_empty;
    logic [DATA_WIDTH-1:0] rd_data;

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .wr_clk   (wr_clk),
        .rd_clk   (rd_clk),
        .wr_rst_n (wr_rst_n),
        .rd_rst_n (rd_rst_n),
        .wr_en    (wr_en),
        .wr_data  (wr_data),
        .wr_full  (wr_full),
        .rd_en    (rd_en),
        .rd_data  (rd_data),
        .rd_empty (rd_empty)
    );

    // ==========================================
    // YOSYS-SAFE FORMAL VERIFICATION BLOCK
    // ==========================================

    // Start in reset to prevent solver deadlock at time 0
    initial begin
        assume(wr_rst_n == 1'b0);
        assume(rd_rst_n == 1'b0);
    end

    integer f_past_valid_wr = 0;
    always @(posedge wr_clk) f_past_valid_wr <= f_past_valid_wr + 1;

    integer f_past_valid_rd = 0;
    always @(posedge rd_clk) f_past_valid_rd <= f_past_valid_rd + 1;

    // --- WRITE DOMAIN CHECKS ---
    always @(posedge wr_clk) begin
        if (wr_rst_n) begin
            if (wr_full) assume(!wr_en);
            assert(!(wr_full && rd_empty));

            if (f_past_valid_wr > 0) begin
                if (!$past(wr_rst_n)) assert(rd_empty);
                if ($past(wr_full) && !$past(rd_en)) assert(wr_full);
            end
            cover(wr_full);
        end
    end

    // --- READ DOMAIN CHECKS ---
    always @(posedge rd_clk) begin
        if (rd_rst_n) begin
            if (rd_empty) assume(!rd_en);

            if (f_past_valid_rd > 0) begin
                if ($past(rd_empty) && !$past(wr_en)) assert(rd_empty);
            end

            if (f_past_valid_rd >= 2) begin
                cover($past(wr_full, 2) && rd_empty);
            end
        end
    end

endmodule
