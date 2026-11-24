#!/usr/bin/env python3
"""RaySC-V Vivado sweep + execution cycle evaluation table generator."""

import argparse
import csv
import os
import re
import sys


def parse_hier_cpu_util(rpt_path):
    """Extract u_cpu Total LUTs and FFs from Vivado util_hier_50mhz.rpt."""
    if not os.path.exists(rpt_path):
        return None, None
    text = open(rpt_path, encoding="utf-8", errors="replace").read()
    m = re.search(
        r"\|\s*u_cpu\s*\|\s*cpu\s*\|\s*(\d+)\s*\|\s*\d+\s*\|\s*\d+\s*\|\s*\d+\s*\|\s*(\d+)\s*\|",
        text,
    )
    if not m:
        return None, None
    return int(m.group(1)), int(m.group(2))


def parse_timing_endpoints(rpt_path):
    """Extract worst-path Source and Destination from Vivado timing_fmax.rpt."""
    if not os.path.exists(rpt_path):
        return "NA", "NA"
    text = open(rpt_path, encoding="utf-8", errors="replace").read()
    m_src = re.search(r"^\s*Source:\s+(\S+)", text, re.M)
    m_dst = re.search(r"^\s*Destination:\s+(\S+)", text, re.M)
    sp = m_src.group(1) if m_src else "NA"
    ep = m_dst.group(1) if m_dst else "NA"
    return sp, ep


def to_int(val):
    if val is None or val in ("", "NA", "null"):
        return None
    return int(float(val))


def to_float(val):
    if val is None or val in ("", "NA", "null", "FAIL"):
        return None
    return float(val)


def load_sweep_metrics(sweep_dir):
    """Load hardware metrics per config from summary.csv and report fallbacks."""
    csv_path = os.path.join(sweep_dir, "summary.csv")
    if not os.path.exists(csv_path):
        raise FileNotFoundError(f"summary.csv not found in {sweep_dir}")

    metrics = {}
    order = []
    with open(csv_path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            cfg = row["config"].strip()
            cpu_lut = to_int(row.get("cpu_lut_50m"))
            cpu_ff = to_int(row.get("cpu_ff_50m"))
            if cpu_lut is None or cpu_ff is None:
                h_lut, h_ff = parse_hier_cpu_util(
                    os.path.join(sweep_dir, cfg, "util_hier_50mhz.rpt")
                )
                if cpu_lut is None:
                    cpu_lut = h_lut
                if cpu_ff is None:
                    cpu_ff = h_ff

            sp = (row.get("crit_startpoint") or "").strip().strip('"')
            ep = (row.get("crit_endpoint") or "").strip().strip('"')
            if sp in ("", "NA", "null") or ep in ("", "NA", "null"):
                f_sp, f_ep = parse_timing_endpoints(
                    os.path.join(sweep_dir, cfg, "timing_fmax.rpt")
                )
                if sp in ("", "NA", "null"):
                    sp = f_sp
                if ep in ("", "NA", "null"):
                    ep = f_ep

            metrics[cfg] = {
                "config": cfg,
                "mode": row.get("mode", ""),
                "strategy": row.get("strategy", "default"),
                "lut_50m": to_int(row.get("lut_50m")),
                "ff_50m": to_int(row.get("ff_50m")),
                "bram_50m": to_float(row.get("bram_50m")),
                "dsp_50m": to_int(row.get("dsp_50m")),
                "cpu_lut_50m": cpu_lut,
                "cpu_ff_50m": cpu_ff,
                "wns_50m_ns": to_float(row.get("wns_50m_ns")),
                "fmax_pass_mhz": to_float(row.get("fmax_pass_mhz")),
                "est_fmax_mhz": to_float(row.get("est_fmax_mhz")),
                "crit_startpoint": sp,
                "crit_endpoint": ep,
            }
            if cfg not in order:
                order.append(cfg)
    return metrics, order


def format_hw_table(metrics, order):
    headers = [
        "Config",
        "CPU LUT",
        "CPU FF",
        "Total LUT",
        "Total FF",
        "BRAM",
        "DSP",
        "WNS@50M (ns)",
        "Fmax (MHz)",
        "Critical Path (Start -> End)",
    ]
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join(["---"] + ["---:"] * 8 + ["---"]) + " |",
    ]
    for cfg in order:
        m = metrics[cfg]
        cpu_lut = f"{m['cpu_lut_50m']:,}" if m["cpu_lut_50m"] is not None else "NA"
        cpu_ff = f"{m['cpu_ff_50m']:,}" if m["cpu_ff_50m"] is not None else "NA"
        tot_lut = f"{m['lut_50m']:,}" if m["lut_50m"] is not None else "NA"
        tot_ff = f"{m['ff_50m']:,}" if m["ff_50m"] is not None else "NA"
        bram = f"{m['bram_50m']:g}" if m["bram_50m"] is not None else "NA"
        dsp = str(m["dsp_50m"]) if m["dsp_50m"] is not None else "NA"
        wns = f"{m['wns_50m_ns']:.3f}" if m["wns_50m_ns"] is not None else "NA"
        fmax = f"{m['fmax_pass_mhz']:.2f}" if m["fmax_pass_mhz"] is not None else "FAIL"
        crit = f"`{m['crit_startpoint']}` -> `{m['crit_endpoint']}`"
        lines.append(
            f"| `{cfg}` | {cpu_lut} | {cpu_ff} | {tot_lut} | {tot_ff} | {bram} | {dsp} | {wns} | **{fmax}** | {crit} |"
        )
    return "\n".join(lines)


