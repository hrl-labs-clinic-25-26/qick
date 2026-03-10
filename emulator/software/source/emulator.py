# emulator/emulator.py
import json, pathlib, io, contextlib, os
from typing import Any, Dict, Optional
from qick import QickConfig

class QickEmu:
    """
    Minimal helper:
      - Load a QICK JSON config file and expose a QickConfig for program compilation.
      - Provide tiny JSON mutation helpers and persist (commit) back to disk.
      - Wrap QICK's existing print_* helpers to ALWAYS write files,
        even if that QICK version only prints to stdout.
      - Drive a Verilated mem-driven TB and plot its CSV output.
    """

    def __init__(self, qick_config_json: str):
        self.cfg_path = pathlib.Path(qick_config_json)
        self.reload()

    # load + raw dict snapshot
    def reload(self):
        self.soccfg = QickConfig(str(self.cfg_path))  # QICK object for compiling
        self._raw: Dict[str, Any] = json.loads(self.cfg_path.read_text())  # pure JSON dict

    # access underlying dict, across QICK versions
    def cfg_dict(self) -> Dict[str, Any]:
        s = self.soccfg
        if hasattr(s, "_cfg"):  # many versions
            return s._cfg
        if hasattr(s, "as_dict"):
            d = s.as_dict()
            if d is not None:
                return d
        if hasattr(s, "to_dict"):
            d = s.to_dict()
            if d is not None:
                return d
        return self._raw  # fallback snapshot

    # persist JSON to disk and re-load QickConfig
    def _save_raw(self):
        # avoid int/str key compare issues when sort_keys
        def _stringify_int_keys(o):
            if isinstance(o, dict):
                return {str(k): _stringify_int_keys(v) for k, v in o.items()}
            if isinstance(o, list):
                return [_stringify_int_keys(v) for v in o]
            return o

        clean = _stringify_int_keys(self._raw)
        self.cfg_path.write_text(json.dumps(clean, indent=2, sort_keys=True))
        self.reload()
        
    def get_config_value(self, path_str: str) -> Any:
        """
        Get a value from the raw config dict using a dot-separated path.
        Handles both dict keys and list indices.
        """
        parts = path_str.split('.')
        current = self._raw
        for part in parts:
            try:
                if isinstance(current, list) and part.isdigit():
                    current = current[int(part)]
                elif isinstance(current, dict):
                    current = current[part]
                else:
                    return None
            except (KeyError, IndexError, TypeError):
                return None
        return current

    def set_config_value(self, path_str: str, value: Any):
        """
        Set a value in the raw config dict using a dot-separated path.
        Handles both dict keys and list indices, creating nested paths as needed.
        """
        parts = path_str.split('.')
        key = parts.pop()
        current = self._raw

        for part in parts:
            if isinstance(current, list) and part.isdigit():
                idx = int(part)
                while len(current) <= idx:
                    current.append({})
                current = current[idx]
            elif isinstance(current, dict):
                current = current.setdefault(part, {})
            else:
                raise TypeError(f"Config path mismatch at '{part}'.")

        if isinstance(current, list) and key.isdigit():
            idx = int(key)
            while len(current) <= idx:
                current.append(None)
            current[idx] = value
        elif isinstance(current, dict):
            current[key] = value
        else:
            raise TypeError(f"Config path mismatch at final key '{key}'.")

    def commit(self):
        """Persist JSON to disk and refresh self.soccfg for program compilation."""
        self._save_raw()

    # file writers that ALWAYS produce a file using QICK's print_* helpers
    @staticmethod
    def _capture_to_file(fn, out_path, *args, **kwargs):
        out_path = pathlib.Path(out_path)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            # Some QICK versions accept a filename directly:
            fn(str(out_path), *args, **kwargs)
        except TypeError:
            # Others only print to stdout; capture and write it:
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                fn(*args, **kwargs)
            out_path.write_text(buf.getvalue())

    def export_pmem_hex(self, prog, path="tb_mem/pmem.mem"):
        self._capture_to_file(prog.print_pmem2hex, path)

    def export_dmem_hex(self, prog, path="tb_mem/dmem.mem"):
        if hasattr(prog, "print_dmem2hex"):
            self._capture_to_file(prog.print_dmem2hex, path)

    def export_wmem_hex(self, prog, stem="tb_mem/wmem"):
        if hasattr(prog, "print_wmem2hex"):
            try:
                # many versions support a stem
                prog.print_wmem2hex(stem=str(stem))
            except TypeError:
                # fallback to capture stdout in a single file
                self._capture_to_file(prog.print_wmem2hex, f"{stem}.mem")

    def export_sgmem(self, prog, ch: int, prefix="tb_mem/sgmem_ch"):
        # prefer the file_prefix+gen_file path if available
        try:
            prog.print_sg_mem(sg_idx=ch, gen_file=True, file_prefix=f"{prefix}{ch}")
        except TypeError:
            # fallback: capture to one file
            self._capture_to_file(prog.print_sg_mem, f"{prefix}{ch}.mem",
                                  sg_idx=ch, gen_file=True)

    def export_all(self, prog, outdir="tb_mem", sg_channels=None, skip_empty_dmem=True):
        """
        Write PMEM, DMEM (if present), WMEM, and SGMEM for channels.
        DMEM is often zero; you can skip if you want.
        """
        outdir = pathlib.Path(outdir)
        outdir.mkdir(parents=True, exist_ok=True)

        self.export_pmem_hex(prog, outdir / "pmem.mem")
        if not skip_empty_dmem or hasattr(prog, "print_dmem2hex"):
            self.export_dmem_hex(prog, outdir / "dmem.mem")
        self.export_wmem_hex(prog, stem=str(outdir / "wmem"))

        if sg_channels is None:
            gens = self._raw.get("gens", [])
            sg_channels = range(len(gens))
        for ch in sg_channels:
            self.export_sgmem(prog, ch, prefix=str(outdir / "sgmem_ch"))

        return str(outdir.resolve())
    
    def print_config(self, path_str: Optional[str] = None):
        """
        prints the current internal config, or a specific part of it.

        Parameters:
        path_str (str, optional): A dot-separated path (e.g., "gens.0"). 
                                  If None, prints the entire config.
        """
        data_to_print = self._raw
        
        if path_str:
            data_to_print = self.get_config_value(path_str)
            if data_to_print is None:
                print(f"--- Config path not found: {path_str} ---")
                return

        # Pretty-print the data
        try:
            print(json.dumps(data_to_print, indent=2))
        except TypeError as e:
            # Fallback for complex types json can't handle
            print(f"--- Could not JSON-serialize config (error: {e}) ---")
            import pprint
            pprint.pprint(data_to_print)

