// cpu_mem_bridge.sv
// Bridges PicoRV32 32-bit word-addressed memory bus to 128-bit AXI4 master.
// One outstanding transaction at a time (simple, correct).

`timescale 1ns/1ps

module cpu_mem_bridge #(
    parameter ADDR_WIDTH = 32,
    parameter AXI_WIDTH  = 128,
    parameter ID_WIDTH   = 4
) (
    input  logic clk,
    input  logic rst_n,

    // PicoRV32 memory interface
    input  logic        cpu_mem_valid,
    input  logic        cpu_mem_instr,
    output logic        cpu_mem_ready,
    input  logic [31:0] cpu_mem_addr,
    input  logic [31:0] cpu_mem_wdata,
    input  logic [ 3:0] cpu_mem_wstrb,  // 0000 = read
    output logic [31:0] cpu_mem_rdata,

    // AXI4 Master (128-bit to crossbar)
    output logic [ID_WIDTH-1:0]   m_axi_awid,
    output logic [ADDR_WIDTH-1:0] m_axi_awaddr,
    output logic [7:0]            m_axi_awlen,
    output logic [2:0]            m_axi_awsize,
    output logic [1:0]            m_axi_awburst,
    output logic                  m_axi_awvalid,
    input  logic                  m_axi_awready,

    output logic [AXI_WIDTH-1:0]  m_axi_wdata,
    output logic [15:0]           m_axi_wstrb,
    output logic                  m_axi_wlast,
    output logic                  m_axi_wvalid,
    input  logic                  m_axi_wready,

    input  logic [ID_WIDTH-1:0]   m_axi_bid,
    input  logic [1:0]            m_axi_bresp,
    input  logic                  m_axi_bvalid,
    output logic                  m_axi_bready,

    output logic [ID_WIDTH-1:0]   m_axi_arid,
    output logic [ADDR_WIDTH-1:0] m_axi_araddr,
    output logic [7:0]            m_axi_arlen,
    output logic [2:0]            m_axi_arsize,
    output logic [1:0]            m_axi_arburst,
    output logic                  m_axi_arvalid,
    input  logic                  m_axi_arready,

    input  logic [ID_WIDTH-1:0]   m_axi_rid,
    input  logic [AXI_WIDTH-1:0]  m_axi_rdata,
    input  logic [1:0]            m_axi_rresp,
    input  logic                  m_axi_rlast,
    input  logic                  m_axi_rvalid,
    output logic                  m_axi_rready
);

// -------------------------------------------------------
// State machine
// -------------------------------------------------------
typedef enum logic [2:0] {
    IDLE,
    AXI_RD_ADDR,
    AXI_RD_DATA,
    AXI_WR_ADDR,
    AXI_WR_DATA,
    AXI_WR_RESP
} state_t;

state_t state;

// Saved request
logic [31:0] saved_addr;
logic [31:0] saved_wdata;
logic [ 3:0] saved_wstrb;

// Word byte lane within 128-bit beat
// CPU address [3:2] selects which 32-bit word in the 16-byte AXI word
logic [1:0] word_sel;
assign word_sel = saved_addr[3:2];

// Align AXI address to 16-byte boundary
logic [ADDR_WIDTH-1:0] aligned_addr;
assign aligned_addr = {saved_addr[31:4], 4'b0000};

// -------------------------------------------------------
// AXI signal defaults
// -------------------------------------------------------
// Read channel
assign m_axi_arid    = '0;
assign m_axi_arlen   = 8'd0;       // 1 beat
assign m_axi_arsize  = 3'b100;     // 16 bytes (128-bit)
assign m_axi_arburst = 2'b01;      // INCR

// Write channel
assign m_axi_awid    = '0;
assign m_axi_awlen   = 8'd0;
assign m_axi_awsize  = 3'b100;
assign m_axi_awburst = 2'b01;
assign m_axi_wlast   = 1'b1;

// -------------------------------------------------------
// Main FSM
// -------------------------------------------------------
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state         <= IDLE;
        cpu_mem_ready <= 1'b0;
        cpu_mem_rdata <= 32'd0;
        m_axi_araddr  <= '0;
        m_axi_arvalid <= 1'b0;
        m_axi_rready  <= 1'b0;
        m_axi_awaddr  <= '0;
        m_axi_awvalid <= 1'b0;
        m_axi_wdata   <= '0;
        m_axi_wstrb   <= '0;
        m_axi_wvalid  <= 1'b0;
        m_axi_bready  <= 1'b0;
        saved_addr    <= '0;
        saved_wdata   <= '0;
        saved_wstrb   <= '0;
    end else begin
        cpu_mem_ready <= 1'b0;  // default

        case (state)
            // -------------------------------------------------
            IDLE: begin
                if (cpu_mem_valid) begin
                    saved_addr  <= cpu_mem_addr;
                    saved_wdata <= cpu_mem_wdata;
                    saved_wstrb <= cpu_mem_wstrb;
                    if (cpu_mem_wstrb == 4'b0000) begin
                        state <= AXI_RD_ADDR;
                    end else begin
                        state <= AXI_WR_ADDR;
                    end
                end
            end

            // -------------------------------------------------
            AXI_RD_ADDR: begin
                m_axi_araddr  <= aligned_addr;
                m_axi_arvalid <= 1'b1;
                if (m_axi_arready) begin
                    m_axi_arvalid <= 1'b0;
                    m_axi_rready  <= 1'b1;
                    state         <= AXI_RD_DATA;
                end
            end

            // -------------------------------------------------
            AXI_RD_DATA: begin
                if (m_axi_rvalid) begin
                    m_axi_rready  <= 1'b0;
                    // Extract correct 32-bit word from 128-bit beat
                    case (word_sel)
                        2'd0: cpu_mem_rdata <= m_axi_rdata[31:0];
                        2'd1: cpu_mem_rdata <= m_axi_rdata[63:32];
                        2'd2: cpu_mem_rdata <= m_axi_rdata[95:64];
                        2'd3: cpu_mem_rdata <= m_axi_rdata[127:96];
                    endcase
                    cpu_mem_ready <= 1'b1;
                    state         <= IDLE;
                end
            end

            // -------------------------------------------------
            AXI_WR_ADDR: begin
                m_axi_awaddr  <= aligned_addr;
                m_axi_awvalid <= 1'b1;
                if (m_axi_awready) begin
                    m_axi_awvalid <= 1'b0;
                    // Build 128-bit write data and strobe from 32-bit word
                    case (word_sel)
                        2'd0: begin
                            m_axi_wdata <= {96'b0, saved_wdata};
                            m_axi_wstrb <= {12'b0, saved_wstrb};
                        end
                        2'd1: begin
                            m_axi_wdata <= {64'b0, saved_wdata, 32'b0};
                            m_axi_wstrb <= {8'b0, saved_wstrb, 4'b0};
                        end
                        2'd2: begin
                            m_axi_wdata <= {32'b0, saved_wdata, 64'b0};
                            m_axi_wstrb <= {4'b0, saved_wstrb, 8'b0};
                        end
                        2'd3: begin
                            m_axi_wdata <= {saved_wdata, 96'b0};
                            m_axi_wstrb <= {saved_wstrb, 12'b0};
                        end
                    endcase
                    m_axi_wvalid <= 1'b1;
                    state        <= AXI_WR_DATA;
                end
            end

            // -------------------------------------------------
            AXI_WR_DATA: begin
                if (m_axi_wready) begin
                    m_axi_wvalid <= 1'b0;
                    m_axi_bready <= 1'b1;
                    state        <= AXI_WR_RESP;
                end
            end

            // -------------------------------------------------
            AXI_WR_RESP: begin
                if (m_axi_bvalid) begin
                    m_axi_bready  <= 1'b0;
                    cpu_mem_ready <= 1'b1;
                    state         <= IDLE;
                end
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule
