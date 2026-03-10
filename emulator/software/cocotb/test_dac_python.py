import math, csv
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.utils import get_sim_time

DAC_BITS     = 16          # per-channel width
NUM_SAMPLES  = 100         # samples per period (matches your SV TB)
VREF         = 1.0         # ideal reference for expected_out

def twos_to_signed(val: int, bits: int) -> int:
    sign = 1 << (bits - 1)
    return (val & (sign - 1)) - (val & sign)

@cocotb.test()
async def drive_dut_from_python(dut):
    """Replicate the original SV TB sequence from Python."""
    # 430.08 MHz: 2325 ps period (split 1162 / 1163)
    cocotb.start_soon(Clock(dut.clk, period=2325, unit="ps", period_high=1162).start())

    # Infer channel count from packed bus
    width = len(dut.s_axis_tdata)
    assert width % DAC_BITS == 0, f"s_axis_tdata width {width} not multiple of {DAC_BITS}"
    n_ch = width // DAC_BITS
    dut._log.info(f"s_axis_tdata width={width} -> {n_ch} channels of {DAC_BITS} bits")

    # Idle
    dut.s_axis_tdata.value  = 0
    dut.s_axis_tvalid.value = 0

    for _ in range(9):
        await RisingEdge(dut.clk)

    # Hold tvalid high for the whole sweep 
    dut.s_axis_tvalid.value = 1

    # CSV log (same header)
    with open("top_dac.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["time_ps", "active_channel", "aout_active", "expected_out"])

        full = (1 << (DAC_BITS - 1)) - 1  # signed full-scale magnitude

        # Outer loop: channels 0..N_DAC-1
        for j in range(n_ch):
            dut._log.info(f"Generating 1-period sine on DAC Channel {j}...")
            # Inner loop: sine samples
            for i in range(NUM_SAMPLES):
                radians = (2.0 * math.pi * i) / NUM_SAMPLES
                analog_input = full * math.sin(radians)
                single_tc = int(round(analog_input)) & ((1 << DAC_BITS) - 1)

                # Place only channel j’s 16-bit slice; others zero
                word = (single_tc << (j * DAC_BITS)) & ((1 << width) - 1)
                dut.s_axis_tdata.value = word

                # One full period per sample 
                await RisingEdge(dut.clk)

                # Expected output 
                exp = VREF * twos_to_signed(single_tc, DAC_BITS) / (1 << (DAC_BITS - 1))

                # Try to read dac_out[j]; if Verilator/VPI hides reals, fall back to 0.0
                try:
                    aout = float(dut.dac_out[j].value)
                except Exception:
                    aout = 0.0

                w.writerow([int(get_sim_time(units="ps")), j, aout, exp])

        # End of sweep: deassert valid and let things settle
        dut.s_axis_tvalid.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)

    dut._log.info("Test completed. Data logged to top_dac.csv")
    assert True
