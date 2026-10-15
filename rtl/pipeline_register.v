// =====================================================================
// FILE: pipeline_register.v
// The ID/EX PIPELINE REGISTER: it sits between the DECODE stage and
// the EXECUTE stage.
//
// At every clock it copies everything the EXECUTE stage will need:
//   - the control signals made by the decoder
//   - the instruction fields: Rd, Rs, imm
//   - the instruction address and a valid bit (for tracing)
//
// flush = 1 (taken jump) or rst = 1 loads a "do nothing" instruction:
// all control signals 0, so the EXECUTE stage changes nothing.
//
// CONNECTIONS
//   Calls       : nothing (no other modules)
//   Called by   : cpu_top.v - instance ID_EX
// =====================================================================
module pipeline_register (
    input             clk,
    input             rst,
    input             flush,
    // ---- inputs from the DECODE stage ----
    input      [2:0]  alu_ctrl_in,
    input             alu_src_sel_in,
    input             wb_sel_in,
    input             reg_we_in,
    input             mem_we_in,
    input             zero_we_in,
    input             carry_we_in,
    input             is_jmp_in,
    input             is_jz_in,
    input      [1:0]  rd_in,
    input      [1:0]  rs_in,
    input      [3:0]  imm_in,
    input      [3:0]  pc_in,
    input             valid_in,
    input      [11:0] instr_in,
    // ---- outputs to the EXECUTE stage ----
    output reg [2:0]  alu_ctrl,
    output reg        alu_src_sel,
    output reg        wb_sel,
    output reg        reg_we,
    output reg        mem_we,
    output reg        zero_we,
    output reg        carry_we,
    output reg        is_jmp,
    output reg        is_jz,
    output reg [1:0]  rd,
    output reg [1:0]  rs,
    output reg [3:0]  imm,
    output reg [3:0]  pc,
    output reg        valid,
    output reg [11:0] instr
);
    always @(posedge clk) begin
        if (rst || flush) begin
            // ---- bubble: nothing will be written in EXECUTE ----
            alu_ctrl    <= 3'd0;
            alu_src_sel <= 1'b0;
            wb_sel      <= 1'b0;
            reg_we      <= 1'b0;
            mem_we      <= 1'b0;
            zero_we     <= 1'b0;
            carry_we    <= 1'b0;
            is_jmp      <= 1'b0;
            is_jz       <= 1'b0;
            rd          <= 2'd0;
            rs          <= 2'd0;
            imm         <= 4'd0;
            pc          <= 4'd0;
            valid       <= 1'b0;
            instr       <= 12'hC00;
        end
        else begin
            // ---- pass the decoded instruction on to EXECUTE ----
            alu_ctrl    <= alu_ctrl_in;
            alu_src_sel <= alu_src_sel_in;
            wb_sel      <= wb_sel_in;
            reg_we      <= reg_we_in;
            mem_we      <= mem_we_in;
            zero_we     <= zero_we_in;
            carry_we    <= carry_we_in;
            is_jmp      <= is_jmp_in;
            is_jz       <= is_jz_in;
            rd          <= rd_in;
            rs          <= rs_in;
            imm         <= imm_in;
            pc          <= pc_in;
            valid       <= valid_in;
            instr       <= instr_in;
        end
    end
endmodule
