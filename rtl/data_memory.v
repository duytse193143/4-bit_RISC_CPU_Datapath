// =====================================================================
// FILE: data_memory.v
// Data RAM: 16 words x 4 bits. Used by LOAD and STORE.
//
// Interface (as in the project plan):
//   clk, address, write_data, mem_we, read_data
//
// - Read  : any time (no clock needed)          -> LOAD
// - Write : on the clock edge when mem_we = 1    -> STORE
// It is separate from the instruction memory (Harvard organisation).
//
// CONNECTIONS
//   Calls       : nothing (no other modules)
//   Called by   : cpu_top.v - instance DMEM
//                 tb_cpu.v - reads and clears CPU.DMEM.mem
// =====================================================================
module data_memory (
    input        clk,
    input  [3:0] address,         // which word
    input  [3:0] write_data,      // data to write (STORE)
    input        mem_we,          // write enable: 1 = write
    output [3:0] read_data        // data read (LOAD)
);
    reg [3:0] mem [0:15];         // 16 words, 4 bits each
    integer i;

    // start with all words = 0 (no unknown X values)
    initial begin
        for (i = 0; i < 16; i = i + 1)
            mem[i] = 4'b0000;
    end

    // write on the clock edge
    always @(posedge clk) begin
        if (mem_we)
            mem[address] <= write_data;
    end

    // read any time
    assign read_data = mem[address];
endmodule
