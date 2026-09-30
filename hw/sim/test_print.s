.globl _start
    .text

_start:
    lui  x1, 0x10000

    addi x2, x0, 72
    sw   x2, 0(x1)

    addi x2, x0, 101
    sw   x2, 0(x1)

    addi x2, x0, 108
    sw   x2, 0(x1)
    sw   x2, 0(x1)

    addi x2, x0, 111
    sw   x2, 0(x1)

    addi x2, x0, 33
    sw   x2, 0(x1)

    addi x2, x0, 10
    sw   x2, 0(x1)

loop:
    jal  x0, loop

