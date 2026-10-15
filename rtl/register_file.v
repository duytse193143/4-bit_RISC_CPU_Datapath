// =====================================================================
// FILE: register_file.v
// 4 general-purpose registers (R0-R3), each 4 bits wide.
//
// Interface (as in the project plan):
//   clk, rst, ra, rb, wa, wd, we, qa, qb
//
//   ra, qa : read port A  (address in, value out)  - no clock needed
//   rb, qb : read port B  (address in, value out)  - no clock needed
//   wa, wd : write address and write data          - on clock edge
//   we     : write enable (1 = write)
//
// Register numbers: R0 = 00, R1 = 01, R2 = 10, R3 = 11
//
// CONNECTIONS
//   Calls       : nothing (no other modules)
//   Called by   : cpu_top.v - instance RF
//                 tb_register_file.v - instance DUT
//                 tb_cpu.v - reads CPU.RF.r0 ... CPU.RF.r3
// =====================================================================
module register_file (
    input            clk,
    input            rst,
    input      [1:0] ra,          // read address A
    input      [1:0] rb,          // read address B
    input      [1:0] wa,          // write address
    input      [3:0] wd,          // write data
    input            we,          // write enable
    output reg [3:0] qa,          // read data A
    output reg [3:0] qb           // read data B
);
    // the four registers
    reg [3:0] r0, r1, r2, r3;

    // ---------------- WRITE (clocked) ----------------
    always @(posedge clk) begin
        if (rst) begin
            r0 <= 4'b0000;        // reset clears all registers
            r1 <= 4'b0000;
            r2 <= 4'b0000;
            r3 <= 4'b0000;
        end
        else if (we) begin
            case (wa)
                2'd0: r0 <= wd;
                2'd1: r1 <= wd;
                2'd2: r2 <= wd;
                2'd3: r3 <= wd;
            endcase
        end
    end

    // ---------------- READ PORT A (combinational) ----------------
    always @(*) begin
        case (ra)
            2'd0: qa = r0;
            2'd1: qa = r1;
            2'd2: qa = r2;
            2'd3: qa = r3;
        endcase
    end

    // ---------------- READ PORT B (combinational) ----------------
    always @(*) begin
        case (rb)
            2'd0: qb = r0;
            2'd1: qb = r1;
            2'd2: qb = r2;
            2'd3: qb = r3;
        endcase
    end
endmodule
