// =====================================================================
// FILE: program_counter.v
// The PC holds the address of the instruction being FETCHED (0 to 15).
//
// Interface (as in the project plan):
//   clk, rst, pc_en, pc_next, pc_out
//
// In the 3-stage pipeline a new instruction is fetched every clock,
// so pc_en is kept at 1 by cpu_top. pc_next is PC + 1, or the jump
// address when a jump is taken in the EX stage.
//
// CONNECTIONS
//   Calls       : nothing (no other modules)
//   Called by   : cpu_top.v - instance PC
// =====================================================================
module program_counter (
    input            clk,
    input            rst,
    input            pc_en,       // 1 = load pc_next
    input      [3:0] pc_next,     // the next address
    output reg [3:0] pc_out       // current fetch address
);
    always @(posedge clk) begin
        if (rst)
            pc_out <= 4'd0;       // after reset, start at address 0
        else if (pc_en)
            pc_out <= pc_next;    // go to the next address
        // if pc_en = 0, pc_out keeps its old value
    end
endmodule
