CC        := riscv64-unknown-elf-gcc
OBJCOPY   := riscv64-unknown-elf-objcopy
OBJDUMP   := riscv64-unknown-elf-objdump
QEMU      := qemu-system-riscv32

BSP_DIR   := bsp
CRT0      := $(BSP_DIR)/crt0.s
LINKER    := $(BSP_DIR)/linker.ld

CFLAGS    := -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles -fno-builtin \
             -T $(LINKER) -I$(BSP_DIR) -O2 -Wall

.PHONY: all clean check-env run run-mandelbrot run-raytrace sim-hw compiler

all: run-mandelbrot

# 環境確認
check-env:
	@echo "=== Checking Tool Versions ==="
	@$(CC) --version | head -n 1
	@$(QEMU) --version | head -n 1
	@verilator --version | head -n 1
	@iverilog -V 2>&1 | head -n 1
	@ocamlc -v | head -n 1
	@echo "All tools exist and are ready."

# --------------------------------------------------
# .c のビルド
%.elf: %.c $(CRT0) $(LINKER)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(CRT0) $< -o $@

# .s のビルド: スタートアップ処理を自前で含むため crt0 は不要
%.elf: %.s $(LINKER)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $< -o $@

# ELF から Verilog 用 hex ファイルへの変換
%.hex: %.elf
	$(OBJCOPY) -O verilog $< $@

# 逆アセンブルダンプ
%.dump: %.elf
	$(OBJDUMP) -D -S $< > $@

# --------------------------------------------------

TARGET ?= sw/mandelbrot/mandelbrot.elf

.PHONY: run
run: $(TARGET)
	@echo "=== Running QEMU: $< ==="
	@echo "Press Ctrl-A then X to exit."
	$(QEMU) -M virt -bios none -kernel $< -nographic

run-boot: tests/asm/boot.elf
	$(QEMU) -M virt -bios none -kernel $< -nographic

run-hello: tests/asm/hello.elf
	$(QEMU) -M virt -bios none -kernel $< -nographic

run-mandelbrot: sw/mandelbrot/mandelbrot.elf
	$(QEMU) -M virt -bios none -kernel $< -nographic

run-raytrace: sw/raytracer/c/main.elf
	$(QEMU) -M virt -bios none -kernel $< -nographic

# --------------------------------------------------

test-sim:
	@mkdir -p hw/sim
	iverilog -o hw/sim/sim.out hw/rtl/counter.v
	vvp hw/sim/sim.out
	@echo "Simulation complete."

sim-hw:
	$(MAKE) -C hw/sim

compiler:
	$(MAKE) -C compiler

clean:
	rm -f tests/asm/*.elf tests/asm/*.hex tests/asm/*.dump
	rm -f sw/mandelbrot/*.elf sw/mandelbrot/*.hex sw/mandelbrot/*.dump
	rm -f sw/raytracer/*/*.elf sw/raytracer/*/*.hex sw/raytracer/*/*.dump
	rm -rf hw/sim/sim.out hw/sim/*.vcd
	-$(MAKE) -C compiler clean
