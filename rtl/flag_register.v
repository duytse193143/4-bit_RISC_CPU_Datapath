// =====================================================================
// FILE: flag_register.v
// Saves the Zero and Carry flags so a later instruction (JZ) can use
// them, and so they can be observed in the waveform.
//   zero  : last arithmetic/logic result was 0000
//   carry : carry-out from ADD, or NO-BORROW from SUB
// They have separate enables because AND/OR/XOR/NOT change only Zero,
// while ADD/SUB change both Zero and Carry.
//
// CONNECTIONS
//   Calls       : nothing (no other modules)
//   Called by   : cpu_top.v - instance FLAGS
// =====================================================================
module flag_register (
    input      clk,
    input      rst,
    input      zero_we,     // 1 = save new zero
    input      carry_we,    // 1 = save new carry
    input      zero_in,     // from the ALU
    input      carry_in,    // from the ALU
    output reg zero_flag,   // saved zero
    output reg carry_flag   // saved carry
);
    always @(posedge clk) begin
        if (rst) begin
            zero_flag  <= 1'b0;
            carry_flag <= 1'b0;
        end
        else begin
            if (zero_we)  zero_flag  <= zero_in;
            if (carry_we) carry_flag <= carry_in;
        end
    end
endmodule
