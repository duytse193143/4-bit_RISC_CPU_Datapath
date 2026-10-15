`timescale 1ns / 1ps
//
// CONNECTIONS
//   Calls       : control_unit.v (module control_unit)
//   Called by   : nobody - this is a testbench (top of simulation)
// =====================================================================
// FILE: tb_control_unit.v
// MODULE-LEVEL TEST 3: the control unit (no clock needed).
// Part A: decoder output for EVERY opcode, compared with the
//         control-signal truth table in the report.
// Part B: branch unit - when is a jump taken and the pipeline flushed?
// =====================================================================
module tb_control_unit;

    reg  [3:0] opcode    = 4'b0000;
    reg        ex_is_jmp = 0;
    reg        ex_is_jz  = 0;
    reg        zero_flag = 0;

    wire [2:0] alu_ctrl;
    wire       alu_src_sel, wb_sel, reg_we, mem_we;
    wire       zero_we, carry_we, is_jmp, is_jz;
    wire       pc_sel, flush;

    integer errors = 0;
    integer tests  = 0;

    // CALLS: module control_unit from file control_unit.v
    control_unit DUT (
        .opcode(opcode), .alu_ctrl(alu_ctrl), .alu_src_sel(alu_src_sel),
        .wb_sel(wb_sel), .reg_we(reg_we), .mem_we(mem_we),
        .zero_we(zero_we), .carry_we(carry_we), .is_jmp(is_jmp), .is_jz(is_jz),
        .ex_is_jmp(ex_is_jmp), .ex_is_jz(ex_is_jz), .zero_flag(zero_flag),
        .pc_sel(pc_sel), .flush(flush)
    );

    // All decoder outputs packed into one 11-bit word, in this order:
    // alu_ctrl[2:0] alu_src_sel wb_sel reg_we mem_we zero_we carry_we is_jmp is_jz
    wire [10:0] signals = {alu_ctrl, alu_src_sel, wb_sel, reg_we, mem_we,
                           zero_we, carry_we, is_jmp, is_jz};

    // check the decoder output for one opcode
    task check_op;
        input [8*6:1] name;
        input [3:0]   op;
        input [10:0]  expected;
        begin
            opcode = op;  #1;
            tests = tests + 1;
            if (signals == expected)
                $display("PASS  %0s alu=%0d src=%b wb=%b rwe=%b mwe=%b zwe=%b cwe=%b jmp=%b jz=%b",
                         name, alu_ctrl, alu_src_sel, wb_sel, reg_we, mem_we,
                         zero_we, carry_we, is_jmp, is_jz);
            else begin
                $display("FAIL  %0s got %b, expected %b", name, signals, expected);
                errors = errors + 1;
            end
        end
    endtask

    // check the branch unit for one situation
    task check_branch;
        input [8*24:1] name;
        input          jmp, jz, z;
        input          exp_pc_sel;
        begin
            ex_is_jmp = jmp;  ex_is_jz = jz;  zero_flag = z;  #1;
            tests = tests + 1;
            if (pc_sel == exp_pc_sel && flush == exp_pc_sel)
                $display("PASS  %0s pc_sel=%b flush=%b", name, pc_sel, flush);
            else begin
                $display("FAIL  %0s pc_sel=%b flush=%b (expected %b)",
                         name, pc_sel, flush, exp_pc_sel);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // The tasks 'check_op' and 'check_branch' used below are defined
        // above in this same file.
        $display("\n===== tb_control_unit: control unit test =====");
        $display("--- Part A: decoder (DECODE stage) ---");
        //          name     opcode    alu   src   wb   rwe  mwe  zwe  cwe  jmp  jz
        check_op("ADD   ", 4'b0000, {3'd0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0});
        check_op("SUB   ", 4'b0001, {3'd1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0});
        check_op("AND   ", 4'b0010, {3'd2, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0});
        check_op("OR    ", 4'b0011, {3'd3, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0});
        check_op("XOR   ", 4'b0100, {3'd4, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0});
        check_op("NOT   ", 4'b0101, {3'd5, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0});
        check_op("LDI   ", 4'b0110, {3'd6, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0});
        check_op("MOV   ", 4'b0111, {3'd6, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0});
        check_op("LOAD  ", 4'b1000, {3'd6, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0});
        check_op("STORE ", 4'b1001, {3'd6, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0});
        check_op("JMP   ", 4'b1010, {3'd0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0});
        check_op("JZ    ", 4'b1011, {3'd0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1});
        check_op("RES-C ", 4'b1100, {3'd0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0});
        check_op("RES-D ", 4'b1101, {3'd0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0});
        check_op("RES-E ", 4'b1110, {3'd0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0});
        check_op("RES-F ", 4'b1111, {3'd0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0});

        $display("--- Part B: branch unit (EXECUTE stage) ---");
        //              name                      jmp jz  Z   pc_sel
        check_branch("no jump instruction     ", 0, 0, 0, 0);
        check_branch("no jump, Zero = 1       ", 0, 0, 1, 0);
        check_branch("JMP                     ", 1, 0, 0, 1);
        check_branch("JMP (Zero = 1)          ", 1, 0, 1, 1);
        check_branch("JZ with Zero = 0        ", 0, 1, 0, 0);
        check_branch("JZ with Zero = 1        ", 0, 1, 1, 1);

        if (errors == 0)
            $display("tb_control_unit PASSED: %0d of %0d checks OK\n", tests, tests);
        else
            $display("tb_control_unit FAILED: %0d of %0d checks failed\n", errors, tests);
        $finish;
    end
endmodule
