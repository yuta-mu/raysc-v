.globl __q16_rsqrt
__q16_rsqrt:
    mv      a1, a0
    blez    a0, .L77
    li      t1, 25
    lui     a7, 0x1000
    li      a0, 0
    lui     t3, 0x10
.L76:
    or      a4, a0, a7
    mul     a6, a4, a4
    mulhu   a3, a4, a4
    mulhu   a2, a6, a1
    mul     a5, a3, a1
    mulhu   a3, a3, a1
    add     a2, a5, a2
    sltu    a5, a2, a5
    add     a5, a5, a3
    mul     a6, a6, a1
    bnez    a5, .L80
    bgeu    a2, t3, .L80
.L79:
    mv      a0, a4
.L74:
    addi    t1, t1, -1
    srli    a7, a7, 0x1
    bnez    t1, .L76
    ret
.L80:
    bne     a2, t3, .L74
    bnez    a5, .L74
    beqz    a6, .L79
    j       .L74
.L77:
    li      a0, 0
    ret

