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
QEMU_TIMEOUT ?= 60
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

.PHONY: help smoke compiler run qemu check test ref clean $(UNIT_TESTS)

help:
	@echo 'make smoke                      最小動作確認: tests/hex/smoke.hex を自作コアで実行し "OK" が出るか見る'
	@echo 'make compiler                   rayqc をビルド (build/compiler/rayqc)'
	@echo 'make run  SRC=prog.rq|.c|.s|.hex 自作コア (RTL シミュレーション) で実行。出力: build/<SRC>.rtl.out'
	@echo 'make qemu SRC=prog.rq|.c|.s     QEMU で実行。出力: build/<SRC>.qemu.out'
	@echo 'make check                      tests/check/ 全件で QEMU 出力 == RTL 出力 (golden があればそれとも比較)'
	@echo 'make test                       RTL 単体テスト (hw/tb/tb_*.sv)'
	@echo 'make ref                        ホスト用 C リファレンスを実行し build/ref/golden.ppm を作る'
	@echo 'make clean                      build/ を削除'
	@echo 'オプション: RAYQ_FLAGS="-O2 --accel=math"  MAXCYCLES=N  QEMU_TIMEOUT=sec'

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
run: $(B)/$(basename $(SRC)).rtl.out
	@echo '出力: $<'
qemu: $(B)/$(basename $(SRC)).qemu.out
	@echo '出力: $<'
else
run qemu:
	@echo '使い方: make $@ SRC=programs/raytracer/main.rq' >&2; exit 2
endif

# ---- smoke: コアが動くかの最小確認 (QEMU・コンパイラ・アセンブラ不要) -----------------------
smoke: $(B)/tests/hex/smoke.rtl.out
	@grep HALT $<.log || true
	@printf 'OK\n' | cmp - $< \
	  || { echo 'smoke: FAIL  UART 出力:'; cat $<; echo '(NG<文字>: tests/hex/smoke.s の先頭コメント参照)'; exit 1; }
	@echo 'smoke: PASS  (自作コアが RV32IM の基本命令を実行できています)'

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

clean:
	rm -rf $(B)

