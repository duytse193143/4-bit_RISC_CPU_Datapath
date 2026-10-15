# 4-Bit RISC CPU with a 3-Stage Pipeline (Verilog HDL)

A complete 4-bit RISC-style processor written in Verilog at the Register-Transfer Level, organised as a 3-stage **IF / ID / EX** pipeline. The CPU was verified with self-checking testbenches (**44 / 44 CPU-level checks passed, 0 errors**) and implemented in AMD Vivado on an Artix-7 **xc7a35tcpg236-1** FPGA.

| | |
| --- | --- |
| **Author** | Tran Duy (SE193143) |
| **Course** | [Course code / name] |
| **Instructor** | [Instructor name] |
| **Tools** | AMD Vivado [version], Vivado Simulator (XSim) |
| **Target device** | Artix-7 xc7a35tcpg236-1 [board name] |

---

## Features

- **4-bit datapath**: registers, ALU and data memory are all 4 bits wide.
- **12-bit fixed-length instructions** with 12 instructions: arithmetic, logic, data movement and control flow.
- **4 general-purpose registers** (R0–R3), with 2 combinational read ports and 1 synchronous write port.
- **Harvard memory**: 16 × 12-bit instruction ROM and 16 × 4-bit data RAM.
- **3-stage pipeline**: completes 1 instruction per clock (CPI = 1) after a 2-cycle fill.
- **Hardwired control**: a combinational decoder with safe defaults, so no latches and no FSM.
- **Zero and Carry flags**: after SUB, Carry = 1 means no borrow.
- **Hazard-free by construction**: no forwarding or stall logic is needed. A taken jump costs 2 cycles.

## Instruction Set

Instruction format (12 bits):

```
 11      8   7   6   5   4   3       0
+---------+-------+-------+-----------+
| opcode  |  Rd   |  Rs   | imm/addr  |
+---------+-------+-------+-----------+
```

| Opcode | Instruction | Operation | Flags updated |
| --- | --- | --- | --- |
| 0000 | `ADD Rd, Rs` | Rd ← Rd + Rs | Zero, Carry |
| 0001 | `SUB Rd, Rs` | Rd ← Rd − Rs (Carry = no borrow) | Zero, Carry |
| 0010 | `AND Rd, Rs` | Rd ← Rd AND Rs | Zero |
| 0011 | `OR Rd, Rs` | Rd ← Rd OR Rs | Zero |
| 0100 | `XOR Rd, Rs` | Rd ← Rd XOR Rs | Zero |
| 0101 | `NOT Rd` | Rd ← NOT Rd | Zero |
| 0110 | `LDI Rd, imm` | Rd ← imm[3:0] | – |
| 0111 | `MOV Rd, Rs` | Rd ← Rs | – |
| 1000 | `LOAD Rd, addr` | Rd ← data_memory[addr] | – |
| 1001 | `STORE Rd, addr` | data_memory[addr] ← Rd | – |
| 1010 | `JMP addr` | PC ← addr | – |
| 1011 | `JZ addr` | If Zero = 1, PC ← addr | – |
| 1100–1111 | *(reserved)* | No operation (NOP) | – |

Example: `ADD R1, R2` → `0000 01 10 0000` = `0x060`

## Architecture

```
        STAGE 1: IF              STAGE 2: ID                 STAGE 3: EX
  +------------------------+   +--------------+   +------------------------------------+
  | PC_MUX -> PC -> IMEM   |-->| Control Unit |-->| Register File -> OPERAND_MUX -> ALU|
  |   ^        |           | I |  (decoder)   | I |        |                  |        |
  |   |      PC + 1        | F |              | D |        |                DMEM       |
  |   |                    | / |              | / |        |                  |        |
  |   +---- jump target ---| I |              | E |      WB_MUX <------------+         |
  |        (pc_sel)        | D |              | X |        |   (write-back to Rd)      |
  +------------------------+   +--------------+   |      FLAGS (Z, C)   Branch unit    |
                                                  +------------------------------------+
```

| Stage | Module | Function |
| --- | --- | --- |
| IF | `program_counter` | 4-bit PC register with synchronous reset |
| IF | `instruction_memory` | 16 × 12-bit ROM, combinational read, loaded from a `.mem` file |
| IF | `mux` (PC_MUX) | Selects PC + 1 or the jump target |
| IF/ID | `instruction_register` | Pipeline register; `flush` turns it into a bubble |
| ID | `control_unit` | Decodes the opcode into control signals; the branch unit drives `pc_sel` and `flush` |
| ID/EX | `pipeline_register` | Carries the control word, register fields and immediate into EX |
| EX | `register_file` | 4 × 4-bit registers: 2 combinational reads, 1 clocked write |
| EX | `mux` (OPERAND_MUX) | ALU operand B: Rs or the immediate |
| EX | `alu` | Adder/subtractor, logic unit and zero detector |
| EX | `data_memory` | 16 × 4-bit RAM: combinational read, synchronous write when `mem_we` = 1 |
| EX | `mux` (WB_MUX) | Write-back source: ALU result or memory data |
| EX | `flag_register` | Zero and Carry flip-flops with separate write enables |

### Pipeline hazards

