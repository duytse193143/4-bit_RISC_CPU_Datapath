`timescale 1ns / 1ps
//
// CONNECTIONS
//   Calls       : alu.v (module alu)
//   Called by   : nobody - this is a testbench (top of simulation)
// =====================================================================
// FILE: tb_alu.v
// MODULE-LEVEL TEST 1: the ALU on its own (no clock needed).
// Covers every ALU operation in the project plan, plus the Zero flag
// and the Carry / no-borrow convention.
// =====================================================================
module tb_alu;

    reg  [3:0] a, b;
    reg  [2:0] alu_ctrl;
    wire [3:0] result;
    wire       carry, zero;

    integer errors = 0;
    integer tests  = 0;

    // CALLS: module alu from file alu.v
    alu DUT (.a(a), .b(b), .alu_ctrl(alu_ctrl),
             .result(result), .carry(carry), .zero(zero));

    // apply one test and compare with the expected values
    task test;
        input [8*12:1] name;
        input [3:0]    in_a, in_b;
        input [2:0]    op;
        input [3:0]    exp_result;
        input          exp_carry;
        input          exp_zero;
        begin
            a = in_a;  b = in_b;  alu_ctrl = op;
            #10;
            tests = tests + 1;
            if (result == exp_result && carry == exp_carry && zero == exp_zero)
                $display("PASS  %0s a=%b b=%b -> result=%b carry=%b zero=%b",
                         name, a, b, result, carry, zero);
            else begin
                $display("FAIL  %0s a=%b b=%b -> result=%b carry=%b zero=%b",
                         name, a, b, result, carry, zero);
                $display("      expected result=%b carry=%b zero=%b",
                         exp_result, exp_carry, exp_zero);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // The task 'test' used below is defined above in this same file.
        $display("\n===== tb_alu: ALU module test =====");
        //      name            a        b        ctrl  result   C  Z
        test("ADD 5+3     ", 4'b0101, 4'b0011, 3'd0, 4'b1000, 0, 0);
        test("ADD 15+1    ", 4'b1111, 4'b0001, 3'd0, 4'b0000, 1, 1);
        test("SUB 5-3     ", 4'b0101, 4'b0011, 3'd1, 4'b0010, 1, 0);
        test("SUB 3-5     ", 4'b0011, 4'b0101, 3'd1, 4'b1110, 0, 0);
        test("SUB 7-7     ", 4'b0111, 4'b0111, 3'd1, 4'b0000, 1, 1);
        test("AND         ", 4'b1100, 4'b1010, 3'd2, 4'b1000, 0, 0);
        test("OR          ", 4'b1100, 4'b1010, 3'd3, 4'b1110, 0, 0);
        test("XOR         ", 4'b1100, 4'b1010, 3'd4, 4'b0110, 0, 0);
        test("XOR to zero ", 4'b0110, 4'b0110, 3'd4, 4'b0000, 0, 1);
        test("NOT 0101    ", 4'b0101, 4'b0000, 3'd5, 4'b1010, 0, 0);
        test("PASS b      ", 4'b0000, 4'b1001, 3'd6, 4'b1001, 0, 0);

        if (errors == 0)
            $display("tb_alu PASSED: %0d of %0d tests OK\n", tests, tests);
        else
            $display("tb_alu FAILED: %0d of %0d tests failed\n", errors, tests);
        $finish;
    end
endmodule
