import re
from collections import Counter
import subprocess

elf_file = "sw/raytracer/c/build/riscv/mirrors/raytracer.elf"
log_file = "qemu_exec.log"

print("1. ELFファイルからシンボルテーブルを解析中...")
nm_output = subprocess.check_output(["riscv64-unknown-elf-nm", elf_file]).decode("utf-8")

symbols = []
for line in nm_output.splitlines():
    parts = line.split()
    if len(parts) >= 3:
        addr_str = parts[0]
        sym_type = parts[1]
        name = parts[2]
        if sym_type in ['T', 't', 'W', 'w']:
            try:
                addr = int(addr_str, 16)
                symbols.append((addr, name))
            except ValueError:
                pass

symbols.sort(key=lambda x: x[0])
print(f"検出された有効な関数シンボル数: {len(symbols)}")

def find_function(pc_int):
    matched_name = "unknown"
    for addr, name in symbols:
        if addr <= pc_int:
            matched_name = name
        else:
            break
    return matched_name

print("\n2. QEMUログを読み込み、関数ごとに集計中...")
func_counter = Counter()

# "0x00001000:  ..." のような行頭のアドレスを正確にキャッチする正規表現
pc_pattern = re.compile(r"^(0x[0-9a-fA-F]+):")

matched_count = 0
with open(log_file, "r") as f:
    for line in f:
        match = pc_pattern.match(line)
        if match:
            matched_count += 1
            pc_hex = match.group(1)
            pc_int = int(pc_hex, 16)
            func_name = find_function(pc_int)
            func_counter[func_name] += 1

print(f"アドレス抽出成功件数: {matched_count:,}")

print("\n=== 【関数別 実行回数ランキング】 ===")
for func, count in func_counter.most_common(15):
    print(f"  {func}: {count:,} 回")

with open("function_execution_summary.csv", "w") as f:
    f.write("Function_Name,Execution_Count\n")
    for func, count in func_counter.most_common():
        f.write(f"{func},{count}\n")

print("\n集計完了！ 'function_execution_summary.csv' に保存しました。")
