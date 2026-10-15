// =====================================================================
// FILE: instruction_memory.v
// Stores the program: 16 words x 12 bits (an initialised ROM).
//
// Interface (as in the project plan):
//   address[3:0], instruction[11:0]
//
// The program is read from a text file (default: program.mem).
// Each line of the file is one instruction in hex, e.g. 645
//
// CONNECTIONS
//   Calls       : nothing (built-in $readmemh only)
//   Called by   : cpu_top.v - instance IMEM
//                 tb_cpu.v - task load_program writes CPU.IMEM.mem
// =====================================================================
module instruction_memory #(
    parameter PROGRAM_FILE = "program.mem"   // file with the program
)(
    input  [3:0]  address,        // from the PC
    output [11:0] instruction     // instruction at that address
);
    reg [11:0] mem [0:15];        // 16 words, 12 bits each
    integer i;

    initial begin
        // fill every word with C00 first (C = reserved opcode = NOP),
        // so an empty location never contains unknown (X) values
        for (i = 0; i < 16; i = i + 1)
            mem[i] = 12'hC00;
        // then load the program from the file
        $readmemh(PROGRAM_FILE, mem);
    end

    // read: output the instruction at the given address
    assign instruction = mem[address];
endmodule