#  generic helpers for running a Verilated mem-driven TB and plotting its CSV 
def _run_verilated_mem_tb(
    self,
    mem_file,
    verilog_dir=None,
    top_module="dac_top_tb_mem",
    sources=("dac_top_tb_mem.sv", "dac_top.sv", "dac.sv"),
    build_dir="build_tb_mem",
    log_csv_name="top_dac_mem.csv",
    mem_filename_in_tb="stimulus.mem",
    enable_wave=False,
    extra_verilator_args=None,
    verbose=True,
):
    """
    Compile & run a memory-driven ($readmemh) testbench via Verilator and return the CSV path.
    """
    import os, sys, shutil, subprocess
    from pathlib import Path

    verilog_dir = Path(verilog_dir) if verilog_dir is not None else Path.cwd()
    build_dir = Path(build_dir)
    build_dir.mkdir(parents=True, exist_ok=True)

    # Resolve sources relative to verilog_dir
    src_paths = [verilog_dir / s for s in sources]
    for sp in src_paths:
        if not sp.exists():
            raise FileNotFoundError(f"Verilog source not found: {sp}")

    # Ensure Verilator is available
    verilator = shutil.which("verilator") or "/opt/homebrew/bin/verilator"
    if not shutil.which("verilator") and not Path(verilator).exists():
        raise FileNotFoundError("verilator not found in PATH (also tried /opt/homebrew/bin/verilator).")

    # Provide the mem file under the exact name the TB expects
    mem_file = Path(mem_file)
    if not mem_file.exists():
        raise FileNotFoundError(f"mem_file not found: {mem_file}")
    target_mem = build_dir / mem_filename_in_tb
    try:
        if target_mem.exists() or target_mem.is_symlink():
            target_mem.unlink()
        target_mem.symlink_to(mem_file.resolve())
    except Exception:
        shutil.copy2(mem_file, target_mem)

    # Verilator compile
    exe_name = f"V{top_module}"
    cmd = [
        str(verilator),
        "--binary",
        "-sv",
        "-Wall",
        "-Mdir", str(build_dir),
        "--top-module", top_module,
    ]
    if enable_wave:
        cmd += ["--trace-fst"]
    if extra_verilator_args:
        cmd += list(extra_verilator_args)
    cmd += [str(p) for p in src_paths]

    if verbose:
        print("$", " ".join(cmd))
    try:
        subprocess.run(cmd, check=True, cwd=verilog_dir)
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Verilator compile failed (exit {e.returncode}).") from e

    # Locate produced executable (absolute path)
    candidates = [
        build_dir / exe_name,
        build_dir / f"{exe_name}.exe",
    ]
    sim_path = next((p for p in candidates if p.exists()), None)
    if sim_path is None:
        # Fallback: search recursively (some versions may tuck it elsewhere under -Mdir)
        for p in build_dir.rglob(f"V{top_module}*"):
            if p.is_file() and os.access(p, os.X_OK):
                sim_path = p
                break
    if sim_path is None:
        raise FileNotFoundError(
            f"Verilator binary not found under {build_dir} — expected something like '{exe_name}'."
        )

    if verbose:
        print(f"$ (cd {build_dir} && ./{sim_path.name})")
    try:
        # IMPORTANT: Run via absolute path (no cwd) to avoid double-prefix issues
        subprocess.run([f"./{sim_path.name}"], check=True, cwd=build_dir)
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Simulation run failed (exit {e.returncode}).") from e
    out_csv = build_dir / log_csv_name
    if not out_csv.exists():
        raise FileNotFoundError(f"Expected CSV not found: {out_csv} (did the TB write LOG_FILE?)")
    if verbose:
        print(f"[ok] Wrote {out_csv}")
    return out_csv