def build_combined_rows(metrics, cycles_csv, baseline_label, sim_clock_mhz):
    rows = []
    with open(cycles_csv, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for r in reader:
            cfg = r["hw_config"].strip()
            if cfg not in metrics:
                raise KeyError(
                    f"hw_config '{cfg}' (label '{r['label']}') not found in summary.csv"
                )
            m = metrics[cfg]
            cyc = int(r["cycles"])
            inst = int(r["instret"]) if r.get("instret", "").strip() else None
            cpi = (cyc / inst) if (inst and inst > 0) else None
            t_sim = cyc / (sim_clock_mhz * 1e6)
            fmax = m["fmax_pass_mhz"]
            t_fmax = (cyc / (fmax * 1e6)) if fmax else None
            rows.append(
                {
                    "label": r["label"].strip(),
                    "opt": (r.get("opt") or "").strip(),
                    "hw_config": cfg,
                    "cycles": cyc,
                    "instret": inst,
                    "cpi": cpi,
                    "t_sim_s": t_sim,
                    "fmax_mhz": fmax,
                    "t_fmax_s": t_fmax,
                    "cpu_lut": m["cpu_lut_50m"],
                    "dsp": m["dsp_50m"],
                }
            )

    if not rows:
        raise ValueError("cycles CSV has no data rows")

    base = None
    if baseline_label:
        for r in rows:
            if r["label"] == baseline_label:
                base = r
                break
        if base is None:
            raise ValueError(f"Baseline label '{baseline_label}' not found in {cycles_csv}")
    else:
        base = rows[0]

    for r in rows:
        r["spd_sim"] = base["t_sim_s"] / r["t_sim_s"]
        if base["t_fmax_s"] is not None and r["t_fmax_s"] is not None:
            r["spd_fmax"] = base["t_fmax_s"] / r["t_fmax_s"]
            r["spd_per_klut"] = (
                r["spd_fmax"] / (r["cpu_lut"] / 1000.0) if r["cpu_lut"] else None
            )
            r["spd_per_dsp"] = (
                r["spd_fmax"] / r["dsp"] if (r["dsp"] and r["dsp"] > 0) else None
            )
        else:
            r["spd_fmax"] = None
            r["spd_per_klut"] = None
            r["spd_per_dsp"] = None

    return rows, base["label"]


def format_combined_table(rows, sim_clock_mhz):
    headers = [
        "Label",
        "Opt",
        "HW Config",
        "Cycles",
        "CPI",
        f"Time@{sim_clock_mhz:g}M (s)",
        f"Spd@{sim_clock_mhz:g}M",
        "Fmax (MHz)",
        "Time@Fmax (s)",
        "Spd@Fmax",
        "CPU LUT",
        "DSP",
        "Spd/kLUT",
        "Spd/DSP",
    ]
    lines = [
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join(["---", "---", "---"] + ["---:"] * 11) + " |",
    ]
    for r in rows:
        cpi = f"{r['cpi']:.3f}" if r["cpi"] is not None else "-"
        fmax = f"{r['fmax_mhz']:.2f}" if r["fmax_mhz"] is not None else "FAIL"
        t_fmax = f"{r['t_fmax_s']:.2f}" if r["t_fmax_s"] is not None else "NA"
        spd_fmax = f"{r['spd_fmax']:.2f}x" if r["spd_fmax"] is not None else "NA"
        cpu_lut = f"{r['cpu_lut']:,}" if r["cpu_lut"] is not None else "NA"
        dsp = str(r["dsp"]) if r["dsp"] is not None else "NA"
        sk = f"{r['spd_per_klut']:.3f}" if r["spd_per_klut"] is not None else "NA"
        sd = f"{r['spd_per_dsp']:.3f}" if r["spd_per_dsp"] is not None else "-"
        lines.append(
            f"| {r['label']} | {r['opt'] or '-'} | `{r['hw_config']}` | "
            f"{r['cycles']:,} | {cpi} | {r['t_sim_s']:.2f} | {r['spd_sim']:.2f}x | "
            f"{fmax} | {t_fmax} | **{spd_fmax}** | {cpu_lut} | {dsp} | {sk} | {sd} |"
        )
    return "\n".join(lines)


def write_out_csv(out_csv, rows):
    os.makedirs(os.path.dirname(os.path.abspath(out_csv)), exist_ok=True)
    fieldnames = [
        "label",
        "opt",
        "hw_config",
        "cycles",
        "instret",
        "cpi",
        "t_sim_s",
        "spd_sim",
        "fmax_mhz",
        "t_fmax_s",
        "spd_fmax",
        "cpu_lut",
        "dsp",
        "spd_per_klut",
        "spd_per_dsp",
    ]
    with open(out_csv, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in rows:
            w.writerow(r)


def main():
    ap = argparse.ArgumentParser(description="RaySC-V Vivado & Cycle Evaluation Table Generator")
    ap.add_argument("--sweep-dir", default="build/vivado_sweep", help="Vivado sweep directory")
    ap.add_argument("--cycles", help="CSV with columns: label,opt,hw_config,cycles[,instret]")
    ap.add_argument("--baseline", help="Baseline label in --cycles CSV (default: first row)")
    ap.add_argument("--sim-clock-mhz", type=float, default=50.0, help="Fixed clock frequency in MHz (default: 50.0)")
    ap.add_argument("--out-csv", help="Optional path to export combined evaluation CSV")
    args = ap.parse_args()

    metrics, order = load_sweep_metrics(args.sweep_dir)

    if not args.cycles:
        print(format_hw_table(metrics, order))
        return 0

    rows, base_lbl = build_combined_rows(metrics, args.cycles, args.baseline, args.sim_clock_mhz)
    print(f"<!-- Baseline: {base_lbl}, Fixed Clock: {args.sim_clock_mhz:g} MHz -->")
    print(format_combined_table(rows, args.sim_clock_mhz))

    if args.out_csv:
        write_out_csv(args.out_csv, rows)
        print(f"\nWrote CSV: {args.out_csv}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
