`timescale 1ns/1ps

// Aurora v1 - Simplified AXI4-Lite Crossbar
// 8 Masters × 8 Slaves with round-robin arbitration
// Simplified version for Aurora v1 - no out-of-order, no bursts
//
// Protocol contract (simplified vs full AXI4):
//  - Single beat per transaction (no bursts)
//  - One outstanding transaction per master per direction
//  - Grants lock at the address handshake and release at the response
//    handshake, so AW/W/B (and AR/R) of one transaction always route
//    between the same master/slave pair.

module axi_crossbar
#(
    parameter DATA_WIDTH = 128,
    parameter ADDR_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter NUM_MASTERS = 8,
    parameter NUM_SLAVES  = 8
)
(
    input logic clk,
    input logic rst_n,

    // ========================================
    // Master Interfaces (from CPU/DMA)
    // ========================================

    // Write Address
    input  logic [NUM_MASTERS-1:0][ADDR_WIDTH-1:0]  m_awaddr,
    input  logic [NUM_MASTERS-1:0]                  m_awvalid,
    output logic [NUM_MASTERS-1:0]                  m_awready,

    // Write Data
    input  logic [NUM_MASTERS-1:0][DATA_WIDTH-1:0]   m_wdata,
    input  logic [NUM_MASTERS-1:0][DATA_WIDTH/8-1:0] m_wstrb,
    input  logic [NUM_MASTERS-1:0]                   m_wvalid,
    output logic [NUM_MASTERS-1:0]                   m_wready,

    // Write Response
    output logic [NUM_MASTERS-1:0]                  m_bvalid,
    input  logic [NUM_MASTERS-1:0]                  m_bready,

    // Read Address
    input  logic [NUM_MASTERS-1:0][ADDR_WIDTH-1:0]  m_araddr,
    input  logic [NUM_MASTERS-1:0]                  m_arvalid,
    output logic [NUM_MASTERS-1:0]                  m_arready,

    // Read Data
    output logic [NUM_MASTERS-1:0][DATA_WIDTH-1:0]  m_rdata,
    output logic [NUM_MASTERS-1:0]                  m_rvalid,
    input  logic [NUM_MASTERS-1:0]                  m_rready,

    // ========================================
    // Slave Interfaces (to SRAM banks, peripherals)
    // ========================================

    // Write Address
    output logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0]   s_awaddr,
    output logic [NUM_SLAVES-1:0]                   s_awvalid,
    input  logic [NUM_SLAVES-1:0]                   s_awready,

    // Write Data
    output logic [NUM_SLAVES-1:0][DATA_WIDTH-1:0]    s_wdata,
    output logic [NUM_SLAVES-1:0][DATA_WIDTH/8-1:0]  s_wstrb,
    output logic [NUM_SLAVES-1:0]                    s_wvalid,
    input  logic [NUM_SLAVES-1:0]                    s_wready,

    // Write Response
    input  logic [NUM_SLAVES-1:0]                   s_bvalid,
    output logic [NUM_SLAVES-1:0]                   s_bready,

    // Read Address
    output logic [NUM_SLAVES-1:0][ADDR_WIDTH-1:0]   s_araddr,
    output logic [NUM_SLAVES-1:0]                   s_arvalid,
    input  logic [NUM_SLAVES-1:0]                   s_arready,

    // Read Data
    input  logic [NUM_SLAVES-1:0][DATA_WIDTH-1:0]   s_rdata,
    input  logic [NUM_SLAVES-1:0]                   s_rvalid,
    output logic [NUM_SLAVES-1:0]                   s_rready
);

localparam int MW = $clog2(NUM_MASTERS);

////////////////////////////////////////////////////
// ADDRESS DECODE
////////////////////////////////////////////////////

function automatic logic [2:0] decode_address(logic [ADDR_WIDTH-1:0] addr);
    // Aurora v1 address map:
    // 0x0000_0000 / 0x8000_0000: Boot ROM    (Slave 0)
    //   (0x00 = CVA6 flat-SoC reset vector; 0x80 = Rocket reset vector — both alias to ROM)
    // 0x1000_0000 - 0x13FF_FFFF: SRAM        (Slave 1)
    // 0x2000_0000 - 0x2000_00FF: UART        (Slave 2)
    // 0x3000_0000 - 0x3000_00FF: GPIO        (Slave 3)
    // 0x4000_0000 - 0x4000_00FF: Timer       (Slave 4)
    // 0x5000_0000 - 0x5FFF_FFFF: Tensor cluster (Slave 5)
    // 0x6000_0000 - 0x6000_03FF: DMA regs    (Slave 6)
    // Default: error sink                    (Slave 7)

    // assignment style (no return) — Yosys-compatible
    if (addr[31:24] == 8'h00 || addr[31:24] == 8'h80)
        decode_address = 3'd0;  // Boot ROM (0x00 CVA6 reset / 0x80 Rocket reset)
    else if (addr[31:24] == 8'h10 || addr[31:24] == 8'h11 ||
             addr[31:24] == 8'h12 || addr[31:24] == 8'h13)
        decode_address = 3'd1;  // SRAM
    else if (addr[31:24] == 8'h20)
        decode_address = 3'd2;  // UART
    else if (addr[31:24] == 8'h30)
        decode_address = 3'd3;  // GPIO
    else if (addr[31:24] == 8'h40)
        decode_address = 3'd4;  // Timer
    else if (addr[31:24] == 8'h50)
        decode_address = 3'd5;  // Tensor cluster (control regs + local buffers)
    else if (addr[31:24] == 8'h60)
        decode_address = 3'd6;  // DMA control registers
    else
        decode_address = 3'd7;  // Unmapped — error sink
endfunction

////////////////////////////////////////////////////
// ROUND-ROBIN PICK
// Returns {found, index}: first requester at or after ptr, wrapping.
////////////////////////////////////////////////////

function automatic logic [MW:0] rr_pick(logic [NUM_MASTERS-1:0] req,
                                        logic [MW-1:0] ptr);
    logic [MW-1:0] idx;
    rr_pick = '0;
    for (int k = NUM_MASTERS-1; k >= 0; k--) begin
        idx = ptr + MW'(k);
        if (req[idx])
            rr_pick = {1'b1, idx};
    end
endfunction

////////////////////////////////////////////////////
// WRITE PATH
////////////////////////////////////////////////////

// Per-slave grant state
logic [NUM_SLAVES-1:0]               wr_busy;     // transaction in flight
logic [NUM_SLAVES-1:0][MW-1:0]       wr_owner;    // locked master
logic [NUM_SLAVES-1:0][MW-1:0]       wr_rr_ptr;   // round-robin pointer

// Per-slave request collection (masked by per-master outstanding limit)
logic [NUM_MASTERS-1:0]              m_wr_outstanding;
logic [NUM_SLAVES-1:0][NUM_MASTERS-1:0] wr_req;

always_comb begin
    for (int mm = 0; mm < NUM_MASTERS; mm++) begin
        m_wr_outstanding[mm] = 1'b0;
        for (int ss = 0; ss < NUM_SLAVES; ss++)
            if (wr_busy[ss] && (wr_owner[ss] == MW'(mm)))
                m_wr_outstanding[mm] = 1'b1;
    end
    for (int ss = 0; ss < NUM_SLAVES; ss++)
        for (int mm = 0; mm < NUM_MASTERS; mm++)
            wr_req[ss][mm] = m_awvalid[mm] && !m_wr_outstanding[mm] &&
                             (decode_address(m_awaddr[mm]) == 3'(ss));
end

// Effective grant per slave: locked owner while busy, else round-robin pick
logic [NUM_SLAVES-1:0]         wr_act;
logic [NUM_SLAVES-1:0][MW-1:0] wr_gnt;

always_comb begin
    for (int ss = 0; ss < NUM_SLAVES; ss++) begin
        logic [MW:0] pick;
        pick = rr_pick(wr_req[ss], wr_rr_ptr[ss]);
        if (wr_busy[ss]) begin
            wr_act[ss] = 1'b1;
            wr_gnt[ss] = wr_owner[ss];
        end else begin
            wr_act[ss] = pick[MW];
            wr_gnt[ss] = pick[MW-1:0];
        end
    end
end

// Lock on AW handshake, release on B handshake
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_busy   <= '0;
        wr_owner  <= '0;
        wr_rr_ptr <= '0;
    end else begin
        for (int ss = 0; ss < NUM_SLAVES; ss++) begin
            if (!wr_busy[ss] && s_awvalid[ss] && s_awready[ss]) begin
                wr_busy[ss]  <= 1'b1;
                wr_owner[ss] <= wr_gnt[ss];
            end else if (wr_busy[ss] && s_bvalid[ss] && s_bready[ss]) begin
                wr_busy[ss]   <= 1'b0;
                wr_rr_ptr[ss] <= wr_owner[ss] + MW'(1);
            end
        end
    end
end

// Slave-side routing
always_comb begin
    for (int ss = 0; ss < NUM_SLAVES; ss++) begin
        if (wr_act[ss]) begin
            s_awaddr[ss]  = m_awaddr[wr_gnt[ss]];
            // AW valid only until the lock is taken (single AW per txn)
            s_awvalid[ss] = !wr_busy[ss] && m_awvalid[wr_gnt[ss]];
            s_wdata[ss]   = m_wdata[wr_gnt[ss]];
            s_wstrb[ss]   = m_wstrb[wr_gnt[ss]];
            s_wvalid[ss]  = m_wvalid[wr_gnt[ss]];
            s_bready[ss]  = m_bready[wr_gnt[ss]];
        end else begin
            s_awaddr[ss]  = '0;
            s_awvalid[ss] = 1'b0;
            s_wdata[ss]   = '0;
            s_wstrb[ss]   = '0;
            s_wvalid[ss]  = 1'b0;
            s_bready[ss]  = 1'b0;
        end
    end
end

// Master-side routing (uses locked/effective grants, never re-decodes
// a possibly-changed address)
always_comb begin
    for (int mm = 0; mm < NUM_MASTERS; mm++) begin
        m_awready[mm] = 1'b0;
        m_wready[mm]  = 1'b0;
        m_bvalid[mm]  = 1'b0;
        for (int ss = 0; ss < NUM_SLAVES; ss++) begin
            if (wr_act[ss] && (wr_gnt[ss] == MW'(mm))) begin
                m_awready[mm] |= !wr_busy[ss] && s_awready[ss];
                m_wready[mm]  |= s_wready[ss];
                m_bvalid[mm]  |= s_bvalid[ss];
            end
        end
    end
end

////////////////////////////////////////////////////
// READ PATH
////////////////////////////////////////////////////

logic [NUM_SLAVES-1:0]               rd_busy;
logic [NUM_SLAVES-1:0][MW-1:0]       rd_owner;
logic [NUM_SLAVES-1:0][MW-1:0]       rd_rr_ptr;

logic [NUM_MASTERS-1:0]              m_rd_outstanding;
logic [NUM_SLAVES-1:0][NUM_MASTERS-1:0] rd_req;

always_comb begin
    for (int mm = 0; mm < NUM_MASTERS; mm++) begin
        m_rd_outstanding[mm] = 1'b0;
        for (int ss = 0; ss < NUM_SLAVES; ss++)
            if (rd_busy[ss] && (rd_owner[ss] == MW'(mm)))
                m_rd_outstanding[mm] = 1'b1;
    end
    for (int ss = 0; ss < NUM_SLAVES; ss++)
        for (int mm = 0; mm < NUM_MASTERS; mm++)
            rd_req[ss][mm] = m_arvalid[mm] && !m_rd_outstanding[mm] &&
                             (decode_address(m_araddr[mm]) == 3'(ss));
end

logic [NUM_SLAVES-1:0]         rd_act;
logic [NUM_SLAVES-1:0][MW-1:0] rd_gnt;

always_comb begin
    for (int ss = 0; ss < NUM_SLAVES; ss++) begin
        logic [MW:0] pick;
        pick = rr_pick(rd_req[ss], rd_rr_ptr[ss]);
        if (rd_busy[ss]) begin
            rd_act[ss] = 1'b1;
            rd_gnt[ss] = rd_owner[ss];
        end else begin
            rd_act[ss] = pick[MW];
            rd_gnt[ss] = pick[MW-1:0];
        end
    end
end

// Lock on AR handshake, release on R handshake (single beat)
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_busy   <= '0;
        rd_owner  <= '0;
        rd_rr_ptr <= '0;
    end else begin
        for (int ss = 0; ss < NUM_SLAVES; ss++) begin
            if (!rd_busy[ss] && s_arvalid[ss] && s_arready[ss]) begin
                rd_busy[ss]  <= 1'b1;
                rd_owner[ss] <= rd_gnt[ss];
            end else if (rd_busy[ss] && s_rvalid[ss] && s_rready[ss]) begin
                rd_busy[ss]   <= 1'b0;
                rd_rr_ptr[ss] <= rd_owner[ss] + MW'(1);
            end
        end
    end
end

// Slave-side routing
always_comb begin
    for (int ss = 0; ss < NUM_SLAVES; ss++) begin
        if (rd_act[ss]) begin
            s_araddr[ss]  = m_araddr[rd_gnt[ss]];
            s_arvalid[ss] = !rd_busy[ss] && m_arvalid[rd_gnt[ss]];
            s_rready[ss]  = m_rready[rd_gnt[ss]];
        end else begin
            s_araddr[ss]  = '0;
            s_arvalid[ss] = 1'b0;
            s_rready[ss]  = 1'b0;
        end
    end
end

// Master-side routing
always_comb begin
    for (int mm = 0; mm < NUM_MASTERS; mm++) begin
        m_arready[mm] = 1'b0;
        m_rvalid[mm]  = 1'b0;
        m_rdata[mm]   = '0;
        for (int ss = 0; ss < NUM_SLAVES; ss++) begin
            if (rd_act[ss] && (rd_gnt[ss] == MW'(mm))) begin
                m_arready[mm] |= !rd_busy[ss] && s_arready[ss];
                if (s_rvalid[ss]) begin
                    m_rvalid[mm] = 1'b1;
                    m_rdata[mm]  = s_rdata[ss];
                end
            end
        end
    end
end

endmodule