def _plot_tb_csv(
    self,
    csv_path,
    time_col="time_ps",
    value_cols=("aout_active",),
    expected_col="expected_out",
    time_unit="us",
    labels=None,
    save_path=None,
    show=True,
):
    """
    Plot one or more value columns vs time from a CSV produced by a Verilated TB.

    Parameters
    ----------
    csv_path : path-like
        Path to the CSV to plot.
    time_col : str
        Column name for time in picoseconds (default: "time_ps").
    value_cols : tuple[str, ...]
        One or more column names to plot on the y-axis (default: ("aout_active",)).
    expected_col : str
        Optional expected/ground-truth column to overlay (dashed) if present.
    time_unit : {'ps','ns','us','ms'}
        Unit to convert time axis to for readability (default: 'us').
    labels : dict[str,str] | None
        Optional mapping from column name to legend label.
    save_path : path-like | None
        If provided, save the plot to this path (png/pdf/etc.).
    show : bool
        If True (default), display the figure; otherwise close after saving.
    """
    import csv, math
    from pathlib import Path
    import matplotlib.pyplot as plt

    csv_path = Path(csv_path)
    if not csv_path.exists():
        raise FileNotFoundError(f"CSV not found: {csv_path}")

    # Load rows
    with csv_path.open(newline="") as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    if not rows:
        raise ValueError("CSV appears to be empty.")

    # Build arrays
    def parse_float(s, default=float("nan")):
        try:
            return float(s)
        except Exception:
            return default

    times_ps = [parse_float(r.get(time_col, "")) for r in rows]
    series = {c: [parse_float(r.get(c, "")) for r in rows] for c in value_cols}
    exp_vals = [parse_float(r.get(expected_col, "")) for r in rows] if expected_col else None

    unit_scale = {"ps": 1.0, "ns": 1e-3, "us": 1e-6, "ms": 1e-9}
    if time_unit not in unit_scale:
        raise ValueError("time_unit must be one of: 'ps','ns','us','ms'")
    t = [v * unit_scale[time_unit] for v in times_ps]

    plt.figure()
    for c in value_cols:
        lab = (labels or {}).get(c, c)
        plt.plot(t, series[c], label=lab)
    if exp_vals and all(not math.isnan(x) for x in exp_vals):
        lab = (labels or {}).get(expected_col, expected_col or "expected")
        plt.plot(t, exp_vals, linestyle="--", label=lab)
    plt.xlabel(f"time [{time_unit}]")
    plt.ylabel("value")
    plt.title("Testbench output vs time")
    plt.grid(True, which="both", linestyle=":")
    plt.legend()
    if save_path is not None:
        sp = Path(save_path)
        sp.parent.mkdir(parents=True, exist_ok=True)
        plt.savefig(sp, bbox_inches="tight", dpi=150)
    if show:
        plt.show()
    else:
        plt.close()

# Bind helpers as methods on the existing class
QickEmu.run_verilated_mem_tb = _run_verilated_mem_tb
QickEmu.plot_tb_csv = _plot_tb_csv
