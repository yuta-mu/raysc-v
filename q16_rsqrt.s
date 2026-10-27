.globl __q16_rsqrt
__q16_rsqrt:
    blez a0, .L_rsqrt_zero
    addi sp, sp, -64
    sw a0, 0(sp)             # x_raw
    sw x0, 4(sp)             # result r = 0
    li t0, 0x01000000        # bit = 2^24
    sw t0, 8(sp)
.L_rsqrt_loop:
    lw t0, 8(sp)
    beqz t0, .L_rsqrt_done
    lw t1, 4(sp)
    or t2, t1, t0            # candidate c = r | bit
    sw t2, 12(sp)

    # sq = c*c, as unsigned 64-bit (hi:lo)
    mul t3, t2, t2
    mulhu t4, t2, t2
    sw t3, 16(sp)            # sq_lo
    sw t4, 20(sp)            # sq_hi

    lw t5, 0(sp)             # x_raw
    # a = sq_hi * x_raw (64-bit)
    mul t6, t4, t5
    mulhu t0, t4, t5
    sw t6, 24(sp)            # a_lo
    sw t0, 28(sp)            # a_hi
    # b = sq_lo * x_raw (64-bit)
    mul t1, t3, t5
    mulhu t2, t3, t5
    sw t1, 32(sp)            # b_lo
    sw t2, 36(sp)            # b_hi = b >> 32

    # high = a + b_hi; accept iff high < 2^16,
    # or high == 2^16 and b_lo == 0 (i.e. sq*x <= 2^48).
    lw t3, 24(sp)             # a_lo
    lw t4, 36(sp)             # b_hi
    add t5, t3, t4            # high_lo
    sltu t6, t5, t3           # carry
    lw t0, 28(sp)             # a_hi
    add t0, t0, t6            # high_hi
    bnez t0, .L_rsqrt_next
    li t1, 65536
    bltu t5, t1, .L_rsqrt_accept
    bne t5, t1, .L_rsqrt_next
    lw t2, 32(sp)             # b_lo
    bnez t2, .L_rsqrt_next
.L_rsqrt_accept:
    lw t0, 12(sp)
    sw t0, 4(sp)
.L_rsqrt_next:
    lw t0, 8(sp)
    srli t0, t0, 1
    sw t0, 8(sp)
    j .L_rsqrt_loop
.L_rsqrt_done:
    lw a0, 4(sp)
    addi sp, sp, 64
    jalr x0, ra, 0
.L_rsqrt_zero:
    li a0, 0
    jalr x0, ra, 0