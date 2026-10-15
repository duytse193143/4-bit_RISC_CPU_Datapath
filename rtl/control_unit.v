// =====================================================================
// FILE: control_unit.v
// Hardwired control unit for the 3-stage pipeline.
//
// Interface (as in the project plan):
//   opcode, flags, alu_ctrl, reg_we, mux selects, PC controls
//
// This file contains 3 modules:
//   1. instruction_decoder : DECODE stage - turns the opcode into
//                            control signals (pure logic, no clock)
//   2. branch_unit         : EXECUTE stage - decides if a jump is taken,
//                            and if so asks the pipeline to flush
//   3. control_unit        : joins the two modules above
//
// CONNECTIONS
//   Calls       : only modules inside this same file:
//                 instruction_decoder, branch_unit
//   Called by   : cpu_top.v - instance CU
//                 tb_control_unit.v - instance DUT
// =====================================================================


// ---------------------------------------------------------------------
// MODULE 1: instruction_decoder  (used in the DECODE stage)
// Turns ON only the signals an instruction needs.
// ---------------------------------------------------------------------
module instruction_decoder (
    input      [3:0] opcode,      // instruction bits [11:8]
    output reg [2:0] alu_ctrl,    // ALU operation
    output reg       alu_src_sel, // operand MUX: 0 = Rs, 1 = immediate
    output reg       wb_sel,      // write-back MUX: 0 = ALU, 1 = memory
    output reg       reg_we,      // 1 = write register Rd
    output reg       mem_we,      // 1 = write data memory
    output reg       zero_we,     // 1 = update Zero flag
    output reg       carry_we,    // 1 = update Carry flag
    output reg       is_jmp,      // 1 = this is JMP
    output reg       is_jz        // 1 = this is JZ
);
    // ---- opcodes (project plan, Section 4) ----
    localparam ADD   = 4'b0000;
    localparam SUB   = 4'b0001;
    localparam AND   = 4'b0010;
    localparam OR    = 4'b0011;
    localparam XOR   = 4'b0100;
    localparam NOT   = 4'b0101;
    localparam LDI   = 4'b0110;
    localparam MOV   = 4'b0111;
    localparam LOAD  = 4'b1000;
    localparam STORE = 4'b1001;
    localparam JMP   = 4'b1010;
    localparam JZ    = 4'b1011;
    // 1100 - 1111 are reserved: they do nothing (NOP)

    // ---- ALU control codes (must match alu.v) ----
    localparam ALU_ADD  = 3'd0;
    localparam ALU_SUB  = 3'd1;
    localparam ALU_AND  = 3'd2;
    localparam ALU_OR   = 3'd3;
    localparam ALU_XOR  = 3'd4;
    localparam ALU_NOT  = 3'd5;
    localparam ALU_PASS = 3'd6;

    always @(*) begin
        // ---- Step 1: default = do nothing ----
        alu_ctrl    = ALU_ADD;
        alu_src_sel = 1'b0;
        wb_sel      = 1'b0;
        reg_we      = 1'b0;
        mem_we      = 1'b0;
        zero_we     = 1'b0;
        carry_we    = 1'b0;
        is_jmp      = 1'b0;
        is_jz       = 1'b0;

        // ---- Step 2: turn on what the opcode needs ----
        case (opcode)
            ADD: begin                    // Rd = Rd + Rs
                alu_ctrl = ALU_ADD;
                reg_we   = 1'b1;
                zero_we  = 1'b1;
                carry_we = 1'b1;
            end
            SUB: begin                    // Rd = Rd - Rs
                alu_ctrl = ALU_SUB;
                reg_we   = 1'b1;
                zero_we  = 1'b1;
                carry_we = 1'b1;
            end
            AND: begin                    // Rd = Rd AND Rs
                alu_ctrl = ALU_AND;
                reg_we   = 1'b1;
                zero_we  = 1'b1;
            end
            OR: begin                     // Rd = Rd OR Rs
                alu_ctrl = ALU_OR;
                reg_we   = 1'b1;
                zero_we  = 1'b1;
            end
            XOR: begin                    // Rd = Rd XOR Rs
                alu_ctrl = ALU_XOR;
                reg_we   = 1'b1;
                zero_we  = 1'b1;
            end
            NOT: begin                    // Rd = NOT Rd
                alu_ctrl = ALU_NOT;
                reg_we   = 1'b1;
                zero_we  = 1'b1;
            end
            LDI: begin                    // Rd = immediate
                alu_ctrl    = ALU_PASS;   // ALU passes operand B
                alu_src_sel = 1'b1;       // operand B = immediate
                reg_we      = 1'b1;
            end
            MOV: begin                    // Rd = Rs
                alu_ctrl = ALU_PASS;      // ALU passes operand B = Rs
                reg_we   = 1'b1;
            end
            LOAD: begin                   // Rd = data_memory[addr]
                alu_ctrl    = ALU_PASS;   // ALU passes addr to memory
                alu_src_sel = 1'b1;
                wb_sel      = 1'b1;       // write memory data into Rd
                reg_we      = 1'b1;
            end
            STORE: begin                  // data_memory[addr] = Rd
                alu_ctrl    = ALU_PASS;   // ALU passes addr to memory
                alu_src_sel = 1'b1;
                mem_we      = 1'b1;
            end
            JMP: begin                    // PC = addr
                is_jmp = 1'b1;
            end
            JZ: begin                     // if Zero = 1, PC = addr
                is_jz = 1'b1;
            end
            default: begin
                // reserved opcodes 1100-1111: do nothing
            end
        endcase
    end
