`timescale 1ns / 1ps
//
// CONNECTIONS
//   Calls       : cpu_top.v (module cpu_top), which uses all other design files;
//                 programs program.mem, prog_arith.mem, prog_logic.mem, prog_jump.mem
//   Called by   : nobody - this is a testbench (top of simulation)
// =====================================================================
// FILE: tb_cpu.v
// CPU-LEVEL TEST: runs programs on the complete pipelined CPU and checks
// the result after each important instruction (project plan, Section 8).
//
//   TEST 1  program.mem    : demonstration program (plan Appendix A)
//                            + a cycle-by-cycle view of the pipeline
//   TEST 2  prog_arith.mem : ADD, SUB, Carry, STORE, LOAD, Zero
//   TEST 3  prog_logic.mem : AND, OR, XOR, MOV, NOT, LDI, Zero
//   TEST 4  prog_jump.mem  : PC increment, JMP to 0100, JZ taken/not taken,
//                            flushing of wrongly fetched instructions
//   TEST 5  reset          : reset values and no unknown (X) values
// =====================================================================
module tb_cpu;

    reg clk = 0;
    reg rst = 1;
    integer errors = 0;
    integer checks = 0;
    integer cycle  = 0;            // clock cycles since reset was released
    integer i;
    reg     show_pipeline = 0;     // 1 = print every clock cycle

    always #5 clk = ~clk;          // 10 ns clock period

    wire [3:0]  pc_out, alu_out, wb_data_out;
    wire [11:0] instr_out;
    wire        zero_out, carry_out;

    // CALLS: module cpu_top from file cpu_top.v
    cpu_top #(.PROGRAM_FILE("program.mem")) CPU (
        .clk(clk), .rst(rst),
        .pc_out(pc_out), .instr_out(instr_out), .alu_out(alu_out),
        .wb_data_out(wb_data_out), .zero_out(zero_out), .carry_out(carry_out)
    );

    // count clock cycles
    always @(posedge clk) begin
        if (rst) cycle <= 0;
        else     cycle <= cycle + 1;
    end

    // -----------------------------------------------------------------
    // Trace. Printed in the middle of each clock cycle.
    //   show_pipeline = 1 : what each stage holds, every cycle
    //   otherwise         : one line when an instruction is in EXECUTE
    // CPU.RF.r1 means: inside CPU (cpu_top.v), inside RF (register_file.v),
    // the signal r1. CPU.id_instr / CPU.id_valid come from
    // instruction_register.v (instance IR); CPU.ex_instr / CPU.ex_valid
    // come from pipeline_register.v (instance ID_EX).
    // -----------------------------------------------------------------
    always @(negedge clk) begin
        if (!rst && show_pipeline) begin
            $write("   cycle %2d | IF: addr %2d | ID: ", cycle + 1, CPU.pc);
            if (CPU.id_valid) $write("%h (addr %2d)", CPU.id_instr, CPU.id_pc);
            else              $write("bubble        ");
            $write(" | EX: ");
            if (CPU.ex_valid) $write("%h (addr %2d)", CPU.ex_instr, CPU.ex_pc);
            else              $write("bubble        ");
            $display(" | R1=%b R2=%b R3=%b", CPU.RF.r1, CPU.RF.r2, CPU.RF.r3);
        end
        else if (!rst && CPU.ex_valid)
            $display("   EX addr %2d: %h | R0=%b R1=%b R2=%b R3=%b | Z=%b C=%b",
                     CPU.ex_pc, CPU.ex_instr, CPU.RF.r0, CPU.RF.r1, CPU.RF.r2, CPU.RF.r3,
                     zero_out, carry_out);
    end

    // =================================================================
    // Helper tasks
    // =================================================================

    // reset the CPU for 2 clocks
    task reset_cpu;
        begin
            rst = 1;
            @(posedge clk); @(posedge clk); #1;
            rst = 0;
        end
    endtask

    // NOTE: CPU.IMEM.mem is the array 'mem' inside instruction_memory.v
    //       (instance IMEM in cpu_top.v); CPU.DMEM.mem is the array 'mem'
    //       inside data_memory.v (instance DMEM in cpu_top.v).
    // load a program file and clear the data memory
    task load_program;
        input [8*20:1] file_name;
        begin
            rst = 1;
            for (i = 0; i < 16; i = i + 1) begin
                CPU.IMEM.mem[i] = 12'hC00;
                CPU.DMEM.mem[i] = 4'b0000;
            end
            $readmemh(file_name, CPU.IMEM.mem);
        end
    endtask

    // NOTE: CPU.ex_valid and CPU.ex_pc are outputs of pipeline_register.v
    //       (instance ID_EX in cpu_top.v).
    // wait until the instruction at address 'addr' has finished
    // (it is in EXECUTE, and the next clock edge writes its result)
    task finish;
        input [3:0] addr;
        begin
            @(negedge clk);
            while (!(CPU.ex_valid && CPU.ex_pc == addr))
                @(negedge clk);
            @(posedge clk);
            #1;
        end
    endtask

    // compare a 4-bit value
    task check;
        input [8*44:1] name;
        input [3:0]    actual;
        input [3:0]    expected;
        begin
            checks = checks + 1;
            if (actual === expected)
                $display("PASS  %0s = %b", name, actual);
            else begin
                $display("FAIL  %0s = %b (expected %b)", name, actual, expected);
                errors = errors + 1;
            end
        end
    endtask

    // compare a 1-bit value
    task check_bit;
        input [8*44:1] name;
        input          actual;
        input          expected;
        begin
            checks = checks + 1;
            if (actual === expected)
                $display("PASS  %0s = %b", name, actual);
            else begin
                $display("FAIL  %0s = %b (expected %b)", name, actual, expected);
                errors = errors + 1;
            end
        end
    endtask

    // =================================================================
    // Tests
    // =================================================================
    initial begin

        // The tasks used below (reset_cpu, load_program, finish, check,
        // check_bit) are defined above in this same file.

        // ---------------- TEST 1: demonstration program ----------------
        $display("\n===== TEST 1: demonstration program (program.mem) =====");
        show_pipeline = 1;
        reset_cpu;
        finish(2);
        check("ADD R1,R2  -> R1 (5+3)", CPU.RF.r1, 4'b1000);
        finish(4);
        check("LDI R3,1010 -> R3", CPU.RF.r3, 4'b1010);
        check("XOR R1,R3  -> R1", CPU.RF.r1, 4'b0010);
        check("R2 still 0011", CPU.RF.r2, 4'b0011);
        $display("      5 instructions finished after %0d clock cycles", cycle);
        finish(5);
        check("JMP 0101: PC (fetch address) = 5", pc_out, 4'd5);
        finish(5);
        show_pipeline = 0;
        check("JMP runs again: program loops at 5", pc_out, 4'd5);

        // ---------------- TEST 2: arithmetic and memory ----------------
        $display("\n===== TEST 2: arithmetic and memory (prog_arith.mem) =====");
        load_program("prog_arith.mem");
        reset_cpu;
        finish(2);
        check    ("ADD R1,R2 (0101+0011) -> R1", CPU.RF.r1, 4'b1000);
        check_bit("ADD: Carry", carry_out, 1'b0);
        check_bit("ADD: Zero", zero_out, 1'b0);
        finish(3);
        check    ("STORE R1,0 -> data_memory[0]", CPU.DMEM.mem[0], 4'b1000);
        finish(5);
        check    ("SUB R1,R2 (0101-0011) -> R1", CPU.RF.r1, 4'b0010);
        check_bit("SUB: Zero", zero_out, 1'b0);
        check_bit("SUB: Carry (1 = no borrow)", carry_out, 1'b1);
        finish(6);
        check    ("STORE R1,1 -> data_memory[1]", CPU.DMEM.mem[1], 4'b0010);
        finish(7);
        check    ("LOAD R0,0 -> R0", CPU.RF.r0, 4'b1000);
        finish(8);
        check    ("SUB R2,R2 -> R2", CPU.RF.r2, 4'b0000);
        check_bit("Zero flag after 0000 result", zero_out, 1'b1);
        $display("      9 instructions finished after %0d clock cycles (pipeline: 9 + 2)", cycle);

        // ---------------- TEST 3: logic, MOV, NOT, LDI ----------------
        $display("\n===== TEST 3: logic operations (prog_logic.mem) =====");
        load_program("prog_logic.mem");
        reset_cpu;
        finish(3);
        check    ("AND 1100,1010 -> R3", CPU.RF.r3, 4'b1000);
        finish(5);
        check    ("OR  1100,1010 -> R3", CPU.RF.r3, 4'b1110);
        finish(6);
        check    ("XOR 1100,1010 -> R1", CPU.RF.r1, 4'b0110);
        finish(7);
        check    ("MOV R2,R1 (R1=0110) -> R2", CPU.RF.r2, 4'b0110);
        finish(9);
        check    ("NOT 0101 -> R0", CPU.RF.r0, 4'b1010);
        finish(10);
        check    ("LDI R3,1010 -> R3", CPU.RF.r3, 4'b1010);
        finish(11);
        check    ("XOR R3,R3 -> R3", CPU.RF.r3, 4'b0000);
        check_bit("Zero flag after 0000 result", zero_out, 1'b1);
        $display("      12 instructions finished after %0d clock cycles (pipeline: 12 + 2)", cycle);

        // ---------------- TEST 4: PC increment and jumps ----------------
        $display("\n===== TEST 4: PC and jumps (prog_jump.mem) =====");
        load_program("prog_jump.mem");
        rst = 1;
        @(posedge clk); @(posedge clk); #1;
        check    ("PC after reset", pc_out, 4'd0);
        rst = 0;
        @(posedge clk); #1;
        check    ("PC increment (0 -> 1)", pc_out, 4'd1);
        finish(1);
        check    ("JMP 4: PC becomes 0100", pc_out, 4'b0100);
        check_bit("JMP flushed the ID/EX register", CPU.ex_valid, 1'b0);
        finish(5);
        check_bit("SUB R1,R1 sets Zero", zero_out, 1'b1);
        finish(6);
        check    ("JZ 9 taken: PC = 9", pc_out, 4'd9);
        finish(10);
        check_bit("ADD R3,R3 clears Zero", zero_out, 1'b0);
        finish(11);
        check    ("JZ 14 not taken: next in EX is addr 12", CPU.ex_pc, 4'd12);
        finish(13);
        check    ("R0 = 1 (JMP skipped addresses 2, 3)", CPU.RF.r0, 4'd1);
        check    ("R2 = 6 (JZ skipped 7, 8; 14 never ran)", CPU.RF.r2, 4'd6);
        check    ("Program stops at PC = 13", pc_out, 4'd13);

        // ---------------- TEST 5: reset and unknown values ----------------
        $display("\n===== TEST 5: reset =====");
        rst = 1;
        @(posedge clk); #1;
        check    ("PC after reset", pc_out, 4'd0);
        check    ("R0 after reset", CPU.RF.r0, 4'd0);
        check    ("R2 after reset", CPU.RF.r2, 4'd0);
        check_bit("Zero after reset", zero_out, 1'b0);
        check_bit("Carry after reset", carry_out, 1'b0);
        check_bit("IF/ID empty after reset", CPU.id_valid, 1'b0);
        check_bit("ID/EX empty after reset", CPU.ex_valid, 1'b0);
        rst = 0;
        repeat (6) @(posedge clk);
        #1;
        // ^{...} XORs all bits together: the answer is X if ANY bit is X
        checks = checks + 1;
        if ((^{pc_out, instr_out, alu_out, wb_data_out, zero_out, carry_out,
               CPU.RF.r0, CPU.RF.r1, CPU.RF.r2, CPU.RF.r3}) === 1'bx) begin
            $display("FAIL  unknown (X) value found on key outputs");
            errors = errors + 1;
        end
        else
            $display("PASS  no unknown (X) values on key outputs or registers");

        // ---------------- summary ----------------
        $display("\n==================================================");
        if (errors == 0)
            $display("tb_cpu PASSED: %0d of %0d checks OK", checks, checks);
        else
            $display("tb_cpu FAILED: %0d of %0d checks failed", errors, checks);
        $display("==================================================\n");
        $finish;
    end
endmodule
