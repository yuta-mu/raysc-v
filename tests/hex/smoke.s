# =============================================================================
# tests/hex/smoke.s -- 自作コアの最小動作確認 (RV32IM のみ。起動コードもコンパイラも不要)
#
# 期待する UART 出力: "OK\n"
# 失敗したときは "NG<文字>\n" を出して ebreak する。文字は失敗した項目:
#   A=mul  B=div  C=rem  D=mul(負数)  E=sw/lw  F=lbu  G=lb  H=ループ(bne/add)
#   I=jal/jalr  J=srai  K=cycles MMIO  L=div(0 除算)
#
# 再生成:  riscv64-unknown-elf-as -march=rv32im -mabi=ilp32 -o smoke.o smoke.s
#          riscv64-unknown-elf-ld -m elf32lriscv -Ttext=0 -o smoke.elf smoke.o
#          (hex は smoke.hex の形式: 1 行 1 ワード、行末にコメント)
# =============================================================================
    .text
    .globl _start
_start:
    lui   sp, 0x40              # sp = 0x00040000
    lui   s0, 0x10000           # s0 = UART 0x10000000

    # A: mul 6*7 = 42
    li    a1, 6
    li    a2, 7
    mul   a3, a1, a2
    li    a4, 42
    li    a0, 1
    bne   a3, a4, fail

    # B: div 100/7 = 14
    li    a1, 100
    li    a2, 7
    div   a3, a1, a2
    li    a4, 14
    li    a0, 2
    bne   a3, a4, fail

    # C: rem 100%7 = 2
    rem   a3, a1, a2
    li    a4, 2
    li    a0, 3
    bne   a3, a4, fail

    # D: mul (-3)*5 = -15
    li    a1, -3
    li    a2, 5
    mul   a3, a1, a2
    li    a4, -15
    li    a0, 4
    bne   a3, a4, fail

    # E: sw / lw (スタックの直下)
    lui   a1, 0x80000
    addi  a1, a1, 1             # a1 = 0x80000001
    sw    a1, -4(sp)
    lw    a3, -4(sp)
    li    a0, 5
    bne   a1, a3, fail

    # F: lbu (リトルエンディアン: 最下位バイト = 0x01)
    lbu   a3, -4(sp)
    li    a4, 1
    li    a0, 6
    bne   a3, a4, fail

    # G: lb (最上位バイト 0x80 を符号拡張 = -128)
    lb    a3, -1(sp)
    li    a4, -128
    li    a0, 7
    bne   a3, a4, fail

    # H: ループ 1+2+...+10 = 55
    li    a1, 0
    li    a2, 1
    li    a5, 11
loop:
    add   a1, a1, a2
    addi  a2, a2, 1
    bne   a2, a5, loop
    li    a4, 55
    li    a0, 8
    bne   a1, a4, fail

    # I: jal / jalr
    jal   ra, sub99
    li    a4, 99
    li    a0, 9
    bne   a3, a4, fail

    # J: srai (-16 >> 2 = -4)
    li    a1, -16
    srai  a3, a1, 2
    li    a4, -4
    li    a0, 10
    bne   a3, a4, fail

    # K: cycles MMIO (0x20000000) は 0 でない
    lui   a1, 0x20000
    lw    a3, 0(a1)
    li    a0, 11
    beq   a3, zero, fail

    # L: 0 除算 (RV32M の規定値: x/0 = -1)
    li    a1, 5
    li    a2, 0
    div   a3, a1, a2
    li    a4, -1
    li    a0, 12
    bne   a3, a4, fail

    # すべて成功: "OK\n"
    li    t1, 'O'
    sb    t1, 0(s0)
    li    t1, 'K'
    sb    t1, 0(s0)
    li    t1, 10
    sb    t1, 0(s0)
    ebreak

fail:                           # "NG" + ('@' + a0) + "\n"
    li    t1, 'N'
    sb    t1, 0(s0)
    li    t1, 'G'
    sb    t1, 0(s0)
    addi  a0, a0, 64
    sb    a0, 0(s0)
    li    t1, 10
    sb    t1, 0(s0)
    ebreak

sub99:
    li    a3, 99
    ret
