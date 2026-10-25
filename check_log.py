log_file = "qemu_exec.log"

print("--- qemu_exec.log の最初の5行 ---")
with open(log_file, "r") as f:
    for i in range(5):
        line = f.readline()
        if not line:
            break
        print(f"[{i}] {line.strip()}")
