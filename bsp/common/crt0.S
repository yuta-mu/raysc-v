.section .text.init
.globl _start

_start:
    # 1. スタックポインタ初期化
    la sp, _stack_top

    # 2. BSS セクションのゼロクリア
    la t0, __bss_start
    la t1, __bss_end
bss_clear:
    bge t0, t1, bss_done
    sw zero, 0(t0)
    addi t0, t0, 4
    j bss_clear

bss_done:
    # 3. main 実行
    call main

    # 4. QEMU virt マシンの正常終了 (sifive_test デバイスへ 0x5555 を書き込む)
    li t0, 0x00100000
    li t1, 0x5555
    sw t1, 0(t0)

loop:
    wfi
    j loop