| Hazard | Resolution | Cost |
| --- | --- | --- |
| Structural | Separate instruction and data memories (Harvard) | 0 cycles |
| Data (RAW) | Registers are read in EX, one cycle after the previous write | 0 cycles |
| Control | Jump decided in EX; IF/ID and ID/EX are flushed | 2 bubbles per taken jump |

## Project Structure

> Adjust the names below if your files differ.

```
.
├── src/
│   ├── cpu_top.v               # Top level: connects all stages
│   ├── program_counter.v
│   ├── instruction_memory.v
│   ├── instruction_register.v  # IF/ID pipeline register
│   ├── control_unit.v          # Decoder + branch unit
│   ├── pipeline_register.v     # ID/EX pipeline register
│   ├── register_file.v
│   ├── alu.v                   # adder_subtractor, logic_unit, zero_detector
│   ├── data_memory.v
│   ├── mux.v                   # 2-to-1 multiplexer (used 3 times)
│   └── flag_register.v
├── sim/
│   ├── tb_cpu.v                # CPU-level self-checking testbench
│   ├── tb_alu.v
│   ├── tb_register_file.v
│   └── tb_control_unit.v
├── mem/
│   ├── program.mem             # Test 1: demonstration program
│   ├── prog_arith.mem          # Test 2: arithmetic and memory
│   ├── prog_logic.mem          # Test 3: logic operations
│   └── prog_jump.mem           # Test 4: PC and jumps
└── docs/
    ├── 4bit_RISC_CPU_Report_TranDuy_SE193143.pdf
    └── 4bit_RISC_CPU_Presentation_TranDuy_SE193143.pptx
```

## How to Run (Vivado)

1. Create a new RTL project for part **xc7a35tcpg236-1**.
2. Add every file in `src/` as **Design Sources**, every file in `sim/` as **Simulation Sources**, and the `.mem` files from `mem/` to the project.
3. **RTL Analysis**: run *Open Elaborated Design → Schematic* to view the datapath.
4. **Simulation**: set `tb_cpu` as the simulation top, then run *Run Behavioral Simulation*. The Tcl console prints a per-cycle pipeline trace and the PASS/FAIL result of each check. To test individual modules, set `tb_alu`, `tb_register_file` or `tb_control_unit` as the top instead.
5. **Synthesis & Implementation**: set `cpu_top` as the design top and run *Run Implementation*. Then open *Report Utilization*.

## Verification Results

| Test | Program | What it covers | Instructions / cycles | Checks |
| --- | --- | --- | --- | --- |
| 1 | `program.mem` | Pipeline trace, ADD / LDI / XOR, JMP loop | 5 in 7 | 6 / 6 |
| 2 | `prog_arith.mem` | ADD, SUB, STORE, LOAD, Zero / Carry | 9 in 11 | 11 / 11 |
| 3 | `prog_logic.mem` | AND, OR, XOR, NOT, MOV, LDI, Zero | 12 in 14 | 8 / 8 |
| 4 | `prog_jump.mem` | PC increment, JMP, JZ taken / not taken, flush | 10 executed | 11 / 11 |
| 5 | *(reset)* | Reset of PC, registers, flags, pipeline; no X values | – | 8 / 8 |
| | | | **Total** | **44 / 44, 0 errors** |

Key observations from the waveform:

- **Pipeline depth.** When `pc_out` = 2, the instruction from address 0 (`0x645`) is in EX. This 2-address offset matches a 3-stage pipeline.
- **CPI = 1.** One result is produced every clock: `alu_out` steps through 5, 3, 8, A, 2.
- **Flush.** On `JMP 5`, `pc_out` goes from 7 back to 5, and two bubbles (`0xC00`) follow.
- **Clean run.** The `errors` counter stays at 0 for the whole simulation.

Performance compared with the earlier 2-cycle (non-pipelined) design:

| Program | 2-cycle design | 3-stage pipeline | Speed-up |
| --- | --- | --- | --- |
| Demonstration (5 instr.) | 10 cycles | 7 cycles | 1.4× |
| Arithmetic & memory (9 instr.) | 18 cycles | 11 cycles | 1.6× |
| Logic operations (12 instr.) | 24 cycles | 14 cycles | 1.7× |

## Resource Utilization (xc7a35tcpg236-1)

| Resource | Used | Available | Utilization |
| --- | --- | --- | --- |
| Slice LUTs | 41 | 20,800 | 0.20 % |
| Slice Registers (FF) | 58 | 41,600 | 0.14 % |
| Slices | 14 | 8,150 | 0.17 % |
| Block RAM | 0 | 50 | 0 % |
| DSP48E1 | 0 | 90 | 0 % |
| Bonded IOB | 28 | 106 | 26.4 % |
| BUFGCTRL | 1 | 32 | 3.1 % |

> **Note:** The instruction ROM is initialised from a `.mem` file, so Vivado treats the program as a constant. It folds the program into logic and removes unused paths. For example, DMEM is trimmed because `program.mem` has no LOAD/STORE, and `instr_out[8]` is tied to GND. The figures above therefore describe the CPU specialised to the loaded program. The I/O count is high only because debug buses (`pc_out`, `alu_out`, `wb_data_out`, `instr_out`, flags) are routed to pins.

## Author

**Tran Duy** — Student ID: SE193143
