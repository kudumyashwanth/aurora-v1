// Clean behavioral implementations of the 4 RocketTile cache SRAM _ext modules
// (firtool 1RW interface). For SIM ONLY, to isolate functional bring-up from the
// sky130 macro mapping in rocket_sram_ext.v. 1-cycle synchronous (registered) read.

module rockettile_dcache_data_arrays_0_ext (
    input  [8:0]   RW0_addr,
    input          RW0_en,
    input          RW0_clk,
    input          RW0_wmode,
    input  [255:0] RW0_wdata,
    output [255:0] RW0_rdata,
    input  [31:0]  RW0_wmask     // per-byte write enable (32 bytes)
);
    reg [255:0] mem [0:511];
    reg [8:0] raddr;
    integer b;
    always @(posedge RW0_clk) begin
        if (RW0_en & RW0_wmode)
            for (b=0; b<32; b=b+1) if (RW0_wmask[b]) mem[RW0_addr][b*8+:8] <= RW0_wdata[b*8+:8];
        if (RW0_en & ~RW0_wmode) raddr <= RW0_addr;
    end
    assign RW0_rdata = mem[raddr];
endmodule

module rockettile_icache_data_arrays_0_ext (
    input  [8:0]   RW0_addr,
    input          RW0_en,
    input          RW0_clk,
    input          RW0_wmode,
    input  [127:0] RW0_wdata,
    output [127:0] RW0_rdata,
    input  [3:0]   RW0_wmask     // per-32b-word write enable (4 words)
);
    reg [127:0] mem [0:511];
    reg [8:0] raddr;
    integer w;
    always @(posedge RW0_clk) begin
        if (RW0_en & RW0_wmode)
            for (w=0; w<4; w=w+1) if (RW0_wmask[w]) mem[RW0_addr][w*32+:32] <= RW0_wdata[w*32+:32];
        if (RW0_en & ~RW0_wmode) raddr <= RW0_addr;
    end
    assign RW0_rdata = mem[raddr];
endmodule

module rockettile_dcache_tag_array_ext (
    input  [5:0]  RW0_addr,
    input         RW0_en,
    input         RW0_clk,
    input         RW0_wmode,
    input  [87:0] RW0_wdata,
    output [87:0] RW0_rdata,
    input  [3:0]  RW0_wmask     // 4 ways x 22b
);
    reg [87:0] mem [0:63];
    reg [5:0] raddr;
    always @(posedge RW0_clk) begin
        if (RW0_en & RW0_wmode) begin
            if (RW0_wmask[0]) mem[RW0_addr][21:0]  <= RW0_wdata[21:0];
            if (RW0_wmask[1]) mem[RW0_addr][43:22] <= RW0_wdata[43:22];
            if (RW0_wmask[2]) mem[RW0_addr][65:44] <= RW0_wdata[65:44];
            if (RW0_wmask[3]) mem[RW0_addr][87:66] <= RW0_wdata[87:66];
        end
        if (RW0_en & ~RW0_wmode) raddr <= RW0_addr;
    end
    assign RW0_rdata = mem[raddr];
endmodule

module rockettile_icache_tag_array_ext (
    input  [5:0]  RW0_addr,
    input         RW0_en,
    input         RW0_clk,
    input         RW0_wmode,
    input  [83:0] RW0_wdata,
    output [83:0] RW0_rdata,
    input  [3:0]  RW0_wmask     // 4 ways x 21b
);
    reg [83:0] mem [0:63];
    reg [5:0] raddr;
    always @(posedge RW0_clk) begin
        if (RW0_en & RW0_wmode) begin
            if (RW0_wmask[0]) mem[RW0_addr][20:0]  <= RW0_wdata[20:0];
            if (RW0_wmask[1]) mem[RW0_addr][41:21] <= RW0_wdata[41:21];
            if (RW0_wmask[2]) mem[RW0_addr][62:42] <= RW0_wdata[62:42];
            if (RW0_wmask[3]) mem[RW0_addr][83:63] <= RW0_wdata[83:63];
        end
        if (RW0_en & ~RW0_wmode) raddr <= RW0_addr;
    end
    assign RW0_rdata = mem[raddr];
endmodule
