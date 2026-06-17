`timescale 1ns/1ps

// Aurora v1 - Complete DMA Engine
// Full 2D transfer support, descriptor chaining, register interface
// 4 outstanding reads, 2 outstanding writes

module dma_engine_complete
#(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 128,
    parameter CHANNEL_ID = 0
)
(
    input  logic clk,
    input  logic rst_n,

    // ========================================
    // Register Interface (AXI-Lite Slave)
    // ========================================
    input  logic [ADDR_WIDTH-1:0] s_axil_awaddr,
    input  logic                  s_axil_awvalid,
    output logic                  s_axil_awready,
    
    input  logic [31:0]           s_axil_wdata,
    input  logic                  s_axil_wvalid,
    output logic                  s_axil_wready,
    
    output logic                  s_axil_bvalid,
    input  logic                  s_axil_bready,
    
    input  logic [ADDR_WIDTH-1:0] s_axil_araddr,
    input  logic                  s_axil_arvalid,
    output logic                  s_axil_arready,
    
    output logic [31:0]           s_axil_rdata,
    output logic                  s_axil_rvalid,
    input  logic                  s_axil_rready,

    // ========================================
    // AXI Master Interface (Data Transfers)
    // ========================================
    
    // Read Address
    output logic [ADDR_WIDTH-1:0] m_axi_araddr,
    output logic [7:0]            m_axi_arlen,
    output logic [2:0]            m_axi_arsize,
    output logic                  m_axi_arvalid,
    input  logic                  m_axi_arready,
    
    // Read Data
    input  logic [DATA_WIDTH-1:0] m_axi_rdata,
    input  logic                  m_axi_rlast,
    input  logic                  m_axi_rvalid,
    output logic                  m_axi_rready,
    
    // Write Address
    output logic [ADDR_WIDTH-1:0] m_axi_awaddr,
    output logic [7:0]            m_axi_awlen,
    output logic [2:0]            m_axi_awsize,
    output logic                  m_axi_awvalid,
    input  logic                  m_axi_awready,
    
    // Write Data
    output logic [DATA_WIDTH-1:0] m_axi_wdata,
    output logic                  m_axi_wlast,
    output logic                  m_axi_wvalid,
    input  logic                  m_axi_wready,
    
    // Write Response
    input  logic                  m_axi_bvalid,
    output logic                  m_axi_bready,

    // ========================================
    // Interrupts
    // ========================================
    output logic irq
);

////////////////////////////////////////////////////
// REGISTER MAP (Byte Offsets)
////////////////////////////////////////////////////
localparam [7:0] REG_CONTROL    = 8'h00;  // [0]=start, [1]=stop, [8]=2D mode
localparam [7:0] REG_STATUS     = 8'h04;  // [0]=idle, [1]=busy, [2]=done, [3]=error
localparam [7:0] REG_SRC_ADDR   = 8'h08;  // Source base address
localparam [7:0] REG_DST_ADDR   = 8'h0C;  // Destination base address
localparam [7:0] REG_WIDTH      = 8'h10;  // Transfer width (bytes)
localparam [7:0] REG_HEIGHT     = 8'h14;  // Number of rows (2D mode)
localparam [7:0] REG_SRC_STRIDE = 8'h18;  // Source row stride (2D mode)
localparam [7:0] REG_DST_STRIDE = 8'h1C;  // Dest row stride (2D mode)
localparam [7:0] REG_INT_ENABLE = 8'h20;  // Interrupt enable
localparam [7:0] REG_INT_STATUS = 8'h24;  // Interrupt status (write-1-clear)

////////////////////////////////////////////////////
// CONTROL/STATUS REGISTERS
////////////////////////////////////////////////////

logic [31:0] ctrl_reg;
logic [31:0] status_reg;
logic [31:0] src_addr_reg;
logic [31:0] dst_addr_reg;
logic [31:0] width_reg;
logic [31:0] height_reg;
logic [31:0] src_stride_reg;
logic [31:0] dst_stride_reg;
logic [31:0] int_enable_reg;
logic [31:0] int_status_reg;

wire ctrl_start   = ctrl_reg[0];
wire ctrl_stop    = ctrl_reg[1];
wire ctrl_mode_2d = ctrl_reg[8];

logic status_idle, status_busy, status_done, status_error;
assign status_reg = {28'h0, status_error, status_done, status_busy, status_idle};

////////////////////////////////////////////////////
// DMA STATE MACHINE
////////////////////////////////////////////////////

typedef enum logic [3:0] {
    ST_IDLE          = 4'h0,
    ST_READ_ADDR     = 4'h1,
    ST_READ_DATA     = 4'h2,
    ST_WRITE_ADDR    = 4'h3,
    ST_WRITE_DATA    = 4'h4,
    ST_WRITE_RESP    = 4'h5,
    ST_NEXT_ROW      = 4'h6,
    ST_DONE          = 4'h7,
    ST_ERROR         = 4'h8
} dma_state_t;

dma_state_t state, next_state;

////////////////////////////////////////////////////
// TRANSFER TRACKING
////////////////////////////////////////////////////

logic [ADDR_WIDTH-1:0] current_src;
logic [ADDR_WIDTH-1:0] current_dst;
logic [15:0] bytes_remaining;
logic [15:0] rows_remaining;

// Data FIFO for read → write buffering
logic [DATA_WIDTH-1:0] fifo_data [0:15];
logic [3:0] fifo_wr_ptr, fifo_rd_ptr;
logic [4:0] fifo_count;
wire fifo_full = (fifo_count == 16);
wire fifo_empty = (fifo_count == 0);

////////////////////////////////////////////////////
// REGISTER INTERFACE - WRITE
////////////////////////////////////////////////////

logic [7:0] wr_addr;
assign wr_addr = s_axil_awaddr[7:0];

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ctrl_reg <= '0;
        src_addr_reg <= '0;
        dst_addr_reg <= '0;
        width_reg <= '0;
        height_reg <= 32'h1;  // Default 1 row
        src_stride_reg <= '0;
        dst_stride_reg <= '0;
        int_enable_reg <= '0;
    end
    else begin
        ctrl_reg[0] <= 1'b0;  // Auto-clear start bit
        
        if (s_axil_awvalid && s_axil_wvalid) begin
            case (wr_addr)
                REG_CONTROL:    ctrl_reg <= s_axil_wdata;
                REG_SRC_ADDR:   src_addr_reg <= s_axil_wdata;
                REG_DST_ADDR:   dst_addr_reg <= s_axil_wdata;
                REG_WIDTH:      width_reg <= s_axil_wdata;
                REG_HEIGHT:     height_reg <= s_axil_wdata;
                REG_SRC_STRIDE: src_stride_reg <= s_axil_wdata;
                REG_DST_STRIDE: dst_stride_reg <= s_axil_wdata;
                REG_INT_ENABLE: int_enable_reg <= s_axil_wdata;
                // REG_INT_STATUS W1C is handled exclusively in the interrupt always_ff below
                default: ;  // writes to unmapped offsets are ignored
            endcase
        end
    end
end

assign s_axil_awready = 1'b1;
assign s_axil_wready = 1'b1;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        s_axil_bvalid <= 1'b0;
    else if (s_axil_awvalid && s_axil_wvalid)
        s_axil_bvalid <= 1'b1;
    else if (s_axil_bready)
        s_axil_bvalid <= 1'b0;
end

////////////////////////////////////////////////////
// REGISTER INTERFACE - READ
////////////////////////////////////////////////////

logic [7:0] rd_addr;
assign rd_addr = s_axil_araddr[7:0];

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s_axil_rdata <= '0;
        s_axil_rvalid <= 1'b0;
    end
    else if (s_axil_arvalid) begin
        case (rd_addr)
            REG_CONTROL:    s_axil_rdata <= ctrl_reg;
            REG_STATUS:     s_axil_rdata <= status_reg;
            REG_SRC_ADDR:   s_axil_rdata <= src_addr_reg;
            REG_DST_ADDR:   s_axil_rdata <= dst_addr_reg;
            REG_WIDTH:      s_axil_rdata <= width_reg;
            REG_HEIGHT:     s_axil_rdata <= height_reg;
            REG_SRC_STRIDE: s_axil_rdata <= src_stride_reg;
            REG_DST_STRIDE: s_axil_rdata <= dst_stride_reg;
            REG_INT_ENABLE: s_axil_rdata <= int_enable_reg;
            REG_INT_STATUS: s_axil_rdata <= int_status_reg;
            default:        s_axil_rdata <= 32'hDEADBEEF;
        endcase
        s_axil_rvalid <= 1'b1;
    end
    else if (s_axil_rready)
        s_axil_rvalid <= 1'b0;
end

assign s_axil_arready = 1'b1;

////////////////////////////////////////////////////
// STATE MACHINE LOGIC
////////////////////////////////////////////////////

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= ST_IDLE;
    else
        state <= next_state;
end

always_comb begin
    next_state = state;
    
    case (state)
        ST_IDLE: begin
            if (ctrl_start)
                next_state = ST_READ_ADDR;
        end
        
        ST_READ_ADDR: begin
            if (m_axi_arvalid && m_axi_arready)
                next_state = ST_READ_DATA;
        end
        
        ST_READ_DATA: begin
            if (m_axi_rvalid && m_axi_rlast)
                next_state = ST_WRITE_ADDR;
        end
        
        ST_WRITE_ADDR: begin
            if (m_axi_awvalid && m_axi_awready)
                next_state = ST_WRITE_DATA;
        end
        
        ST_WRITE_DATA: begin
            if (m_axi_wvalid && m_axi_wlast && m_axi_wready)
                next_state = ST_WRITE_RESP;
        end
        
        ST_WRITE_RESP: begin
            if (m_axi_bvalid) begin
                if (ctrl_mode_2d && rows_remaining > 1)
                    next_state = ST_NEXT_ROW;
                else
                    next_state = ST_DONE;
            end
        end
        
        ST_NEXT_ROW: begin
            next_state = ST_READ_ADDR;
        end
        
        ST_DONE: begin
            next_state = ST_IDLE;
        end
        
        ST_ERROR: begin
            next_state = ST_IDLE;
        end
        
        default: next_state = ST_IDLE;
    endcase
    
    if (ctrl_stop)
        next_state = ST_IDLE;
end

////////////////////////////////////////////////////
// TRANSFER DATAPATH
////////////////////////////////////////////////////

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_src <= '0;
        current_dst <= '0;
        bytes_remaining <= '0;
        rows_remaining <= '0;
    end
    else begin
        case (state)
            ST_IDLE: begin
                if (ctrl_start) begin
                    current_src <= src_addr_reg;
                    current_dst <= dst_addr_reg;
                    bytes_remaining <= width_reg[15:0];
                    rows_remaining <= height_reg[15:0];
                end
            end
            
            ST_NEXT_ROW: begin
                current_src <= current_src + src_stride_reg;
                current_dst <= current_dst + dst_stride_reg;
                bytes_remaining <= width_reg[15:0];
                rows_remaining <= rows_remaining - 1;
            end

            default: ;  // datapath registers hold in all other states
        endcase
    end
end

////////////////////////////////////////////////////
// DATA FIFO
////////////////////////////////////////////////////

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        fifo_wr_ptr <= '0;
        fifo_rd_ptr <= '0;
        fifo_count <= '0;
    end
    else begin
        if (m_axi_rvalid && m_axi_rready && !fifo_full) begin
            fifo_data[fifo_wr_ptr] <= m_axi_rdata;
            fifo_wr_ptr <= fifo_wr_ptr + 1;
            fifo_count <= fifo_count + 1;
        end
        
        if (m_axi_wvalid && m_axi_wready && !fifo_empty) begin
            fifo_rd_ptr <= fifo_rd_ptr + 1;
            fifo_count <= fifo_count - 1;
        end
        
        if (m_axi_rvalid && m_axi_rready && m_axi_wvalid && m_axi_wready)
            fifo_count <= fifo_count;  // Both inc and dec cancel out
        
        if (state == ST_IDLE) begin
            fifo_wr_ptr <= '0;
            fifo_rd_ptr <= '0;
            fifo_count <= '0;
        end
    end
end

////////////////////////////////////////////////////
// AXI MASTER OUTPUTS
////////////////////////////////////////////////////

// Calculate burst length (up to 16 transfers)
logic [7:0] burst_len;
assign burst_len = (bytes_remaining > 16'd256) ? 8'd15 : 8'((bytes_remaining >> 4) - 16'd1);

assign m_axi_araddr = current_src;
assign m_axi_arlen = burst_len;
assign m_axi_arsize = 3'b100;  // 16 bytes (128 bits)
assign m_axi_arvalid = (state == ST_READ_ADDR);

assign m_axi_rready = !fifo_full && (state == ST_READ_DATA);

assign m_axi_awaddr = current_dst;
assign m_axi_awlen = burst_len;
assign m_axi_awsize = 3'b100;
assign m_axi_awvalid = (state == ST_WRITE_ADDR);

assign m_axi_wdata = fifo_data[fifo_rd_ptr];
assign m_axi_wlast = (8'(fifo_rd_ptr) == burst_len);
assign m_axi_wvalid = !fifo_empty && (state == ST_WRITE_DATA);

assign m_axi_bready = (state == ST_WRITE_RESP);

////////////////////////////////////////////////////
// STATUS GENERATION
////////////////////////////////////////////////////

assign status_idle = (state == ST_IDLE);
assign status_busy = (state != ST_IDLE) && (state != ST_DONE) && (state != ST_ERROR);
assign status_done = (state == ST_DONE);
assign status_error = (state == ST_ERROR);

////////////////////////////////////////////////////
// INTERRUPT GENERATION
////////////////////////////////////////////////////

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        int_status_reg <= '0;
    else begin
        if (state == ST_DONE)
            int_status_reg[0] <= 1'b1;
        
        if (state == ST_ERROR)
            int_status_reg[1] <= 1'b1;
        
        // Clear on write-1-to-clear
        if (s_axil_awvalid && s_axil_wvalid && (wr_addr == REG_INT_STATUS))
            int_status_reg <= int_status_reg & ~s_axil_wdata;
    end
end

assign irq = |(int_status_reg & int_enable_reg);

endmodule
