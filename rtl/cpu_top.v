// =====================================================================
// FILE: cpu_top.v
// The complete 4-bit RISC CPU with a 3-STAGE PIPELINE.
// This file only CONNECTS the blocks.
//
//   STAGE 1  IF (fetch)   : PC -> instruction memory -> IF/ID register (IR)
//   STAGE 2  ID (decode)  : control unit decodes -> ID/EX register
//   STAGE 3  EX (execute) : read registers -> operand MUX -> ALU
//                           -> data memory -> write-back MUX -> Rd,
//                           update flags, decide jumps
//
// All three stages work at the same time on three different
// instructions, so one instruction can finish every clock.
// A taken jump (decided in EX) flushes the 2 younger instructions.
//
// Instruction format (12 bits):
//   [11:8] opcode | [7:6] Rd | [5:4] Rs | [3:0] immediate / address
//
// CONNECTIONS
//   Calls       : mux.v, program_counter.v, instruction_memory.v,
//                 instruction_register.v, control_unit.v, pipeline_register.v,
//                 register_file.v, alu.v, flag_register.v, data_memory.v
//   Called by   : tb_cpu.v - instance CPU
// =====================================================================
module cpu_top #(
    parameter PROGRAM_FILE = "program.mem"   // program to run
)(
    input         clk,
    input         rst,
    // observable debug outputs (waveform viewer or FPGA LEDs)
    output [3:0]  pc_out,          // fetch address (PC)
    output [11:0] instr_out,       // instruction in the EXECUTE stage
    output [3:0]  alu_out,         // ALU result
    output [3:0]  wb_data_out,     // value written to the destination register
    output        zero_out,        // Zero flag
    output        carry_out        // Carry flag
);

    // wires shared between stages
    wire        pc_sel;            // from the branch unit (EX)
    wire        flush;             // from the branch unit (EX)
    wire [3:0]  ex_imm;            // jump address (EX)

    // =================================================================
    // STAGE 1: IF - FETCH
    // =================================================================
    wire [3:0]  pc;                // fetch address
    wire [3:0]  pc_plus_1 = pc + 4'd1;
    wire [3:0]  pc_next;
    wire [11:0] fetched;           // word out of instruction memory

    // PC MUX: next address = PC + 1, or the jump address from EX
    // CALLS: module mux2 from file mux.v
    mux2 PC_MUX (
        .d0  (pc_plus_1),
        .d1  (ex_imm),
        .sel (pc_sel),
        .y   (pc_next)
    );

    // CALLS: module program_counter from file program_counter.v
    program_counter PC (
        .clk     (clk),
        .rst     (rst),
        .pc_en   (1'b1),           // fetch a new instruction every clock
        .pc_next (pc_next),
        .pc_out  (pc)
    );

    // CALLS: module instruction_memory from file instruction_memory.v
    instruction_memory #(.PROGRAM_FILE(PROGRAM_FILE)) IMEM (
        .address     (pc),
        .instruction (fetched)
    );

    // ---------------- IF/ID pipeline register (the IR) ----------------
    wire [11:0] id_instr;          // instruction now in DECODE
    wire [3:0]  id_pc;
    wire        id_valid;

    // CALLS: module instruction_register from file instruction_register.v
    instruction_register IR (
        .clk             (clk),
        .rst             (rst),
        .ir_load         (1'b1),   // load every clock
        .flush           (flush),
        .instruction_in  (fetched),
        .pc_in           (pc),
        .instruction_out (id_instr),
        .pc_out          (id_pc),
        .valid_out       (id_valid)
    );

    // =================================================================
    // STAGE 2: ID - DECODE
    // =================================================================
    wire [3:0] id_opcode = id_instr[11:8];
    wire [1:0] id_rd     = id_instr[7:6];
    wire [1:0] id_rs     = id_instr[5:4];
    wire [3:0] id_imm    = id_instr[3:0];

    wire [2:0] id_alu_ctrl;
    wire       id_alu_src_sel, id_wb_sel, id_reg_we, id_mem_we;
    wire       id_zero_we, id_carry_we, id_is_jmp, id_is_jz;

    wire       ex_is_jmp, ex_is_jz;   // from ID/EX (below)
    wire       zero_flag, carry_flag; // from the flag register (EX)

    // CALLS: module control_unit from file control_unit.v
    control_unit CU (
        // decode part
        .opcode      (id_opcode),
        .alu_ctrl    (id_alu_ctrl),
        .alu_src_sel (id_alu_src_sel),
        .wb_sel      (id_wb_sel),
        .reg_we      (id_reg_we),
        .mem_we      (id_mem_we),
        .zero_we     (id_zero_we),
        .carry_we    (id_carry_we),
        .is_jmp      (id_is_jmp),
        .is_jz       (id_is_jz),
        // branch part (EX stage)
        .ex_is_jmp   (ex_is_jmp),
        .ex_is_jz    (ex_is_jz),
        .zero_flag   (zero_flag),
        .pc_sel      (pc_sel),
        .flush       (flush)
    );

    // ---------------- ID/EX pipeline register ----------------
    wire [2:0]  ex_alu_ctrl;
    wire        ex_alu_src_sel, ex_wb_sel, ex_reg_we, ex_mem_we;
    wire        ex_zero_we, ex_carry_we;
    wire [1:0]  ex_rd, ex_rs;
    wire [3:0]  ex_pc;
    wire        ex_valid;
    wire [11:0] ex_instr;

    // CALLS: module pipeline_register from file pipeline_register.v
    pipeline_register ID_EX (
        .clk            (clk),
        .rst            (rst),
        .flush          (flush),
        .alu_ctrl_in    (id_alu_ctrl),
        .alu_src_sel_in (id_alu_src_sel),
        .wb_sel_in      (id_wb_sel),
        .reg_we_in      (id_reg_we),
        .mem_we_in      (id_mem_we),
        .zero_we_in     (id_zero_we),
        .carry_we_in    (id_carry_we),
        .is_jmp_in      (id_is_jmp),
        .is_jz_in       (id_is_jz),
        .rd_in          (id_rd),
        .rs_in          (id_rs),
        .imm_in         (id_imm),
        .pc_in          (id_pc),
        .valid_in       (id_valid),
        .instr_in       (id_instr),
        .alu_ctrl       (ex_alu_ctrl),
        .alu_src_sel    (ex_alu_src_sel),
        .wb_sel         (ex_wb_sel),
        .reg_we         (ex_reg_we),
        .mem_we         (ex_mem_we),
        .zero_we        (ex_zero_we),
        .carry_we       (ex_carry_we),
        .is_jmp         (ex_is_jmp),
        .is_jz          (ex_is_jz),
        .rd             (ex_rd),
        .rs             (ex_rs),
        .imm            (ex_imm),
        .pc             (ex_pc),
        .valid          (ex_valid),
        .instr          (ex_instr)
    );

    // =================================================================
    // STAGE 3: EX - EXECUTE (operand read, ALU, memory, write-back)
    // =================================================================
    wire [3:0] rd_value;           // qa: value of Rd
    wire [3:0] rs_value;           // qb: value of Rs
    wire [3:0] alu_b;
    wire [3:0] alu_result;
    wire       alu_zero, alu_carry;
    wire [3:0] mem_data;
    wire [3:0] wb_data;

    // ---- operand read ----
    // CALLS: module register_file from file register_file.v
    register_file RF (
        .clk (clk),
        .rst (rst),
        .ra  (ex_rd),              // port A reads Rd
        .rb  (ex_rs),              // port B reads Rs
        .wa  (ex_rd),              // result is written into Rd
        .wd  (wb_data),
        .we  (ex_reg_we),
        .qa  (rd_value),
        .qb  (rs_value)
    );

    // ---- operand MUX: B = Rs value (0) or immediate (1) ----
    // CALLS: module mux2 from file mux.v
    mux2 OPERAND_MUX (
        .d0  (rs_value),
        .d1  (ex_imm),
        .sel (ex_alu_src_sel),
        .y   (alu_b)
    );

    // ---- ALU ----
    // CALLS: module alu from file alu.v
    alu ALU (
        .a        (rd_value),
        .b        (alu_b),
        .alu_ctrl (ex_alu_ctrl),
        .result   (alu_result),
        .carry    (alu_carry),
        .zero     (alu_zero)
    );

    // ---- flags ----
    // CALLS: module flag_register from file flag_register.v
    flag_register FLAGS (
        .clk        (clk),
        .rst        (rst),
        .zero_we    (ex_zero_we),
        .carry_we   (ex_carry_we),
        .zero_in    (alu_zero),
        .carry_in   (alu_carry),
        .zero_flag  (zero_flag),
        .carry_flag (carry_flag)
    );

    // ---- memory access: address = ALU result, data = Rd ----
    // CALLS: module data_memory from file data_memory.v
    data_memory DMEM (
        .clk        (clk),
        .address    (alu_result),
        .write_data (rd_value),
        .mem_we     (ex_mem_we),
        .read_data  (mem_data)
    );

    // ---- write-back MUX: ALU result (0) or memory data (1) ----
    // CALLS: module mux2 from file mux.v
    mux2 WB_MUX (
        .d0  (alu_result),
        .d1  (mem_data),
        .sel (ex_wb_sel),
        .y   (wb_data)
    );

    // =================================================================
    // Debug outputs
    // =================================================================
    assign pc_out      = pc;
    assign instr_out   = ex_instr;
    assign alu_out     = alu_result;
    assign wb_data_out = wb_data;
    assign zero_out    = zero_flag;
    assign carry_out   = carry_flag;

endmodule
