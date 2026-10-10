.section .text.init
.globl _start

_start:
    # 1. リンカスクリプトで計算したスタック頂点を設定
    la sp, _stack_top

    # 2. BSS セクション (__bss_start から __bss_end まで) をゼロクリア
    la t0, __bss_start
    la t1, __bss_end
bss_clear:
    bge t0, t1, bss_done
    sw zero, 0(t0)
    addi t0, t0, 4
    j bss_clear

bss_done:
    # 3. main 関数の実行
    call main

loop:
#ifdef TARGET_QEMU
    li t0, 0x00100000
    li t1, 0x5555
    sw t1, 0(t0)
    wfi
#endif
    j loop
