IVERILOG ?= iverilog
VVP ?= vvp
SURFER ?= surfer
VERILATOR ?= verilator
YOSYS ?= yosys
IVERILOG_FLAGS ?= -g2005 -Wall
VVP_FLAGS ?= -N
VERILATOR_FLAGS ?= --lint-only -Wall --language 1364-2005

# The ALU project is the default; the original DFF remains an explicit smoke test.
TOP ?= tb_alu_controller
RTL_TOP ?= alu_controller
RTL_SRCS ?= rtl/alu8.v rtl/alu_controller.v
TB_SRCS ?= tb/tb_alu_controller.v
WAVE_FILE ?= sim/alu_controller.vcd
WAVE_SCRIPT ?= tb/alu_controller.sucl
SYNTH_LOG ?= sim/$(RTL_TOP)_synth.log
SMOKE_CONFIG = TOP=tb_smoke_dff RTL_TOP=smoke_dff RTL_SRCS=rtl/smoke/smoke_dff.v TB_SRCS=tb/smoke/tb_smoke_dff.v WAVE_FILE=sim/smoke.vcd WAVE_SCRIPT=tb/smoke/smoke.sucl

.PHONY: all compile sim wave view lint synth check smoke smoke-check smoke-wave clean

all: sim

compile:
	mkdir -p sim
	$(IVERILOG) $(IVERILOG_FLAGS) -s $(TOP) -o sim/$(TOP).vvp $(RTL_SRCS) $(TB_SRCS)

sim: compile
	$(VVP) $(VVP_FLAGS) sim/$(TOP).vvp

wave: sim
	$(MAKE) view

view:
	@test -s "$(WAVE_FILE)" || { echo "Missing $(WAVE_FILE): run make sim first."; exit 1; }
	$(SURFER) "$(WAVE_FILE)" --command-file "$(WAVE_SCRIPT)"

# Lint and synthesis operate on synthesizable RTL only, without the testbench.
lint:
	mkdir -p sim
	$(VERILATOR) $(VERILATOR_FLAGS) --Mdir sim/verilator/$(RTL_TOP) --top-module $(RTL_TOP) $(RTL_SRCS)

synth:
	mkdir -p sim
	$(YOSYS) -Q -T -q -l $(SYNTH_LOG) -p 'read_verilog $(RTL_SRCS); hierarchy -check -top $(RTL_TOP); synth -top $(RTL_TOP); check -assert; write_verilog sim/$(RTL_TOP)_netlist.v; write_json sim/$(RTL_TOP)_netlist.json; stat'
	@echo "Synthesis passed: $(SYNTH_LOG) and sim/$(RTL_TOP)_netlist.*"

check: lint sim synth smoke

smoke:
	$(MAKE) sim $(SMOKE_CONFIG)

smoke-check:
	$(MAKE) lint sim synth $(SMOKE_CONFIG)

smoke-wave:
	$(MAKE) wave $(SMOKE_CONFIG)

clean:
	rm -rf sim
