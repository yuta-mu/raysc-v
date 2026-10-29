# =============================================================================
# RaySC-V  root Makefile            (make help で一覧)
#
# build/ はソースツリーを鏡写しにする:
#   tests/rayq/foo.rq -> build/tests/rayq/foo.s / .hex / .qemu.elf / .rtl.out ...
#
# 約束事 (docs 参照):
#   rayqc IN.rq [-O0..-O3] [--accel=off|math|isect] -o OUT.s   ... main: と定数データだけを出力
#   tools/assembler.py IN.s -o OUT.hex                         ... 起動コード付き (PC=0, sp=0x40000, jal main, ebreak)
#   hw/tb/tb_cpu.sv  +hex=FILE +uart=FILE +maxcycles=N          ... UART の 1 バイトごとに 2 桁 16 進 1 行を FILE へ書く。ebreak で $finish、超過で TIMEOUT を表示
# =============================================================================

.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
.SECONDARY:
SHELL := /bin/sh

# ---- ツール -------------------------------------------------------------------
PYTHON   ?= python3
IVERILOG ?= iverilog
VVP      ?= vvp
QEMU     ?= qemu-system-riscv32
CROSS    ?= riscv64-unknown-elf-
HOST_CC  ?= cc
CC       := $(CROSS)gcc
OBJCOPY  := $(CROSS)objcopy

# ---- 調整用 ---------------------------------------------------------------------
RAYQ_FLAGS   ?= -O0 --accel=off
MAXCYCLES    ?= 50000000
QEMU_TIMEOUT ?= 600
REF_ARGS     ?=
SRC          ?=

