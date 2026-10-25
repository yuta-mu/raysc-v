import re
from collections import Counter, defaultdict
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
        if sym_type in ['T', 't', 'W', 'w']:
            try:
                symbols.append((int(addr_str, 16), parts[2]))
            except ValueError:
                pass

symbols.sort(key=lambda x: x[0])

def find_function(pc_int):
    matched_name = "unknown"
    for addr, name in symbols:
        if addr <= pc_int:
            matched_name = name
        else:
            break
    return matched_name

print("2. QEMUログから関数ごとの実行命令を解析中...")
func_instr_counter = defaultdict(Counter)
func_total_counter = Counter()

# PCと命令(mnemonic)を抽出する正規表現
pc_instr_pattern = re.compile(r"^(0x[0-9a-fA-F]+):\s+[0-9a-fA-F]+\s+([a-zA-Z0-9_\.]+)")

with open(log_file, "r") as f:
    for line in f:
        match = pc_instr_pattern.match(line)
        if match:
            pc_int = int(match.group(1), 16)
            mnemonic = match.group(2)
            func_name = find_function(pc_int)
            
            func_instr_counter[func_name][mnemonic] += 1
            func_total_counter[func_name] += 1

print("\n=== 【関数別 実行命令の内訳】 ===")
for func, total in func_total_counter.most_common(10):
    print(f"\n■ {func} (総実行命令数: {total:,} 回)")
    for instr, count in func_instr_counter[func].most_common(10):
        percentage = (count / total) * 100
        print(f"   - {instr:7s} : {count:7,} 回 ({percentage:5.1f}%)")

with open("instruction_mix_report.txt", "w") as f:
    for func, total in func_total_counter.most_common():
        f.write(f"Function: {func} (Total: {total})\n")
        for instr, count in func_instr_counter[func].most_common():
            f.write(f"  {instr}: {count}\n")
        f.write("\n")

print("\n詳細レポートを 'instruction_mix_report.txt' に保存しました。")