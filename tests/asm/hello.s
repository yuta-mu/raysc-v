.section .text
.globl main

.equ UART0_BASE, 0x10000000

main:
    la a0, msg            # a0 = 出力する文字列のアドレス
    li t0, UART0_BASE     # t0 = UARTのベースアドレス (0x10000000)

print_loop:
    lb t1, 0(a0)          # t1 = *a0 (1バイト読み込み)
    beqz t1, done         # null文字 ('\0') なら終了へ

    sb t1, 0(t0)          # UART の送信レジスタに書き込み (出力)
    addi a0, a0, 1        # 次の文字へ
    j print_loop

done:
    j done                # 無限ループ

.section .rodata
msg:
    .string "Hello RISC-V!\n"