endmodule


// ---------------------------------------------------------------------
// MODULE 2: branch_unit  (used in the EXECUTE stage)
// pc_sel = 1 means "jump": the PC loads the jump address, and the two
// younger instructions already in IF and ID are flushed (made NOP).
// ---------------------------------------------------------------------
module branch_unit (
    input      is_jmp,        // instruction in EX is JMP
    input      is_jz,         // instruction in EX is JZ
    input      zero_flag,     // saved Zero flag
    output reg pc_sel,        // PC MUX: 0 = PC + 1, 1 = jump address
    output     flush          // 1 = empty the IF/ID and ID/EX registers
);
    always @(*) begin
        if (is_jmp)
            pc_sel = 1'b1;                 // JMP always jumps
        else if (is_jz && zero_flag)
            pc_sel = 1'b1;                 // JZ jumps only when Zero = 1
        else
            pc_sel = 1'b0;                 // otherwise: next address
    end

    assign flush = pc_sel;                 // jump taken -> flush
endmodule


// ---------------------------------------------------------------------
// MODULE 3: control_unit (instruction_decoder + branch_unit)
// The decoder works on the instruction in DECODE; the branch unit
// works on the instruction in EXECUTE.
// ---------------------------------------------------------------------
module control_unit (
    // ---- DECODE stage ----
    input      [3:0] opcode,
    output     [2:0] alu_ctrl,
    output           alu_src_sel,
    output           wb_sel,
    output           reg_we,
    output           mem_we,
    output           zero_we,
    output           carry_we,
    output           is_jmp,
    output           is_jz,
    // ---- EXECUTE stage ----
    input            ex_is_jmp,
    input            ex_is_jz,
    input            zero_flag,
    output           pc_sel,
    output           flush
);
    // CALLS: module instruction_decoder (MODULE 1 in this same file, control_unit.v)
    instruction_decoder DECODER (
        .opcode      (opcode),
        .alu_ctrl    (alu_ctrl),
        .alu_src_sel (alu_src_sel),
        .wb_sel      (wb_sel),
        .reg_we      (reg_we),
        .mem_we      (mem_we),
        .zero_we     (zero_we),
        .carry_we    (carry_we),
        .is_jmp      (is_jmp),
        .is_jz       (is_jz)
    );

    // CALLS: module branch_unit (MODULE 2 in this same file, control_unit.v)
    branch_unit BRANCH (
        .is_jmp    (ex_is_jmp),
        .is_jz     (ex_is_jz),
        .zero_flag (zero_flag),
        .pc_sel    (pc_sel),
        .flush     (flush)
    );
endmodule
