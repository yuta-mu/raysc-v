# tests/asm/test_mul.s
.section .text
.global _start

_start:
    li  a0, 3
    li  a1, 4
    mul a2, a0, a1

    li  t0, 0x10000000
    li  t1, 12
    beq a2, t1, pass

fail:
    li  t2, 70              # ASCII 'F'
    sb  t2, 0(t0)
    li  t2, 10              # ASCII '\n'
    sb  t2, 0(t0)
    j   halt

pass:
    li  t2, 80              # ASCII 'P'
    sb  t2, 0(t0)
    li  t2, 10              # ASCII '\n'
    sb  t2, 0(t0)

halt:
    j   halt
