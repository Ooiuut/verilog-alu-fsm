# 8-bit ALU with an FSM Controller

A small Verilog-2005 project for practicing combinational logic, registers,
finite state machines, and simulation.

## Design

- `rtl/alu8.v`: combinational ALU with two 8-bit operands and a 3-bit opcode.
- `rtl/alu_controller.v`: saves the inputs, runs the operation, and saves the result.
- `tb/tb_alu_controller.v`: self-checking testbench.

```text
 A, B, opcode --> input registers --> ALU --> result and flag registers
                       ^                         ^
                       |                         |
 clk, rst, start --> FSM controller -----------> busy, done
```

| Opcode | Operation |
| --- | --- |
| 0 | ADD |
| 1 | SUB |
| 2 | AND |
| 3 | OR |
| 4 | XOR |
| 5 | NOT A |
| 6 | Logical shift left by one bit |
| 7 | Logical shift right by one bit |

The result is 8 bits. `carry` reports unsigned addition carry or the bit shifted
out. `borrow` reports unsigned subtraction borrow. `overflow` reports signed
two's-complement overflow for addition and subtraction. Unused flags are zero.

## Timing

Registers update on the rising clock edge. Reset is synchronous and active high.

| Edge | Action | State after the edge | busy | done |
| --- | --- | --- | --- | --- |
| N, with start=1 while idle | Save A, B, and opcode | EXECUTE | 1 | 0 |
| N+1 | Save the result and flags | DONE | 1 | 1 |
| N+2 | Return to idle; keep the result | IDLE | 0 | 0 |

The earliest next request can be accepted at edge N+3. Requests while busy are
ignored. Holding `start` high causes a new request to be accepted whenever the
controller is idle. Reset clears all registers and cancels a pending operation.

## Run

Simulation needs Icarus Verilog (`iverilog` and `vvp`) and Make.
Surfer is used for viewing waveforms; Verilator and Yosys are used for extra checks.
On macOS these tools are available through Homebrew:

```sh
brew install icarus-verilog surfer verilator yosys
make sim      # Compile, run the testbench, and generate a VCD
make view     # Open the VCD in Surfer
make check    # Lint, simulate, synthesize, and run the separate DFF smoke test
make clean    # Remove generated files
```

The simulation uses `-g2005 -Wall`. Generated files, including
`sim/alu_controller.vcd`, are ignored by Git.

The current testbench reports:

```text
PASS: 131 output checks, 38 completed operations
```

Tests cover all operations, arithmetic boundary cases, captured inputs, result
retention, busy requests, the done pulse, held-high start, and reset in each state.
Verilator lint and Yosys synthesis checks also pass. The design has not been
tested on an FPGA.

AI assistance was used during development, including testbench generation.

More detail: [design notes](docs/alu8-design.md),
[tool setup](docs/toolchain.md), and [Chinese walkthrough](docs/walkthrough-zh.md).
