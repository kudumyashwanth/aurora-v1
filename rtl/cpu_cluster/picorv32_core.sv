// picorv32_core.sv - FIXED & CLEAN VERSION for Aurora v1
// Simplified in-order RV32I core (no extra parameters)
// Matches frozen architecture: 100 MHz, no SMT, private L1 not modeled here

`timescale 1ns/1ps

module picorv32_core #(
    parameter [31:0] PROGADDR_RESET = 32'h0000_0000
) (
    input  logic        clk,
    input  logic        resetn,

    // Memory interface (32-bit native to bridge)
    output logic        mem_valid,
    output logic        mem_instr,
    input  logic        mem_ready,
    output logic [31:0] mem_addr,
    output logic [31:0] mem_wdata,
    output logic [ 3:0] mem_wstrb,
    input  logic [31:0] mem_rdata,

    // Interrupt interface
    input  logic [31:0] irq,
    output logic [31:0] eoi,

    // Trap
    output logic        trap
);

    ////////////////////////////////////////////////////
    // REGISTERS
    ////////////////////////////////////////////////////
    logic [31:0] cpuregs [0:31];
    logic [31:0] pc_reg;
    logic [31:0] instr;

    ////////////////////////////////////////////////////
    // STATE MACHINE
    ////////////////////////////////////////////////////
    typedef enum logic [2:0] {
        STATE_FETCH,
        STATE_DECODE,
        STATE_EXECUTE,
        STATE_MEMORY,
        STATE_WRITEBACK
    } state_t;

    state_t state, next_state;

    ////////////////////////////////////////////////////
    // INSTRUCTION DECODE
    ////////////////////////////////////////////////////
    logic [6:0] opcode;
    logic [4:0] rd, rs1, rs2;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

    always_comb begin
        opcode = instr[6:0];
        rd     = instr[11:7];
        rs1    = instr[19:15];
        rs2    = instr[24:20];
        funct3 = instr[14:12];
        funct7 = instr[31:25];

        // Immediate formats
        imm_i = {{20{instr[31]}}, instr[31:20]};
        imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
        imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
        imm_u = {instr[31:12], 12'b0};
        imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
    end

    ////////////////////////////////////////////////////
    // REGISTER FILE READ
    ////////////////////////////////////////////////////
    logic [31:0] rs1_val, rs2_val;
    always_comb begin
        rs1_val = (rs1 == 0) ? 32'h0 : cpuregs[rs1];
        rs2_val = (rs2 == 0) ? 32'h0 : cpuregs[rs2];
    end

    ////////////////////////////////////////////////////
    // ALU
    ////////////////////////////////////////////////////
    logic [31:0] alu_result;
    logic [31:0] alu_a, alu_b;

    always_comb begin
        alu_a = rs1_val;
        alu_b = (opcode == 7'b0010011) ? imm_i : rs2_val;   // I-type vs R-type

        case (opcode)
            7'b0010011, 7'b0110011: begin
                case (funct3)
                    3'b000: alu_result = (funct7[5] && opcode == 7'b0110011) ?
                                        (alu_a - alu_b) : (alu_a + alu_b); // ADD/SUB
                    3'b001: alu_result = alu_a << alu_b[4:0];               // SLL
                    3'b010: alu_result = ($signed(alu_a) < $signed(alu_b)) ? 32'd1 : 32'd0; // SLT
                    3'b011: alu_result = (alu_a < alu_b) ? 32'd1 : 32'd0;                  // SLTU
                    3'b100: alu_result = alu_a ^ alu_b;                    // XOR
                    3'b101: alu_result = (funct7[5]) ?
                                        ($signed(alu_a) >>> alu_b[4:0]) :
                                        (alu_a >> alu_b[4:0]);             // SRL/SRA
                    3'b110: alu_result = alu_a | alu_b;                    // OR
                    3'b111: alu_result = alu_a & alu_b;                    // AND
                    default: alu_result = 32'h0;
                endcase
            end
            default: alu_result = 32'h0;
        endcase
    end

    ////////////////////////////////////////////////////
    // BRANCH LOGIC
    ////////////////////////////////////////////////////
    logic branch_taken;
    always_comb begin
        branch_taken = 1'b0;
        if (opcode == 7'b1100011) begin
            case (funct3)
                3'b000: branch_taken = (rs1_val == rs2_val);               // BEQ
                3'b001: branch_taken = (rs1_val != rs2_val);               // BNE
                3'b100: branch_taken = ($signed(rs1_val) < $signed(rs2_val)); // BLT
                3'b101: branch_taken = ($signed(rs1_val) >= $signed(rs2_val)); // BGE
                3'b110: branch_taken = (rs1_val < rs2_val);                // BLTU
                3'b111: branch_taken = (rs1_val >= rs2_val);               // BGEU
            endcase
        end
    end

    ////////////////////////////////////////////////////
    // STATE & REGISTER UPDATE
    ////////////////////////////////////////////////////
    logic [31:0] next_pc;
    logic [31:0] rd_write_data;
    logic        rd_write_en;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state   <= STATE_FETCH;
            pc_reg  <= PROGADDR_RESET;
            for (int i = 0; i < 32; i++) cpuregs[i] <= 32'h0;
        end else begin
            state <= next_state;

            // PC update
            if (state == STATE_WRITEBACK)
                pc_reg <= next_pc;

            // Register writeback
            if (rd_write_en && rd != 0)
                cpuregs[rd] <= rd_write_data;

            // Instruction fetch
            if (state == STATE_FETCH && mem_ready)
                instr <= mem_rdata;
        end
    end

    ////////////////////////////////////////////////////
    // NEXT STATE LOGIC
    ////////////////////////////////////////////////////
    always_comb begin
        next_state    = state;
        mem_valid     = 1'b0;
        mem_instr     = 1'b0;
        mem_addr      = 32'h0;
        mem_wdata     = 32'h0;
        mem_wstrb     = 4'b0000;
        next_pc       = pc_reg + 4;
        rd_write_en   = 1'b0;
        rd_write_data = 32'h0;
        trap          = 1'b0;
        eoi           = 32'h0;

        case (state)
            STATE_FETCH: begin
                mem_valid = 1'b1;
                mem_instr = 1'b1;
                mem_addr  = pc_reg;
                if (mem_ready) next_state = STATE_DECODE;
            end

            STATE_DECODE: begin
                next_state = STATE_EXECUTE;
            end

            STATE_EXECUTE: begin
                case (opcode)
                    // LUI
                    7'b0110111: begin
                        rd_write_data = imm_u;
                        rd_write_en   = 1'b1;
                        next_state    = STATE_WRITEBACK;
                    end

                    // AUIPC
                    7'b0010111: begin
                        rd_write_data = pc_reg + imm_u;
                        rd_write_en   = 1'b1;
                        next_state    = STATE_WRITEBACK;
                    end

                    // JAL
                    7'b1101111: begin
                        rd_write_data = pc_reg + 4;
                        rd_write_en   = 1'b1;
                        next_pc       = pc_reg + imm_j;
                        next_state    = STATE_WRITEBACK;
                    end

                    // JALR
                    7'b1100111: begin
                        rd_write_data = pc_reg + 4;
                        rd_write_en   = 1'b1;
                        next_pc       = (rs1_val + imm_i) & ~32'h1;
                        next_state    = STATE_WRITEBACK;
                    end

                    // BRANCH
                    7'b1100011: begin
                        if (branch_taken) next_pc = pc_reg + imm_b;
                        next_state = STATE_WRITEBACK;
                    end

                    // LOAD
                    7'b0000011: begin
                        mem_valid = 1'b1;
                        mem_addr  = rs1_val + imm_i;
                        next_state = STATE_MEMORY;
                    end

                    // STORE
                    7'b0100011: begin
                        mem_valid = 1'b1;
                        mem_addr  = rs1_val + imm_s;
                        case (funct3)
                            3'b000: begin // SB
                                mem_wdata = {4{rs2_val[7:0]}};
                                mem_wstrb = 4'b0001 << (mem_addr[1:0]);
                            end
                            3'b001: begin // SH
                                mem_wdata = {2{rs2_val[15:0]}};
                                mem_wstrb = mem_addr[1] ? 4'b1100 : 4'b0011;
                            end
                            3'b010: begin // SW
                                mem_wdata = rs2_val;
                                mem_wstrb = 4'b1111;
                            end
                            default: mem_wstrb = 4'b0000;
                        endcase
                        next_state = STATE_MEMORY;
                    end

                    // ALU ops (R-type + I-type)
                    7'b0110011, 7'b0010011: begin
                        rd_write_data = alu_result;
                        rd_write_en   = 1'b1;
                        next_state    = STATE_WRITEBACK;
                    end

                    // Illegal / NOP
                    default: begin
                        next_state = STATE_WRITEBACK;
                    end
                endcase
            end

            STATE_MEMORY: begin
                if (mem_ready) next_state = STATE_WRITEBACK;
            end

            STATE_WRITEBACK: begin
                next_state = STATE_FETCH;
            end

            default: next_state = STATE_FETCH;
        endcase
    end

endmodule
