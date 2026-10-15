// =====================================================================
// FILE: instruction_register.v
// The IR is the IF/ID PIPELINE REGISTER: it sits between the
// FETCH stage and the DECODE stage.
//
// Interface (as in the project plan):
//   clk, rst, ir_load, instruction_in, instruction_out
// Extra pipeline signals:
//   flush           : 1 = throw the instruction away (taken jump)
//   pc_in / pc_out  : address of the instruction (to follow it in the
//                     pipeline and in the waveform)
//   valid_out       : 1 = holds a real instruction, 0 = empty (bubble)
//
// Every clock (ir_load = 1) it saves the instruction just fetched.
//
// CONNECTIONS
//   Calls       : nothing (no other modules)
//   Called by   : cpu_top.v - instance IR (the IF/ID register)
// =====================================================================
module instruction_register (
    input             clk,
    input             rst,
    input             ir_load,          // 1 = save the new instruction
    input             flush,            // 1 = replace it with a NOP
    input      [11:0] instruction_in,   // from instruction memory
    input      [3:0]  pc_in,            // its address
    output reg [11:0] instruction_out,  // to the DECODE stage
    output reg [3:0]  pc_out,
    output reg        valid_out
);
    always @(posedge clk) begin
        if (rst || flush) begin
            instruction_out <= 12'hC00;     // C00 = reserved opcode = NOP
            pc_out          <= 4'd0;
            valid_out       <= 1'b0;        // empty slot (bubble)
        end
        else if (ir_load) begin
            instruction_out <= instruction_in;
            pc_out          <= pc_in;
            valid_out       <= 1'b1;
        end
    end
endmodule
