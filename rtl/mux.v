// ===================================================
// FILE: mux.v
// 2-input, 4-bit multiplexer. A mux picks ONE of its inputs.
//   sel = 0 -> y = d0
//   sel = 1 -> y = d1
//
// The CPU uses this module three times:
//   1. Operand MUX    : ALU input B = register Rs  or immediate
//   2. Write-back MUX : register data = ALU result or memory data
//   3. PC MUX         : next PC = PC + 1  or jump address
//
// CONNECTIONS
//   Calls       : nothing (no other modules)
//   Called by   : cpu_top.v - 3 times: instances PC_MUX, OPERAND_MUX, WB_MUX
// =====================================================================
module mux2 (
    input  [3:0] d0,
    input  [3:0] d1,
    input        sel,
    output [3:0] y
);
    assign y = (sel == 1'b1) ? d1 : d0;
endmodule
