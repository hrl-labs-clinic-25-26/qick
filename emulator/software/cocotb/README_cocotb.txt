cocotb + Verilator scaffold for dac_top
======================================

This folder contains a ready-to-run cocotb test for `dac_top` design.

Files
-----
- `Makefile`          : cocotb entry point (invokes Verilator and runs Python test)
- `test_dac_top.py`   : Python test that clocks the DUT and drives one packed word
- (you provide) `dac_top.sv`, `dac.sv` in the SAME directory

Prereqs (macOS with Homebrew)
-----------------------------
1) Install tools:
   brew install verilator python

2) Create a venv and install cocotb:
   python3 -m venv .venv
   source .venv/bin/activate
   python -m pip install --upgrade pip
   python -m pip install cocotb

Run
---
Put `dac_top.sv` and `dac.sv` next to this Makefile, then:
   make SIM=verilator

Notes
-----
- The test assumes:
  * top module: `dac_top`
  * ports: `clk`, `s_axis_tdata[bits-1:0]`, `s_axis_tvalid`
  * output: `dac_out[N_DAC]` (unpacked array of `real`)
- It infers `N_DAC` as `len(s_axis_tdata)/16` (i.e., 16-bit per channel packed LSB-first).
  Adjust `bits_per_ch` in `test_dac_top.py` if your packing differs.
- You can force parameters via Makefile by uncommenting the `-G` flags.
- Waveforms: Verilator is invoked with `--trace-fst`. Add `$dumpfile/$dumpvars` to your SV if you want FST dumps.