# ---- パス -----------------------------------------------------------------------
B        := build
RAYQC    := $(B)/compiler/rayqc
RTL_SRCS := $(wildcard hw/rtl/*.sv hw/rtl/*.v)
TB_CPU   := hw/tb/tb_cpu.sv
TB_VVP   := $(B)/sim/tb_cpu.vvp
CRT0     := bsp/common/crt0.S
QEMU_LD  := bsp/qemu/linker.ld
RVFLAGS  := -march=rv32im -mabi=ilp32 -ffreestanding -nostdlib -nostartfiles -static -O2

# ---- check の対象 ----------------------------------------------------------------
CHECK_SRCS   := $(wildcard tests/check/*.rq tests/check/*.s)
CHECK_STAMPS := $(addprefix $(B)/,$(addsuffix .check,$(basename $(CHECK_SRCS))))

# ---- RTL 単体テスト (hw/tb/tb_<name>.sv は自動登録。tb_cpu は除く) -----------------------
UNIT_TB    := $(filter-out $(TB_CPU),$(wildcard hw/tb/tb_*.sv))
UNIT_TESTS := $(patsubst hw/tb/tb_%.sv,test-%,$(UNIT_TB))

.PHONY: help smoke compiler run qemu check test ref asm asm-func clean $(UNIT_TESTS)

help:
	@echo 'make smoke                      最小動作確認: tests/hex/smoke.hex を自作コアで実行し "OK" が出るか見る'
	@echo 'make compiler                   rayqc をビルド (build/compiler/rayqc)'
	@echo 'make run  SRC=prog.rq|.c|.s|.hex 自作コア (RTL シミュレーション) で実行。出力: build/<SRC>.rtl.out'
	@echo 'make qemu SRC=prog.rq|.c|.s     QEMU で実行。出力: build/<SRC>.qemu.out'
	@echo 'make check                      tests/check/ 全件で QEMU 出力 == RTL 出力 (golden があればそれとも比較)'
	@echo 'make test                       RTL 単体テスト (hw/tb/tb_*.sv)'
	@echo 'make ref                        ホスト用 C リファレンスを実行し build/ref/golden.ppm を作る'
	@echo 'make asm [ASM_SRC=ref/qmath.h]  rv32im でコンパイル→逆アセンブル: build/asm/<名前>.s / .dis'
	@echo 'make asm-func FUNC=q16_mul       1 関数だけ asm と逆アセンブルを表示 (ASM_SRC も指定可)'
	@echo 'make clean                      build/ を削除'
	@echo 'option: RAYQ_FLAGS="-O2 --accel=math"  MAXCYCLES=N  QEMU_TIMEOUT=sec  ASM_OPT=-O0'

# ---- コンパイラ -----------------------------------------------------------------
compiler: $(RAYQC)

$(RAYQC): $(wildcard compiler/*.ml compiler/*.mll compiler/*.mly compiler/Makefile)
	$(MAKE) --no-print-directory -C compiler BUILD_DIR="$(abspath $(B))/compiler"

# .rq -> .s
$(B)/%.s: %.rq $(RAYQC)
	@mkdir -p $(@D)
	$(RAYQC) $(RAYQ_FLAGS) -o $@ $<

# ---- 自作コア向け: 手書き .hex をそのまま使う (tests/hex/*.hex。同名の .s があっても hex を優先) ---------------------------
$(B)/%.hex: %.hex
	@mkdir -p $(@D)
	cp $< $@

# ---- 自作コア向け: .s -> .hex (自作アセンブラ) -----------------------------------------
$(B)/%.hex: %.s tools/assembler.py
	@mkdir -p $(@D)
	$(PYTHON) tools/assembler.py $< -o $@

$(B)/%.hex: $(B)/%.s tools/assembler.py
	@mkdir -p $(@D)
	$(PYTHON) tools/assembler.py $< -o $@

# ---- QEMU 向け: .c / .s -> .elf (gcc) -------------------------------------------------
$(B)/%.qemu.elf: %.c $(CRT0) $(QEMU_LD)
	@mkdir -p $(@D)
	$(CC) $(RVFLAGS) -DTARGET_QEMU -T $(QEMU_LD) $(CRT0) $< -o $@

$(B)/%.qemu.elf: %.s $(CRT0) $(QEMU_LD)
	@mkdir -p $(@D)
	$(CC) $(RVFLAGS) -DTARGET_QEMU -T $(QEMU_LD) $(CRT0) $< -o $@

$(B)/%.qemu.elf: $(B)/%.s $(CRT0) $(QEMU_LD)
	@mkdir -p $(@D)
	$(CC) $(RVFLAGS) -DTARGET_QEMU -T $(QEMU_LD) $(CRT0) $< -o $@

# ---- 実行 ----------------------------------------------------------------------
# RTL シミュレーション (iverilog)
$(TB_VVP): $(RTL_SRCS) $(TB_CPU)
	@test -n "$(strip $(RTL_SRCS))" || { echo 'hw/rtl/ に RTL がありません' >&2; exit 1; }
	@mkdir -p $(@D)
	$(IVERILOG) -g2012 -Ihw/rtl -s tb_cpu -o $@ $(RTL_SRCS) $(TB_CPU)

$(B)/%.rtl.out: $(B)/%.hex $(TB_VVP)
	@mkdir -p $(@D)
	@$(VVP) $(TB_VVP) +hex=$< +uart=$@.txt +maxcycles=$(MAXCYCLES) > $@.log 2>&1; rc=$$?; \
	 if [ $$rc -ne 0 ] || grep -q TIMEOUT $@.log; then \
	   tail -n 20 $@.log; echo "RTL シミュレーション失敗: $<"; exit 1; fi
	@$(PYTHON) -c 'import sys; open(sys.argv[2],"wb").write(bytes(int(l,16) for l in open(sys.argv[1]) if l.strip()))' $@.txt $@

# QEMU (virt マシン。UART 0x10000000 の出力をそのままファイルへ)
$(B)/%.qemu.out: $(B)/%.qemu.elf
	@rm -f $@
	timeout $(QEMU_TIMEOUT) $(QEMU) -machine virt -bios none -display none -monitor none \
	    -serial file:$@ -kernel $<

ifneq ($(strip $(SRC)),)
SRC_EXT := $(suffix $(SRC))
BASE    := $(basename $(SRC))

ifeq ($(SRC_EXT),.rq)
$(B)/$(BASE).qemu.elf: $(B)/$(BASE).s $(CRT0) $(QEMU_LD)
	@mkdir -p $(@D)
	$(CC) $(RVFLAGS) -DTARGET_QEMU -T $(QEMU_LD) $(CRT0) $< -o $@

$(B)/$(BASE).hex: $(B)/$(BASE).s tools/assembler.py
	@mkdir -p $(@D)
	$(PYTHON) tools/assembler.py $< -o $@

endif

run: $(B)/$(BASE).rtl.out
	@echo 'output: $<'
qemu: $(B)/$(BASE).qemu.out
	@echo 'output: $<'
else
run qemu:
	@echo 'usage: make $@ SRC=programs/raytracer/main.rq' >&2; exit 2
endif

# ---- smoke: コアが動くかの最小確認 (QEMU・コンパイラ・アセンブラ不要) -----------------------
smoke: $(B)/tests/hex/smoke.rtl.out
	@grep HALT $<.log || true
	@printf 'OK\n' | cmp - $< \
	  || { echo 'smoke: FAIL  UART Output:'; cat $<; echo '(NG<文字>: tests/hex/smoke.s の先頭コメント参照)'; exit 1; }
	@echo 'smoke: PASS  (RV32IM)'

# ---- check: QEMU == RTL (+ golden) ------------------------------------------------
check: $(CHECK_STAMPS)
	@test -n "$(strip $(CHECK_STAMPS))" || { echo 'tests/check/ にテストがありません' >&2; exit 1; }
	@echo 'check: $(words $(CHECK_STAMPS)) 件すべて PASS'

$(B)/%.check: $(B)/%.qemu.out $(B)/%.rtl.out
	@cmp $(B)/$*.qemu.out $(B)/$*.rtl.out || { echo 'FAIL $*: QEMU != RTL'; exit 1; }
	@g=tests/golden/$(notdir $*).out; \
	 if [ -f $$g ]; then cmp $$g $(B)/$*.rtl.out || { echo 'FAIL $*: RTL != golden'; exit 1; }; fi
	@echo 'PASS $*'; touch $@

# ---- RTL 単体テスト ---------------------------------------------------------------
test: $(UNIT_TESTS)
	@echo 'RTL 単体テスト完了 ($(words $(UNIT_TESTS)) 件)'

$(UNIT_TESTS): test-%: hw/tb/tb_%.sv $(RTL_SRCS)
	@mkdir -p $(B)/sim
	$(IVERILOG) -g2012 -Ihw/rtl -s tb_$* -o $(B)/sim/tb_$*.vvp $(RTL_SRCS) $<
	$(VVP) $(B)/sim/tb_$*.vvp

# ---- C リファレンス (ホスト) --------------------------------------------------------
$(B)/ref/raytracer: ref/main.c ref/qmath.h
	@mkdir -p $(@D)
	$(HOST_CC) -std=c11 -O2 -Wall -Iref $< -o $@ -lm

$(B)/ref/golden.ppm: $(B)/ref/raytracer
	$< $(REF_ARGS) > $@

ref: $(B)/ref/golden.ppm

# ---- asm 取得: C ソース/ヘッダを rv32im でコンパイルし、.s と逆アセンブル(.dis)を得る ----------
#   make asm                        ref/qmath.h の全関数 -> build/asm/qmath.h.s / .o / .dis
#   make asm ASM_SRC=ref/main.c     任意の .c / .h
#   make asm ASM_OPT=-O0            最適化レベル (既定は RVFLAGS の -O2)。ASM_EXTRA=-fverbose-asm なども可
#   make asm-func FUNC=q16_mul      1 関数だけ .s と逆アセンブルを表示
# static inline の関数は、参照されないと出力されない。-fkeep-inline-functions で全関数を出す。
# リンクはしないので、__divdi3 などの libgcc 関数は未解決のまま (逆アセンブルでは -r の再配置として見える)。
OBJDUMP      := $(CROSS)objdump
ASM_SRC      ?= ref/qmath.h
ASM_OPT      ?=
ASM_EXTRA    ?=
FUNC         ?=
OBJDUMP_OPTS ?= -d -r
ASM_CFLAGS   := $(RVFLAGS) $(ASM_OPT) -fkeep-inline-functions \
                -fno-asynchronous-unwind-tables -fno-unwind-tables -fno-ident $(ASM_EXTRA)
ASM_OUT      := $(B)/asm/$(notdir $(ASM_SRC))

$(ASM_OUT).s: $(ASM_SRC)
	@mkdir -p $(@D)
	$(CC) $(ASM_CFLAGS) -x c -S $< -o $@

$(ASM_OUT).o: $(ASM_OUT).s
	$(CC) $(RVFLAGS) -c $< -o $@

$(ASM_OUT).dis: $(ASM_OUT).o
	$(OBJDUMP) $(OBJDUMP_OPTS) $< > $@

asm: $(ASM_OUT).s $(ASM_OUT).dis
	@echo 'asm: $(ASM_OUT).s  $(ASM_OUT).dis'

asm-func: $(ASM_OUT).s $(ASM_OUT).o
	@test -n "$(FUNC)" || { echo 'usage: make asm-func FUNC=q16_mul [ASM_SRC=ref/qmath.h]' >&2; exit 2; }
	@echo '=== $(FUNC): .s ==='
	@sed -n '/^$(FUNC):/,/^[[:space:]]*\.size[[:space:]]*$(FUNC),/p' $(ASM_OUT).s
	@echo '=== $(FUNC): 逆アセンブル ==='
	@$(OBJDUMP) $(OBJDUMP_OPTS) --disassemble=$(FUNC) $(ASM_OUT).o | sed -n '/>:$$/,$$p'

clean:
	rm -rf $(B)

