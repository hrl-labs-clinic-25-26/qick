# cocotb + Verilator: drive DUT (dac_top) purely from Python
TOPLEVEL_LANG = verilog
SIM = verilator

TOPLEVEL = dac_top                   # compile the DUT only
COCOTB_TEST_MODULES = test_dac_python  # Python test module (no .py extension)

# Your RTL (adjust paths if needed)
VERILOG_SOURCES = $(PWD)/../dac_top.sv $(PWD)/../dac.sv

# Verilator flags
VERILATOR_FLAGS += -sv --timing --trace-fst -Wall -O3 --timescale 1ps/1ps
# Optional parameter overrides
# VERILATOR_FLAGS += -Gbits=256 -GN_DAC=16

# Enable wave dumping with: make SIM=verilator WAVES=1
include $(shell cocotb-config --makefiles)/Makefile.sim
