RISCV_PREFIX ?= riscv64-unknown-elf-

CC      := $(RISCV_PREFIX)gcc
AS      := $(RISCV_PREFIX)as
LD      := $(RISCV_PREFIX)ld
OBJCOPY := $(RISCV_PREFIX)objcopy
OBJDUMP := $(RISCV_PREFIX)objdump

QEMU      := qemu-system-riscv32
IVERILOG  := iverilog -g2012 -Wall -I hw/rtl
VVP       := vvp

BSP_DIR   := bsp
CRT0      := $(BSP_DIR)/crt0.S
QEMU_LINKER := $(BSP_DIR)/linker.ld
HW_LINKER   := $(BSP_DIR)/hardware.ld

ARCH          ?= rv32im
ABI           ?= ilp32
ARCH_FLAGS    := -march=$(ARCH) -mabi=$(ABI)
COMMON_CFLAGS := $(ARCH_FLAGS) -nostdlib -nostartfiles -fno-builtin -I$(BSP_DIR) -O2 -Wall
LDFLAGS       := -T $(LINKER) -m elf32lriscv -nostdlib

RTL_SRCS := hw/rtl/control.sv \
            hw/rtl/alu_control.sv \
            hw/rtl/controller.sv \
            hw/rtl/regfile.sv \
            hw/rtl/imm_gen.sv \
            hw/rtl/alu.sv \
            hw/rtl/branch_unit.sv \
            hw/rtl/datapath.sv \
			hw/rtl/multiplier.sv \
			hw/rtl/divider.sv \
            hw/rtl/cpu.sv

TB_CPU_BIN := hw/sim/sim_tb_cpu.out

.PHONY: all clean check-env run run-boot run-hello run-mandelbrot run-raytrace \
        compiler sim-hw test-% wave-% check-cpu sim-cpu sim-prog asm

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
# .c / .s -> .elf -> .bin -> .hex
# for QEMU
%.elf: %.c $(CRT0) $(QEMU_LINKER)
	@mkdir -p $(dir $@)
	$(CC) $(COMMON_CFLAGS) -DTARGET_QEMU -T $(QEMU_LINKER) $(CRT0) $< -o $@

%.elf: %.s $(QEMU_LINKER)
	@mkdir -p $(dir $@)
	$(CC) $(COMMON_CFLAGS) -DTARGET_QEMU -T $(QEMU_LINKER) $< -o $@

%.dump: %.elf
	$(OBJDUMP) -D -S $< > $@

# for hw
%.hw.elf: %.c $(CRT0) $(HW_LINKER)
	@mkdir -p $(dir $@)
	$(CC) $(COMMON_CFLAGS) -T $(HW_LINKER) $(CRT0) $< -o $@

%.hw.elf: %.s $(HW_LINKER)
	@mkdir -p $(dir $@)
	$(CC) $(COMMON_CFLAGS) -T $(HW_LINKER) $< -o $@	

# 生バイナリ抽出
%.bin: %.hw.elf
	$(OBJCOPY) -O binary $< $@

%.hex: %.bin
	python3 -c 'import sys, struct; data = open(sys.argv[1], "rb").read(); [print(f"{w:08x}") for (w,) in struct.iter_unpack("<I", data[:len(data) - (len(data) % 4)])]' $< > $@

%.hw.dump: %.hw.elf
	$(OBJDUMP) -D -S $< > $@

.SECONDARY:

# 任意のアセンブリ・バイナリの個別一括生成
# 例: make asm PROG=tests/asm/hello
asm: $(PROG).hex $(PROG).hw.dump
	@echo "Built: $(PROG).hex & $(PROG).hw.dump"

# --------------------------------------------------

TARGET ?= sw/mandelbrot/mandelbrot.elf

run: $(TARGET)
	@echo "=== Running QEMU: $< ==="
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

test-%: hw/rtl/%.sv hw/sim/tb_%.sv
	@mkdir -p hw/sim
	$(IVERILOG) -o hw/sim/sim_$*.out $^
	$(VVP) hw/sim/sim_$*.out

test-control:
	@mkdir -p hw/sim
	$(IVERILOG) -o hw/sim/sim_control.out \
		hw/rtl/control.sv \
		hw/rtl/alu_control.sv \
		hw/sim/tb_control.sv
	$(VVP) hw/sim/sim_control.out

check-cpu:
	@mkdir -p hw/sim
	$(IVERILOG) -o hw/sim/sim_cpu.out $(RTL_SRCS)

$(TB_CPU_BIN): $(RTL_SRCS) hw/sim/tb_cpu.sv
	@mkdir -p hw/sim
	$(IVERILOG) -o $@ $^

sim-cpu: $(TB_CPU_BIN)
	$(VVP) $(TB_CPU_BIN)

# 例: make sim-prog PROG=hw/sim/prog_basic
sim-prog: $(PROG).hex $(TB_CPU_BIN)
	$(VVP) $(TB_CPU_BIN) +hex=$(PROG).hex

sim-mandelbrot: sw/mandelbrot/mandelbrot.hex sw/mandelbrot/mandelbrot.hw.dump $(TB_CPU_BIN)
	$(VVP) $(TB_CPU_BIN) +hex=sw/mandelbrot/mandelbrot.hex

sim: $(TB_CPU_BIN)
	@mkdir -p hw/sim
	$(CC) $(COMMON_CFLAGS) -T $(HW_LINKER) $(if $(filter %.c,$(SRC)),$(CRT0)) $(SRC) -o hw/sim/test.hw.elf
	$(OBJCOPY) -O binary hw/sim/test.hw.elf hw/sim/test.bin
	python3 -c 'import sys, struct; data = open(sys.argv[1], "rb").read(); [print(f"{w:08x}") for (w,) in struct.iter_unpack("<I", data[:len(data) - (len(data) % 4)])]' hw/sim/test.bin > hw/sim/test.hex
	$(OBJDUMP) -D -S hw/sim/test.hw.elf > hw/sim/test.hw.dump
	$(VVP) $(TB_CPU_BIN) +hex=hw/sim/test.hex

compiler:
	$(MAKE) -C compiler

clean:
	rm -f tests/asm/*.elf tests/asm/*.hw.elf tests/asm/*.bin tests/asm/*.hex tests/asm/*.dump tests/asm/*.hw.dump
	rm -f sw/mandelbrot/*.elf sw/mandelbrot/*.hw.elf sw/mandelbrot/*.bin sw/mandelbrot/*.hex sw/mandelbrot/*.dump
	rm -f sw/raytracer/*/*.elf sw/raytracer/*/*.hw.elf sw/raytracer/*/*.bin sw/raytracer/*/*.hex sw/raytracer/*/*.dump
	rm -rf hw/sim/*.out hw/sim/*.vcd hw/sim/*.o hw/sim/*.bin hw/sim/*.hex hw/sim/*.hw.elf hw/sim/*.dump
	-$(MAKE) -C compiler clean
