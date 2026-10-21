# 8-bit ALU with FSM controller: design contract

Purpose: a small research onboarding exercise that can be explained using
introductory combinational logic, registers, and a Moore FSM. Use Verilog-2005.
The existing `rtl/smoke/` and `tb/smoke/` remain separate environment checks.

## Architecture and interfaces

`alu8` is combinational. Inputs: `operand_a[7:0]`, `operand_b[7:0]`,
`opcode[2:0]`. Outputs: `result[7:0]`, `carry`, `borrow`, `overflow`.
Every combinational output receives a default assignment; opcode decoding
uses a plain `case` statement and blocking assignments.

`alu_controller` is the public top. Inputs: `clk`, `rst`, `start`,
`operand_a[7:0]`, `operand_b[7:0]`, `opcode[2:0]`. Outputs:
`result[7:0]`, `carry`, `borrow`, `overflow`, `busy`, `done`.
It contains operand/opcode registers, one `alu8`, result/flag registers,
and a two-bit state register. Sequential assignments use `<=`.

## Operation contract

| Opcode | Operation | Result | Carry | Borrow | Signed overflow |
| --- | --- | --- | --- | --- | --- |
| 0 | ADD | low 8 bits of A+B | ninth sum bit | 0 | signed sum outside -128..127 |
| 1 | SUB | low 8 bits of A-B | 0 | unsigned A < B | signed difference outside -128..127 |
| 2 | AND | A & B | 0 | 0 | 0 |
| 3 | OR | A \| B | 0 | 0 | 0 |
| 4 | XOR | A ^ B | 0 | 0 | 0 |
| 5 | NOT | ~A | 0 | 0 | 0 |
| 6 | SHL | A << 1, zero fill | old A[7] | 0 | 0 |
| 7 | SHR | A >> 1, zero fill | old A[0] | 0 | 0 |

Arithmetic wraps modulo 256; it does not saturate. B is ignored by NOT,
SHL, and SHR. All eight binary opcodes are valid. The plain `case` default
returns zero result/flags for unmatched X/Z opcodes in simulation; this is
not a hardware invalid-opcode or unknown-detection mechanism.

## Reset and timing

`rst` is active-high synchronous, sampled on rising edges, and takes
priority over requests/results. It clears all registers and cancels work.
Inputs are synchronous to `clk`; clock-domain crossing is out of scope.

| Rising edge | State before -> after | Behavior after the edge |
| --- | --- | --- |
| N, start=1 | IDLE -> EXECUTE | latch A/B/opcode, busy=1, done=0; retain previous result/flags |
| N+1 | EXECUTE -> DONE | latch ALU result/flags; busy=1, done=1 |
| N+2 | DONE -> IDLE | busy=0, done=0; retain result/flags |
| N+3, start=1 | IDLE -> EXECUTE | earliest next acceptance |

`busy=(state!=IDLE)` and `done=(state==DONE)` are Moore outputs.
Requests while EXECUTE or DONE are ignored, without a queue. `start` is
level-sensitive at IDLE edges: holding it high causes a new acceptance
every three clocks. A producer should pulse it while busy=0, and a
synchronous consumer samples the completed result while done=1.

## Verification and scope

Self-check the full interface: eight operations, arithmetic boundaries,
signed/unsigned flag differences, input capture, result retention, busy
request rejection, one-cycle done, consecutive requests, held start,
and reset in all FSM states. Drive on falling edges and check after
rising-edge nonblocking updates. Use `$stop` with `vvp -N` on failures.
Generate `sim/alu_controller.vcd`. Keep all generated outputs under sim/.

Run Icarus simulation, Verilator RTL lint, Yosys generic synthesis, and
the pre-existing DFF smoke check. No FPGA vendor toolchain, pipelining,
variable shifts, saturation, multiplication/division, CDC, or formal flow.
