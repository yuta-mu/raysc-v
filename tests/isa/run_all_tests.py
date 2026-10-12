#!/usr/bin/env python3
import glob
import os
import subprocess
import sys

RTL_DIR = "../../hw/rtl"
TB_FILE = "../../hw/tb/tb_riscv_test.v"
HEX_DIR = "hex"
TOP_SIM = "sim.vvp"

print("=== 1. Compiling Verilog with iverilog ===")
compile_cmd = [
    "iverilog",
    "-g2012",
    f"-I{RTL_DIR}",
    "-o", TOP_SIM,
    TB_FILE,
] + glob.glob(f"{RTL_DIR}/*.sv")

if subprocess.run(compile_cmd).returncode != 0:
    print("[ERROR] Compilation failed.")
    sys.exit(1)

hex_files = sorted(glob.glob(f"{HEX_DIR}/*.hex"))
if not hex_files:
    print(f"[ERROR] No hex files found in {HEX_DIR}/")
    sys.exit(1)

print(f"\n=== 2. Running {len(hex_files)} tests ===")
passed = []
failed = []
timeouts = []

for hex_path in hex_files:
    test_name = os.path.splitext(os.path.basename(hex_path))[0]

    proc = subprocess.run(
        ["vvp", TOP_SIM, f"+HEX={hex_path}"],
        capture_output=True,
        text=True,
    )
    output = proc.stdout + proc.stderr

    if "RESULT: PASS" in output or "[PASS]" in output:
        print(f"[\033[32mPASS\033[0m] {test_name}")
        passed.append(test_name)
    elif "RESULT: TIMEOUT" in output or "[TIMEOUT]" in output:
        print(f"[\033[33mTIMEOUT\033[0m] {test_name}")
        timeouts.append(test_name)
    else:
        print(f"[\033[31mFAIL\033[0m] {test_name}")
        failed.append(test_name)

print("\n" + "=" * 45)
print(f"TOTAL:   {len(hex_files)}")
print(f"PASSED:  \033[32m{len(passed)}\033[0m")
print(f"FAILED:  \033[31m{len(failed)}\033[0m")
print(f"TIMEOUT: \033[33m{len(timeouts)}\033[0m")
print("=" * 45)

if os.path.exists(TOP_SIM):
    os.remove(TOP_SIM)

if failed or timeouts:
    sys.exit(1)

