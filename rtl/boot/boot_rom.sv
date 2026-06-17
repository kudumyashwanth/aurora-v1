`timescale 1ns/1ps

// Aurora v1 - Boot ROM
// 64KB ROM — loads aurora_boot.hex at simulation start
// AXI4-Lite slave interface (128-bit data)

module boot_rom #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 128,
    parameter ROM_SIZE   = 65536   // 64KB
) (
    input  logic clk,
    input  logic rst_n,

    input  logic [ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic                  s_axi_arvalid,
    output logic                  s_axi_arready,

    output logic [DATA_WIDTH-1:0] s_axi_rdata,
    output logic                  s_axi_rvalid,
    input  logic                  s_axi_rready,

    input  logic [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic                  s_axi_awvalid,
    output logic                  s_axi_awready,

    input  logic [DATA_WIDTH-1:0] s_axi_wdata,
    input  logic                  s_axi_wvalid,
    output logic                  s_axi_wready,

    output logic                  s_axi_bvalid,
    input  logic                  s_axi_bready
);

localparam ROM_DEPTH = ROM_SIZE / (DATA_WIDTH/8);

logic [DATA_WIDTH-1:0] rom_mem [0:ROM_DEPTH-1];

// Load Aurora AI demo boot program
initial begin
    integer i;
    for (i = 0; i < ROM_DEPTH; i++) rom_mem[i] = '0;
    $readmemh("/home/yashwanth/aurora_v1/boot/aurora_boot.hex", rom_mem);
end

// READ PATH
logic [15:0] read_addr;
assign read_addr = s_axi_araddr[19:4];

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s_axi_rdata  <= '0;
        s_axi_rvalid <= 1'b0;
    end else begin
        if (s_axi_arvalid && s_axi_arready) begin
            s_axi_rdata  <= (32'(read_addr) < ROM_DEPTH) ? rom_mem[read_addr[$clog2(ROM_DEPTH)-1:0]] : {4{32'hDEADBEEF}};
            s_axi_rvalid <= 1'b1;
        end else if (s_axi_rready)
            s_axi_rvalid <= 1'b0;
    end
end

assign s_axi_arready = !s_axi_rvalid || s_axi_rready;

// WRITE PATH (ROM is read-only — accept and ignore)
assign s_axi_awready = 1'b1;
assign s_axi_wready  = 1'b1;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        s_axi_bvalid <= 1'b0;
    else if (s_axi_awvalid && s_axi_wvalid)
        s_axi_bvalid <= 1'b1;
    else if (s_axi_bready)
        s_axi_bvalid <= 1'b0;
end

endmodule
