.section .text

.globl camera_get_ray
camera_get_ray:
addi sp, sp, -436
sw ra, 432(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
sw a3, 12(sp)
sw a4, 16(sp)
sw a5, 20(sp)
sw a6, 24(sp)
sw a7, 28(sp)
lw t0, 436(sp)
sw t0, 32(sp)
lw t0, 440(sp)
sw t0, 36(sp)
lw t0, 444(sp)
sw t0, 40(sp)
lw t0, 448(sp)
sw t0, 44(sp)
lw t0, 452(sp)
sw t0, 48(sp)
lw t0, 456(sp)
sw t0, 52(sp)
lw t0, 460(sp)
sw t0, 56(sp)
lw t0, 464(sp)
sw t0, 60(sp)
lw t0, 468(sp)
sw t0, 64(sp)
lw t0, 472(sp)
sw t0, 68(sp)
lw t0, 476(sp)
sw t0, 72(sp)
lw t0, 480(sp)
sw t0, 76(sp)
lw t0, 484(sp)
sw t0, 80(sp)
lw t0, 488(sp)
sw t0, 84(sp)
.L_camera_get_ray_0:
lw a0, 0(sp)
jal ra, random_q16
sw a0, 208(sp)
sw a1, 212(sp)
lw t0, 208(sp)
sw t0, 88(sp)
lw t0, 212(sp)
sw t0, 92(sp)
lw a0, 88(sp)
jal ra, random_q16
sw a0, 216(sp)
sw a1, 220(sp)
lw t0, 216(sp)
sw t0, 96(sp)
lw t0, 220(sp)
sw t0, 100(sp)
lw t0, 96(sp)
sw t0, 120(sp)
li t0, 320
sw t0, 224(sp)
lw a0, 80(sp)
lw a1, 224(sp)
jal ra, ratio_i32
sw a0, 228(sp)
li t0, 320
sw t0, 232(sp)
li t0, 16
sw t0, 236(sp)
lw t0, 232(sp)
lw t1, 236(sp)
sll t0, t0, t1
sw t0, 240(sp)
lw t0, 240(sp)
qrcp t0, t0
sw t0, 244(sp)
lw t0, 92(sp)
lw t1, 244(sp)
qmul t0, t0, t1
sw t0, 248(sp)
lw t0, 228(sp)
lw t1, 248(sp)
add t0, t0, t1
sw t0, 252(sp)
lw t0, 252(sp)
sw t0, 124(sp)
li t0, 240
sw t0, 256(sp)
lw a0, 84(sp)
lw a1, 256(sp)
jal ra, ratio_i32
sw a0, 260(sp)
li t0, 240
sw t0, 264(sp)
li t0, 16
sw t0, 268(sp)
lw t0, 264(sp)
lw t1, 268(sp)
sll t0, t0, t1
sw t0, 272(sp)
lw t0, 272(sp)
qrcp t0, t0
sw t0, 276(sp)
lw t0, 100(sp)
lw t1, 276(sp)
qmul t0, t0, t1
sw t0, 280(sp)
lw t0, 260(sp)
lw t1, 280(sp)
add t0, t0, t1
sw t0, 284(sp)
lw t0, 284(sp)
sw t0, 128(sp)
lw a0, 28(sp)
lw a1, 32(sp)
lw a2, 36(sp)
lw a3, 124(sp)
jal ra, vec3_scale
sw a0, 288(sp)
sw a1, 292(sp)
sw a2, 296(sp)
lw a0, 16(sp)
lw a1, 20(sp)
lw a2, 24(sp)
lw a3, 288(sp)
lw a4, 292(sp)
lw a5, 296(sp)
jal ra, vec3_add
sw a0, 300(sp)
sw a1, 304(sp)
sw a2, 308(sp)
lw a0, 40(sp)
lw a1, 44(sp)
lw a2, 48(sp)
lw a3, 128(sp)
jal ra, vec3_scale
sw a0, 312(sp)
sw a1, 316(sp)
sw a2, 320(sp)
lw a0, 300(sp)
lw a1, 304(sp)
lw a2, 308(sp)
lw a3, 312(sp)
lw a4, 316(sp)
lw a5, 320(sp)
jal ra, vec3_add
sw a0, 324(sp)
sw a1, 328(sp)
sw a2, 332(sp)
lw t0, 324(sp)
sw t0, 132(sp)
lw t0, 328(sp)
sw t0, 136(sp)
lw t0, 332(sp)
sw t0, 140(sp)
lw t0, 4(sp)
sw t0, 144(sp)
lw t0, 8(sp)
sw t0, 148(sp)
lw t0, 12(sp)
sw t0, 152(sp)
li t0, 0
sw t0, 336(sp)
lw t0, 76(sp)
lw t1, 336(sp)
sub t0, t0, t1
sltu t0, x0, t0
sw t0, 340(sp)
lw t0, 340(sp)
bnez t0, .L_camera_get_ray_1
j .L_camera_get_ray_2
.L_camera_get_ray_1:
lw a0, 120(sp)
jal ra, random_in_unit_disk
sw a0, 344(sp)
sw a1, 348(sp)
sw a2, 352(sp)
sw a3, 356(sp)
lw t0, 344(sp)
sw t0, 104(sp)
lw t0, 348(sp)
sw t0, 108(sp)
lw t0, 352(sp)
sw t0, 112(sp)
lw t0, 356(sp)
sw t0, 116(sp)
lw t0, 104(sp)
sw t0, 120(sp)
lw a0, 52(sp)
lw a1, 56(sp)
lw a2, 60(sp)
lw a3, 108(sp)
jal ra, vec3_scale
sw a0, 360(sp)
sw a1, 364(sp)
sw a2, 368(sp)
lw a0, 4(sp)
lw a1, 8(sp)
lw a2, 12(sp)
lw a3, 360(sp)
lw a4, 364(sp)
lw a5, 368(sp)
jal ra, vec3_add
sw a0, 372(sp)
sw a1, 376(sp)
sw a2, 380(sp)
lw a0, 64(sp)
lw a1, 68(sp)
lw a2, 72(sp)
lw a3, 112(sp)
jal ra, vec3_scale
sw a0, 384(sp)
sw a1, 388(sp)
sw a2, 392(sp)
lw a0, 372(sp)
lw a1, 376(sp)
lw a2, 380(sp)
lw a3, 384(sp)
lw a4, 388(sp)
lw a5, 392(sp)
jal ra, vec3_add
sw a0, 396(sp)
sw a1, 400(sp)
sw a2, 404(sp)
lw t0, 396(sp)
sw t0, 144(sp)
lw t0, 400(sp)
sw t0, 148(sp)
lw t0, 404(sp)
sw t0, 152(sp)
j .L_camera_get_ray_2
.L_camera_get_ray_2:
lw t0, 144(sp)
sw t0, 156(sp)
lw t0, 148(sp)
sw t0, 160(sp)
lw t0, 152(sp)
sw t0, 164(sp)
lw a0, 132(sp)
lw a1, 136(sp)
lw a2, 140(sp)
lw a3, 144(sp)
lw a4, 148(sp)
lw a5, 152(sp)
jal ra, vec3_sub
sw a0, 408(sp)
sw a1, 412(sp)
sw a2, 416(sp)
lw a0, 408(sp)
lw a1, 412(sp)
lw a2, 416(sp)
jal ra, vec3_unit_big
sw a0, 420(sp)
sw a1, 424(sp)
sw a2, 428(sp)
lw t0, 420(sp)
sw t0, 168(sp)
lw t0, 424(sp)
sw t0, 172(sp)
lw t0, 428(sp)
sw t0, 176(sp)
lw t0, 120(sp)
sw t0, 180(sp)
lw t0, 156(sp)
sw t0, 184(sp)
lw t0, 160(sp)
sw t0, 188(sp)
lw t0, 164(sp)
sw t0, 192(sp)
lw t0, 168(sp)
sw t0, 196(sp)
lw t0, 172(sp)
sw t0, 200(sp)
lw t0, 176(sp)
sw t0, 204(sp)
lw a0, 180(sp)
lw a1, 184(sp)
lw a2, 188(sp)
lw a3, 192(sp)
lw a4, 196(sp)
lw a5, 200(sp)
lw a6, 204(sp)
lw ra, 432(sp)
addi sp, sp, 436
jalr x0, ra, 0

.globl camera_init
camera_init:
addi sp, sp, -596
sw ra, 592(sp)
.L_camera_init_0:
li t0, 851968
sw t0, 180(sp)
li t0, 131072
sw t0, 184(sp)
li t0, 196608
sw t0, 188(sp)
lw t0, 180(sp)
sw t0, 192(sp)
lw t0, 184(sp)
sw t0, 196(sp)
lw t0, 188(sp)
sw t0, 200(sp)
lw t0, 192(sp)
sw t0, 132(sp)
lw t0, 196(sp)
sw t0, 136(sp)
lw t0, 200(sp)
sw t0, 140(sp)
li t0, 0
sw t0, 204(sp)
li t0, 0
sw t0, 208(sp)
li t0, 0
sw t0, 212(sp)
lw t0, 204(sp)
sw t0, 216(sp)
lw t0, 208(sp)
sw t0, 220(sp)
lw t0, 212(sp)
sw t0, 224(sp)
lw t0, 216(sp)
sw t0, 144(sp)
lw t0, 220(sp)
sw t0, 148(sp)
lw t0, 224(sp)
sw t0, 152(sp)
li t0, 0
sw t0, 228(sp)
li t0, 65536
sw t0, 232(sp)
li t0, 0
sw t0, 236(sp)
lw t0, 228(sp)
sw t0, 240(sp)
lw t0, 232(sp)
sw t0, 244(sp)
lw t0, 236(sp)
sw t0, 248(sp)
lw t0, 240(sp)
sw t0, 156(sp)
lw t0, 244(sp)
sw t0, 160(sp)
lw t0, 248(sp)
sw t0, 164(sp)
li t0, 655360
sw t0, 252(sp)
lw t0, 252(sp)
sw t0, 168(sp)
li t0, 39322
sw t0, 256(sp)
lw t0, 256(sp)
sw t0, 172(sp)
li t0, 1310720
sw t0, 260(sp)
lw a0, 260(sp)
jal ra, degrees_to_radians
sw a0, 264(sp)
lw t0, 264(sp)
sw t0, 76(sp)
li t0, 32768
sw t0, 268(sp)
lw t0, 76(sp)
lw t1, 268(sp)
qmul t0, t0, t1
sw t0, 272(sp)
lw a0, 272(sp)
jal ra, q_tan_small
sw a0, 276(sp)
lw t0, 276(sp)
sw t0, 80(sp)
li t0, 131072
sw t0, 280(sp)
lw t0, 280(sp)
lw t1, 80(sp)
qmul t0, t0, t1
sw t0, 284(sp)
lw t0, 284(sp)
lw t1, 168(sp)
qmul t0, t0, t1
sw t0, 288(sp)
lw t0, 288(sp)
sw t0, 84(sp)
li t0, 320
sw t0, 292(sp)
li t0, 240
sw t0, 296(sp)
lw a0, 292(sp)
lw a1, 296(sp)
jal ra, ratio_i32
sw a0, 300(sp)
lw t0, 300(sp)
sw t0, 88(sp)
lw t0, 84(sp)
lw t1, 88(sp)
qmul t0, t0, t1
sw t0, 304(sp)
lw t0, 304(sp)
sw t0, 92(sp)
lw a0, 132(sp)
lw a1, 136(sp)
lw a2, 140(sp)
lw a3, 144(sp)
lw a4, 148(sp)
lw a5, 152(sp)
jal ra, vec3_sub
sw a0, 308(sp)
sw a1, 312(sp)
sw a2, 316(sp)
lw a0, 308(sp)
lw a1, 312(sp)
lw a2, 316(sp)
jal ra, vec3_unit_big
sw a0, 320(sp)
sw a1, 324(sp)
sw a2, 328(sp)
lw t0, 320(sp)
sw t0, 96(sp)
lw t0, 324(sp)
sw t0, 100(sp)
lw t0, 328(sp)
sw t0, 104(sp)
lw a0, 156(sp)
lw a1, 160(sp)
lw a2, 164(sp)
lw a3, 96(sp)
lw a4, 100(sp)
lw a5, 104(sp)
jal ra, vec3_cross
sw a0, 332(sp)
sw a1, 336(sp)
sw a2, 340(sp)
lw a0, 332(sp)
lw a1, 336(sp)
lw a2, 340(sp)
jal ra, vec3_unit
sw a0, 344(sp)
sw a1, 348(sp)
sw a2, 352(sp)
lw t0, 344(sp)
sw t0, 108(sp)
lw t0, 348(sp)
sw t0, 112(sp)
lw t0, 352(sp)
sw t0, 116(sp)
lw a0, 96(sp)
lw a1, 100(sp)
lw a2, 104(sp)
lw a3, 108(sp)
lw a4, 112(sp)
lw a5, 116(sp)
jal ra, vec3_cross
sw a0, 356(sp)
sw a1, 360(sp)
sw a2, 364(sp)
lw t0, 356(sp)
sw t0, 120(sp)
lw t0, 360(sp)
sw t0, 124(sp)
lw t0, 364(sp)
sw t0, 128(sp)
lw t0, 132(sp)
sw t0, 0(sp)
lw t0, 136(sp)
sw t0, 4(sp)
lw t0, 140(sp)
sw t0, 8(sp)
lw a0, 108(sp)
lw a1, 112(sp)
lw a2, 116(sp)
lw a3, 92(sp)
jal ra, vec3_scale
sw a0, 368(sp)
sw a1, 372(sp)
sw a2, 376(sp)
lw t0, 368(sp)
sw t0, 24(sp)
lw t0, 372(sp)
sw t0, 28(sp)
lw t0, 376(sp)
sw t0, 32(sp)
lw a0, 120(sp)
lw a1, 124(sp)
lw a2, 128(sp)
jal ra, vec3_neg
sw a0, 380(sp)
sw a1, 384(sp)
sw a2, 388(sp)
lw a0, 380(sp)
lw a1, 384(sp)
lw a2, 388(sp)
lw a3, 84(sp)
jal ra, vec3_scale
sw a0, 392(sp)
sw a1, 396(sp)
sw a2, 400(sp)
lw t0, 392(sp)
sw t0, 36(sp)
lw t0, 396(sp)
sw t0, 40(sp)
lw t0, 400(sp)
sw t0, 44(sp)
lw a0, 96(sp)
lw a1, 100(sp)
lw a2, 104(sp)
lw a3, 168(sp)
jal ra, vec3_scale
sw a0, 404(sp)
sw a1, 408(sp)
sw a2, 412(sp)
lw a0, 0(sp)
lw a1, 4(sp)
lw a2, 8(sp)
lw a3, 404(sp)
lw a4, 408(sp)
lw a5, 412(sp)
jal ra, vec3_sub
sw a0, 416(sp)
sw a1, 420(sp)
sw a2, 424(sp)
li t0, 32768
sw t0, 428(sp)
lw a0, 24(sp)
lw a1, 28(sp)
lw a2, 32(sp)
lw a3, 428(sp)
jal ra, vec3_scale
sw a0, 432(sp)
sw a1, 436(sp)
sw a2, 440(sp)
lw a0, 416(sp)
lw a1, 420(sp)
lw a2, 424(sp)
lw a3, 432(sp)
lw a4, 436(sp)
lw a5, 440(sp)
jal ra, vec3_sub
sw a0, 444(sp)
sw a1, 448(sp)
sw a2, 452(sp)
li t0, 32768
sw t0, 456(sp)
lw a0, 36(sp)
lw a1, 40(sp)
lw a2, 44(sp)
lw a3, 456(sp)
jal ra, vec3_scale
sw a0, 460(sp)
sw a1, 464(sp)
sw a2, 468(sp)
lw a0, 444(sp)
lw a1, 448(sp)
lw a2, 452(sp)
lw a3, 460(sp)
lw a4, 464(sp)
lw a5, 468(sp)
jal ra, vec3_sub
sw a0, 472(sp)
sw a1, 476(sp)
sw a2, 480(sp)
lw t0, 472(sp)
sw t0, 12(sp)
lw t0, 476(sp)
sw t0, 16(sp)
lw t0, 480(sp)
sw t0, 20(sp)
li t0, 0
sw t0, 484(sp)
lw t0, 172(sp)
lw t1, 484(sp)
slt t0, t1, t0
xori t0, t0, 1
sw t0, 488(sp)
lw t0, 488(sp)
bnez t0, .L_camera_init_1
j .L_camera_init_2
.L_camera_init_1:
li t0, 0
sw t0, 492(sp)
lw t0, 492(sp)
sw t0, 72(sp)
li t0, 0
sw t0, 496(sp)
li t0, 0
sw t0, 500(sp)
li t0, 0
sw t0, 504(sp)
lw t0, 496(sp)
sw t0, 508(sp)
lw t0, 500(sp)
sw t0, 512(sp)
lw t0, 504(sp)
sw t0, 516(sp)
lw t0, 508(sp)
sw t0, 48(sp)
lw t0, 512(sp)
sw t0, 52(sp)
lw t0, 516(sp)
sw t0, 56(sp)
li t0, 0
sw t0, 520(sp)
li t0, 0
sw t0, 524(sp)
li t0, 0
sw t0, 528(sp)
lw t0, 520(sp)
sw t0, 532(sp)
lw t0, 524(sp)
sw t0, 536(sp)
lw t0, 528(sp)
sw t0, 540(sp)
lw t0, 532(sp)
sw t0, 60(sp)
lw t0, 536(sp)
sw t0, 64(sp)
lw t0, 540(sp)
sw t0, 68(sp)
j .L_camera_init_3
.L_camera_init_2:
li t0, 1
sw t0, 544(sp)
lw t0, 544(sp)
sw t0, 72(sp)
li t0, 32768
sw t0, 548(sp)
lw t0, 172(sp)
lw t1, 548(sp)
qmul t0, t0, t1
sw t0, 552(sp)
lw a0, 552(sp)
jal ra, degrees_to_radians
sw a0, 556(sp)
lw a0, 556(sp)
jal ra, q_tan_small
sw a0, 560(sp)
lw t0, 168(sp)
lw t1, 560(sp)
qmul t0, t0, t1
sw t0, 564(sp)
lw t0, 564(sp)
sw t0, 176(sp)
lw a0, 108(sp)
lw a1, 112(sp)
lw a2, 116(sp)
lw a3, 176(sp)
jal ra, vec3_scale
sw a0, 568(sp)
sw a1, 572(sp)
sw a2, 576(sp)
lw t0, 568(sp)
sw t0, 48(sp)
lw t0, 572(sp)
sw t0, 52(sp)
lw t0, 576(sp)
sw t0, 56(sp)
lw a0, 120(sp)
lw a1, 124(sp)
lw a2, 128(sp)
lw a3, 176(sp)
jal ra, vec3_scale
sw a0, 580(sp)
sw a1, 584(sp)
sw a2, 588(sp)
lw t0, 580(sp)
sw t0, 60(sp)
lw t0, 584(sp)
sw t0, 64(sp)
lw t0, 588(sp)
sw t0, 68(sp)
j .L_camera_init_3
.L_camera_init_3:
lw a0, 0(sp)
lw a1, 4(sp)
lw a2, 8(sp)
lw a3, 12(sp)
lw a4, 16(sp)
lw a5, 20(sp)
lw a6, 24(sp)
lw a7, 28(sp)
lw t0, 32(sp)
sw t0, 596(sp)
lw t0, 36(sp)
sw t0, 600(sp)
lw t0, 40(sp)
sw t0, 604(sp)
lw t0, 44(sp)
sw t0, 608(sp)
lw t0, 48(sp)
sw t0, 612(sp)
lw t0, 52(sp)
sw t0, 616(sp)
lw t0, 56(sp)
sw t0, 620(sp)
lw t0, 60(sp)
sw t0, 624(sp)
lw t0, 64(sp)
sw t0, 628(sp)
lw t0, 68(sp)
sw t0, 632(sp)
lw t0, 72(sp)
sw t0, 636(sp)
lw ra, 592(sp)
addi sp, sp, 596
jalr x0, ra, 0

.globl camera_render
camera_render:
addi sp, sp, -412
sw ra, 408(sp)
sw a0, 56(sp)
sw a1, 60(sp)
sw a2, 64(sp)
sw a3, 68(sp)
sw a4, 72(sp)
sw a5, 76(sp)
sw a6, 80(sp)
sw a7, 84(sp)
lw t0, 412(sp)
sw t0, 88(sp)
lw t0, 416(sp)
sw t0, 92(sp)
lw t0, 420(sp)
sw t0, 96(sp)
lw t0, 424(sp)
sw t0, 100(sp)
lw t0, 428(sp)
sw t0, 104(sp)
lw t0, 432(sp)
sw t0, 108(sp)
lw t0, 436(sp)
sw t0, 112(sp)
lw t0, 440(sp)
sw t0, 116(sp)
lw t0, 444(sp)
sw t0, 120(sp)
lw t0, 448(sp)
sw t0, 124(sp)
lw t0, 452(sp)
sw t0, 128(sp)
lw t0, 456(sp)
sw t0, 132(sp)
.L_camera_render_0:
lw t0, 56(sp)
sw t0, 136(sp)
li t0, 0
sw t0, 228(sp)
li t0, 4
sw t0, 232(sp)
la t0, __str_0
sw t0, 220(sp)
j .L_camera_render_1
.L_camera_render_1:
lw t0, 220(sp)
lw t0, 0(t0)
sw t0, 224(sp)
lw t0, 224(sp)
lw t1, 228(sp)
sub t0, t0, t1
sltu t0, x0, t0
sw t0, 236(sp)
lw t0, 236(sp)
bnez t0, .L_camera_render_2
j .L_camera_render_3
.L_camera_render_2:
lw t0, 224(sp)
li t1, 0x10000000
sb t0, 0(t1)
lw t0, 220(sp)
lw t1, 232(sp)
add t0, t0, t1
sw t0, 220(sp)
j .L_camera_render_1
.L_camera_render_3:
li t0, 0
sw t0, 240(sp)
li t0, 240
sw t0, 244(sp)
lw t0, 240(sp)
sw t0, 208(sp)
lw t0, 244(sp)
sw t0, 248(sp)
j .L_camera_render_4
.L_camera_render_4:
lw t0, 208(sp)
lw t1, 248(sp)
slt t0, t0, t1
sw t0, 252(sp)
lw t0, 252(sp)
bnez t0, .L_camera_render_5
j .L_camera_render_7
.L_camera_render_5:
li t0, 0
sw t0, 256(sp)
li t0, 320
sw t0, 260(sp)
lw t0, 256(sp)
sw t0, 212(sp)
lw t0, 260(sp)
sw t0, 264(sp)
j .L_camera_render_8
.L_camera_render_8:
lw t0, 212(sp)
lw t1, 264(sp)
slt t0, t0, t1
sw t0, 268(sp)
lw t0, 268(sp)
bnez t0, .L_camera_render_9
j .L_camera_render_11
.L_camera_render_9:
li t0, 0
sw t0, 272(sp)
li t0, 0
sw t0, 276(sp)
li t0, 0
sw t0, 280(sp)
lw t0, 272(sp)
sw t0, 284(sp)
lw t0, 276(sp)
sw t0, 288(sp)
lw t0, 280(sp)
sw t0, 292(sp)
lw t0, 284(sp)
sw t0, 140(sp)
lw t0, 288(sp)
sw t0, 144(sp)
lw t0, 292(sp)
sw t0, 148(sp)
li t0, 0
sw t0, 296(sp)
li t0, 100
sw t0, 300(sp)
lw t0, 296(sp)
sw t0, 216(sp)
lw t0, 300(sp)
sw t0, 304(sp)
j .L_camera_render_12
.L_camera_render_12:
lw t0, 216(sp)
lw t1, 304(sp)
slt t0, t0, t1
sw t0, 308(sp)
lw t0, 308(sp)
bnez t0, .L_camera_render_13
j .L_camera_render_15
.L_camera_render_13:
lw a0, 136(sp)
lw a1, 60(sp)
lw a2, 64(sp)
lw a3, 68(sp)
lw a4, 72(sp)
lw a5, 76(sp)
lw a6, 80(sp)
lw a7, 84(sp)
lw t0, 88(sp)
sw t0, 0(sp)
lw t0, 92(sp)
sw t0, 4(sp)
lw t0, 96(sp)
sw t0, 8(sp)
lw t0, 100(sp)
sw t0, 12(sp)
lw t0, 104(sp)
sw t0, 16(sp)
lw t0, 108(sp)
sw t0, 20(sp)
lw t0, 112(sp)
sw t0, 24(sp)
lw t0, 116(sp)
sw t0, 28(sp)
lw t0, 120(sp)
sw t0, 32(sp)
lw t0, 124(sp)
sw t0, 36(sp)
lw t0, 128(sp)
sw t0, 40(sp)
lw t0, 132(sp)
sw t0, 44(sp)
lw t0, 212(sp)
sw t0, 48(sp)
lw t0, 208(sp)
sw t0, 52(sp)
jal ra, camera_get_ray
sw a0, 312(sp)
sw a1, 316(sp)
sw a2, 320(sp)
sw a3, 324(sp)
sw a4, 328(sp)
sw a5, 332(sp)
sw a6, 336(sp)
lw t0, 312(sp)
sw t0, 152(sp)
lw t0, 316(sp)
sw t0, 156(sp)
lw t0, 320(sp)
sw t0, 160(sp)
lw t0, 324(sp)
sw t0, 164(sp)
lw t0, 328(sp)
sw t0, 168(sp)
lw t0, 332(sp)
sw t0, 172(sp)
lw t0, 336(sp)
sw t0, 176(sp)
lw t0, 152(sp)
sw t0, 136(sp)
lw a0, 136(sp)
lw a1, 156(sp)
lw a2, 160(sp)
lw a3, 164(sp)
lw a4, 168(sp)
lw a5, 172(sp)
lw a6, 176(sp)
jal ra, ray_color
sw a0, 340(sp)
sw a1, 344(sp)
sw a2, 348(sp)
sw a3, 352(sp)
lw t0, 340(sp)
sw t0, 180(sp)
lw t0, 344(sp)
sw t0, 184(sp)
lw t0, 348(sp)
sw t0, 188(sp)
lw t0, 352(sp)
sw t0, 192(sp)
lw t0, 180(sp)
sw t0, 136(sp)
lw a0, 140(sp)
lw a1, 144(sp)
lw a2, 148(sp)
lw a3, 184(sp)
lw a4, 188(sp)
lw a5, 192(sp)
jal ra, vec3_add
sw a0, 356(sp)
sw a1, 360(sp)
sw a2, 364(sp)
lw t0, 356(sp)
sw t0, 140(sp)
lw t0, 360(sp)
sw t0, 144(sp)
lw t0, 364(sp)
sw t0, 148(sp)
j .L_camera_render_14
.L_camera_render_14:
li t0, 1
sw t0, 368(sp)
lw t0, 216(sp)
lw t1, 368(sp)
add t0, t0, t1
sw t0, 216(sp)
j .L_camera_render_12
.L_camera_render_15:
li t0, 100
sw t0, 372(sp)
li t0, 16
sw t0, 376(sp)
lw t0, 372(sp)
lw t1, 376(sp)
sll t0, t0, t1
sw t0, 380(sp)
lw t0, 380(sp)
qrcp t0, t0
sw t0, 384(sp)
lw a0, 140(sp)
lw a1, 144(sp)
lw a2, 148(sp)
lw a3, 384(sp)
jal ra, vec3_scale
sw a0, 388(sp)
sw a1, 392(sp)
sw a2, 396(sp)
lw t0, 388(sp)
sw t0, 196(sp)
lw t0, 392(sp)
sw t0, 200(sp)
lw t0, 396(sp)
sw t0, 204(sp)
lw a0, 196(sp)
lw a1, 200(sp)
lw a2, 204(sp)
jal ra, write_pixel
j .L_camera_render_10
.L_camera_render_10:
li t0, 1
sw t0, 400(sp)
lw t0, 212(sp)
lw t1, 400(sp)
add t0, t0, t1
sw t0, 212(sp)
j .L_camera_render_8
.L_camera_render_11:
j .L_camera_render_6
.L_camera_render_6:
li t0, 1
sw t0, 404(sp)
lw t0, 208(sp)
lw t1, 404(sp)
add t0, t0, t1
sw t0, 208(sp)
j .L_camera_render_4
.L_camera_render_7:
lw ra, 408(sp)
addi sp, sp, 412
jalr x0, ra, 0

.globl color_to_byte
color_to_byte:
addi sp, sp, -60
sw ra, 56(sp)
sw a0, 0(sp)
.L_color_to_byte_0:
li t0, 0
sw t0, 12(sp)
lw t0, 0(sp)
lw t1, 12(sp)
slt t0, t1, t0
xori t0, t0, 1
sw t0, 16(sp)
lw t0, 16(sp)
bnez t0, .L_color_to_byte_1
j .L_color_to_byte_2
.L_color_to_byte_1:
li t0, 0
sw t0, 20(sp)
lw a0, 20(sp)
lw ra, 56(sp)
addi sp, sp, 60
jalr x0, ra, 0
.L_color_to_byte_2:
lw t0, 0(sp)
qsqrt t0, t0
sw t0, 24(sp)
lw t0, 24(sp)
sw t0, 4(sp)
li t0, 0
sw t0, 28(sp)
li t0, 65470
sw t0, 32(sp)
lw a0, 4(sp)
lw a1, 28(sp)
lw a2, 32(sp)
jal ra, q_clamp
sw a0, 36(sp)
lw t0, 36(sp)
sw t0, 8(sp)
li t0, 256
sw t0, 40(sp)
lw t0, 8(sp)
lw t1, 40(sp)
mul t0, t0, t1
sw t0, 44(sp)
li t0, 16
sw t0, 48(sp)
lw t0, 44(sp)
lw t1, 48(sp)
sra t0, t0, t1
sw t0, 52(sp)
lw a0, 52(sp)
lw ra, 56(sp)
addi sp, sp, 60
jalr x0, ra, 0

.globl degrees_to_radians
degrees_to_radians:
addi sp, sp, -36
sw ra, 32(sp)
sw a0, 0(sp)
.L_degrees_to_radians_0:
li t0, 205887
sw t0, 4(sp)
lw t0, 0(sp)
lw t1, 4(sp)
qmul t0, t0, t1
sw t0, 8(sp)
li t0, 180
sw t0, 12(sp)
li t0, 16
sw t0, 16(sp)
lw t0, 12(sp)
lw t1, 16(sp)
sll t0, t0, t1
sw t0, 20(sp)
lw t0, 20(sp)
qrcp t0, t0
sw t0, 24(sp)
lw t0, 8(sp)
lw t1, 24(sp)
qmul t0, t0, t1
sw t0, 28(sp)
lw a0, 28(sp)
lw ra, 32(sp)
addi sp, sp, 36
jalr x0, ra, 0

.globl hit_ground
hit_ground:
addi sp, sp, -416
sw ra, 412(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
sw a3, 12(sp)
sw a4, 16(sp)
sw a5, 20(sp)
sw a6, 24(sp)
sw a7, 28(sp)
.L_hit_ground_0:
li t0, 0
sw t0, 144(sp)
lw t0, 144(sp)
sw t0, 32(sp)
li t0, 0
sw t0, 148(sp)
li t0, 0
sw t0, 152(sp)
li t0, 0
sw t0, 156(sp)
lw t0, 148(sp)
sw t0, 160(sp)
lw t0, 152(sp)
sw t0, 164(sp)
lw t0, 156(sp)
sw t0, 168(sp)
lw t0, 160(sp)
sw t0, 36(sp)
lw t0, 164(sp)
sw t0, 40(sp)
lw t0, 168(sp)
sw t0, 44(sp)
li t0, 0
sw t0, 172(sp)
li t0, 65536
sw t0, 176(sp)
li t0, 0
sw t0, 180(sp)
lw t0, 172(sp)
sw t0, 184(sp)
lw t0, 176(sp)
sw t0, 188(sp)
lw t0, 180(sp)
sw t0, 192(sp)
lw t0, 184(sp)
sw t0, 48(sp)
lw t0, 188(sp)
sw t0, 52(sp)
lw t0, 192(sp)
sw t0, 56(sp)
li t0, 0
sw t0, 196(sp)
lw t0, 196(sp)
sw t0, 60(sp)
li t0, 1
sw t0, 200(sp)
lw t0, 200(sp)
sw t0, 64(sp)
li t0, 0
sw t0, 204(sp)
lw t0, 204(sp)
sw t0, 68(sp)
li t0, 32768
sw t0, 208(sp)
li t0, 32768
sw t0, 212(sp)
li t0, 32768
sw t0, 216(sp)
lw t0, 208(sp)
sw t0, 220(sp)
lw t0, 212(sp)
sw t0, 224(sp)
lw t0, 216(sp)
sw t0, 228(sp)
lw t0, 220(sp)
sw t0, 72(sp)
lw t0, 224(sp)
sw t0, 76(sp)
lw t0, 228(sp)
sw t0, 80(sp)
li t0, 0
sw t0, 232(sp)
lw t0, 232(sp)
sw t0, 84(sp)
li t0, 8192
sw t0, 236(sp)
lw a0, 0(sp)
lw a1, 4(sp)
lw a2, 8(sp)
lw a3, 236(sp)
jal ra, vec3_scale
sw a0, 240(sp)
sw a1, 244(sp)
sw a2, 248(sp)
lw t0, 240(sp)
sw t0, 88(sp)
lw t0, 244(sp)
sw t0, 92(sp)
lw t0, 248(sp)
sw t0, 96(sp)
lw a0, 88(sp)
lw a1, 92(sp)
lw a2, 96(sp)
lw a3, 12(sp)
lw a4, 16(sp)
lw a5, 20(sp)
jal ra, vec3_dot
sw a0, 252(sp)
li t0, 8192000
sw t0, 256(sp)
lw t0, 256(sp)
lw t1, 16(sp)
qmul t0, t0, t1
sw t0, 260(sp)
lw t0, 252(sp)
lw t1, 260(sp)
add t0, t0, t1
sw t0, 264(sp)
lw t0, 264(sp)
sw t0, 100(sp)
li t0, 0
sw t0, 268(sp)
lw t0, 100(sp)
lw t1, 268(sp)
slt t0, t0, t1
xori t0, t0, 1
sw t0, 272(sp)
lw t0, 272(sp)
bnez t0, .L_hit_ground_1
j .L_hit_ground_2
.L_hit_ground_1:
lw a0, 32(sp)
lw a1, 36(sp)
lw a2, 40(sp)
lw a3, 44(sp)
lw a4, 48(sp)
lw a5, 52(sp)
lw a6, 56(sp)
lw a7, 60(sp)
lw t0, 64(sp)
sw t0, 416(sp)
lw t0, 68(sp)
sw t0, 420(sp)
lw t0, 72(sp)
sw t0, 424(sp)
lw t0, 76(sp)
sw t0, 428(sp)
lw t0, 80(sp)
sw t0, 432(sp)
lw t0, 84(sp)
sw t0, 436(sp)
lw ra, 412(sp)
addi sp, sp, 416
jalr x0, ra, 0
.L_hit_ground_2:
lw a0, 88(sp)
lw a1, 92(sp)
lw a2, 96(sp)
lw a3, 88(sp)
lw a4, 92(sp)
lw a5, 96(sp)
jal ra, vec3_dot
sw a0, 276(sp)
li t0, 2048000
sw t0, 280(sp)
lw t0, 280(sp)
lw t1, 4(sp)
qmul t0, t0, t1
sw t0, 284(sp)
lw t0, 276(sp)
lw t1, 284(sp)
add t0, t0, t1
sw t0, 288(sp)
lw t0, 288(sp)
sw t0, 104(sp)
lw t0, 100(sp)
lw t1, 100(sp)
qmul t0, t0, t1
sw t0, 292(sp)
lw t0, 292(sp)
lw t1, 104(sp)
sub t0, t0, t1
sw t0, 296(sp)
lw t0, 296(sp)
sw t0, 108(sp)
li t0, 0
sw t0, 300(sp)
lw t0, 108(sp)
lw t1, 300(sp)
slt t0, t0, t1
sw t0, 304(sp)
lw t0, 304(sp)
bnez t0, .L_hit_ground_3
j .L_hit_ground_4
.L_hit_ground_3:
lw a0, 32(sp)
lw a1, 36(sp)
lw a2, 40(sp)
lw a3, 44(sp)
lw a4, 48(sp)
lw a5, 52(sp)
lw a6, 56(sp)
lw a7, 60(sp)
lw t0, 64(sp)
sw t0, 416(sp)
lw t0, 68(sp)
sw t0, 420(sp)
lw t0, 72(sp)
sw t0, 424(sp)
lw t0, 76(sp)
sw t0, 428(sp)
lw t0, 80(sp)
sw t0, 432(sp)
lw t0, 84(sp)
sw t0, 436(sp)
lw ra, 412(sp)
addi sp, sp, 416
jalr x0, ra, 0
.L_hit_ground_4:
lw t0, 100(sp)
sub t0, x0, t0
sw t0, 308(sp)
lw t0, 108(sp)
qsqrt t0, t0
sw t0, 312(sp)
lw t0, 308(sp)
lw t1, 312(sp)
sub t0, t0, t1
sw t0, 316(sp)
lw t0, 316(sp)
sw t0, 112(sp)
li t0, 524288
sw t0, 320(sp)
lw t0, 112(sp)
lw t1, 320(sp)
qmul t0, t0, t1
sw t0, 324(sp)
lw t0, 324(sp)
sw t0, 116(sp)
lw t0, 116(sp)
lw t1, 24(sp)
slt t0, t1, t0
xori t0, t0, 1
sw t0, 332(sp)
lw t0, 332(sp)
bnez t0, .L_hit_ground_6
j .L_hit_ground_5
.L_hit_ground_5:
lw t0, 116(sp)
lw t1, 28(sp)
slt t0, t0, t1
xori t0, t0, 1
sw t0, 336(sp)
lw t0, 336(sp)
sw t0, 328(sp)
j .L_hit_ground_7
.L_hit_ground_6:
li t0, 1
sw t0, 328(sp)
j .L_hit_ground_7
.L_hit_ground_7:
lw t0, 328(sp)
bnez t0, .L_hit_ground_8
j .L_hit_ground_9
.L_hit_ground_8:
lw a0, 32(sp)
lw a1, 36(sp)
lw a2, 40(sp)
lw a3, 44(sp)
lw a4, 48(sp)
lw a5, 52(sp)
lw a6, 56(sp)
lw a7, 60(sp)
lw t0, 64(sp)
sw t0, 416(sp)
lw t0, 68(sp)
sw t0, 420(sp)
lw t0, 72(sp)
sw t0, 424(sp)
lw t0, 76(sp)
sw t0, 428(sp)
lw t0, 80(sp)
sw t0, 432(sp)
lw t0, 84(sp)
sw t0, 436(sp)
lw ra, 412(sp)
addi sp, sp, 416
jalr x0, ra, 0
.L_hit_ground_9:
lw a0, 0(sp)
lw a1, 4(sp)
lw a2, 8(sp)
lw a3, 12(sp)
lw a4, 16(sp)
lw a5, 20(sp)
lw a6, 116(sp)
jal ra, ray_at
sw a0, 340(sp)
sw a1, 344(sp)
sw a2, 348(sp)
lw t0, 340(sp)
sw t0, 120(sp)
lw t0, 344(sp)
sw t0, 124(sp)
lw t0, 348(sp)
sw t0, 128(sp)
li t0, 66
sw t0, 352(sp)
lw t0, 120(sp)
lw t1, 352(sp)
qmul t0, t0, t1
sw t0, 356(sp)
li t0, 65536
sw t0, 360(sp)
li t0, 66
sw t0, 364(sp)
lw t0, 124(sp)
lw t1, 364(sp)
qmul t0, t0, t1
sw t0, 368(sp)
lw t0, 360(sp)
lw t1, 368(sp)
add t0, t0, t1
sw t0, 372(sp)
li t0, 66
sw t0, 376(sp)
lw t0, 128(sp)
lw t1, 376(sp)
qmul t0, t0, t1
sw t0, 380(sp)
lw t0, 356(sp)
sw t0, 384(sp)
lw t0, 372(sp)
sw t0, 388(sp)
lw t0, 380(sp)
sw t0, 392(sp)
lw a0, 384(sp)
lw a1, 388(sp)
lw a2, 392(sp)
jal ra, vec3_unit
sw a0, 396(sp)
sw a1, 400(sp)
sw a2, 404(sp)
lw t0, 396(sp)
sw t0, 132(sp)
lw t0, 400(sp)
sw t0, 136(sp)
lw t0, 404(sp)
sw t0, 140(sp)
li t0, 1
sw t0, 408(sp)
lw t0, 408(sp)
sw t0, 32(sp)
lw t0, 116(sp)
sw t0, 60(sp)
lw t0, 120(sp)
sw t0, 36(sp)
lw t0, 124(sp)
sw t0, 40(sp)
lw t0, 128(sp)
sw t0, 44(sp)
lw t0, 132(sp)
sw t0, 48(sp)
lw t0, 136(sp)
sw t0, 52(sp)
lw t0, 140(sp)
sw t0, 56(sp)
lw a0, 32(sp)
lw a1, 36(sp)
lw a2, 40(sp)
lw a3, 44(sp)
lw a4, 48(sp)
lw a5, 52(sp)
lw a6, 56(sp)
lw a7, 60(sp)
lw t0, 64(sp)
sw t0, 416(sp)
lw t0, 68(sp)
sw t0, 420(sp)
lw t0, 72(sp)
sw t0, 424(sp)
lw t0, 76(sp)
sw t0, 428(sp)
lw t0, 80(sp)
sw t0, 432(sp)
lw t0, 84(sp)
sw t0, 436(sp)
lw ra, 412(sp)
addi sp, sp, 416
jalr x0, ra, 0

.globl hit_sphere
hit_sphere:
addi sp, sp, -692
sw ra, 688(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
sw a3, 12(sp)
sw a4, 16(sp)
sw a5, 20(sp)
sw a6, 24(sp)
sw a7, 28(sp)
lw t0, 692(sp)
sw t0, 32(sp)
.L_hit_sphere_0:
la t0, SPHERE_X
sw t0, 164(sp)
li t0, 2
sw t0, 168(sp)
lw t0, 0(sp)
lw t1, 168(sp)
sll t0, t0, t1
sw t0, 172(sp)
lw t0, 164(sp)
lw t1, 172(sp)
add t0, t0, t1
sw t0, 176(sp)
lw t0, 176(sp)
lw t0, 0(t0)
sw t0, 180(sp)
la t0, SPHERE_Y
sw t0, 184(sp)
li t0, 2
sw t0, 188(sp)
lw t0, 0(sp)
lw t1, 188(sp)
sll t0, t0, t1
sw t0, 192(sp)
lw t0, 184(sp)
lw t1, 192(sp)
add t0, t0, t1
sw t0, 196(sp)
lw t0, 196(sp)
lw t0, 0(t0)
sw t0, 200(sp)
la t0, SPHERE_Z
sw t0, 204(sp)
li t0, 2
sw t0, 208(sp)
lw t0, 0(sp)
lw t1, 208(sp)
sll t0, t0, t1
sw t0, 212(sp)
lw t0, 204(sp)
lw t1, 212(sp)
add t0, t0, t1
sw t0, 216(sp)
lw t0, 216(sp)
lw t0, 0(t0)
sw t0, 220(sp)
lw t0, 180(sp)
sw t0, 224(sp)
lw t0, 200(sp)
sw t0, 228(sp)
lw t0, 220(sp)
sw t0, 232(sp)
lw t0, 224(sp)
sw t0, 92(sp)
lw t0, 228(sp)
sw t0, 96(sp)
lw t0, 232(sp)
sw t0, 100(sp)
la t0, SPHERE_R
sw t0, 236(sp)
li t0, 2
sw t0, 240(sp)
lw t0, 0(sp)
lw t1, 240(sp)
sll t0, t0, t1
sw t0, 244(sp)
lw t0, 236(sp)
lw t1, 244(sp)
add t0, t0, t1
sw t0, 248(sp)
lw t0, 248(sp)
lw t0, 0(t0)
sw t0, 252(sp)
lw t0, 252(sp)
sw t0, 104(sp)
la t0, SPHERE_R2
sw t0, 256(sp)
li t0, 2
sw t0, 260(sp)
lw t0, 0(sp)
lw t1, 260(sp)
sll t0, t0, t1
sw t0, 264(sp)
lw t0, 256(sp)
lw t1, 264(sp)
add t0, t0, t1
sw t0, 268(sp)
lw t0, 268(sp)
lw t0, 0(t0)
sw t0, 272(sp)
lw t0, 272(sp)
sw t0, 108(sp)
li t0, 0
sw t0, 276(sp)
lw t0, 276(sp)
sw t0, 36(sp)
li t0, 0
sw t0, 280(sp)
li t0, 0
sw t0, 284(sp)
li t0, 0
sw t0, 288(sp)
lw t0, 280(sp)
sw t0, 292(sp)
lw t0, 284(sp)
sw t0, 296(sp)
lw t0, 288(sp)
sw t0, 300(sp)
lw t0, 292(sp)
sw t0, 40(sp)
lw t0, 296(sp)
sw t0, 44(sp)
lw t0, 300(sp)
sw t0, 48(sp)
li t0, 0
sw t0, 304(sp)
li t0, 0
sw t0, 308(sp)
li t0, 0
sw t0, 312(sp)
lw t0, 304(sp)
sw t0, 316(sp)
lw t0, 308(sp)
sw t0, 320(sp)
lw t0, 312(sp)
sw t0, 324(sp)
lw t0, 316(sp)
sw t0, 52(sp)
lw t0, 320(sp)
sw t0, 56(sp)
lw t0, 324(sp)
sw t0, 60(sp)
li t0, 0
sw t0, 328(sp)
lw t0, 328(sp)
sw t0, 64(sp)
li t0, 0
sw t0, 332(sp)
lw t0, 332(sp)
sw t0, 68(sp)
la t0, SPHERE_MAT
sw t0, 336(sp)
li t0, 2
sw t0, 340(sp)
lw t0, 0(sp)
lw t1, 340(sp)
sll t0, t0, t1
sw t0, 344(sp)
lw t0, 336(sp)
lw t1, 344(sp)
add t0, t0, t1
sw t0, 348(sp)
lw t0, 348(sp)
lw t0, 0(t0)
sw t0, 352(sp)
lw t0, 352(sp)
sw t0, 72(sp)
la t0, SPHERE_AR
sw t0, 356(sp)
li t0, 2
sw t0, 360(sp)
lw t0, 0(sp)
lw t1, 360(sp)
sll t0, t0, t1
sw t0, 364(sp)
lw t0, 356(sp)
lw t1, 364(sp)
add t0, t0, t1
sw t0, 368(sp)
lw t0, 368(sp)
lw t0, 0(t0)
sw t0, 372(sp)
la t0, SPHERE_AG
sw t0, 376(sp)
li t0, 2
sw t0, 380(sp)
lw t0, 0(sp)
lw t1, 380(sp)
sll t0, t0, t1
sw t0, 384(sp)
lw t0, 376(sp)
lw t1, 384(sp)
add t0, t0, t1
sw t0, 388(sp)
lw t0, 388(sp)
lw t0, 0(t0)
sw t0, 392(sp)
la t0, SPHERE_AB
sw t0, 396(sp)
li t0, 2
sw t0, 400(sp)
lw t0, 0(sp)
lw t1, 400(sp)
sll t0, t0, t1
sw t0, 404(sp)
lw t0, 396(sp)
lw t1, 404(sp)
add t0, t0, t1
sw t0, 408(sp)
lw t0, 408(sp)
lw t0, 0(t0)
sw t0, 412(sp)
lw t0, 372(sp)
sw t0, 416(sp)
lw t0, 392(sp)
sw t0, 420(sp)
lw t0, 412(sp)
sw t0, 424(sp)
lw t0, 416(sp)
sw t0, 76(sp)
lw t0, 420(sp)
sw t0, 80(sp)
lw t0, 424(sp)
sw t0, 84(sp)
la t0, SPHERE_PARAM
sw t0, 428(sp)
li t0, 2
sw t0, 432(sp)
lw t0, 0(sp)
lw t1, 432(sp)
sll t0, t0, t1
sw t0, 436(sp)
lw t0, 428(sp)
lw t1, 436(sp)
add t0, t0, t1
sw t0, 440(sp)
lw t0, 440(sp)
lw t0, 0(t0)
sw t0, 444(sp)
lw t0, 444(sp)
sw t0, 88(sp)
lw a0, 4(sp)
lw a1, 8(sp)
lw a2, 12(sp)
lw a3, 92(sp)
lw a4, 96(sp)
lw a5, 100(sp)
jal ra, vec3_sub
sw a0, 448(sp)
sw a1, 452(sp)
sw a2, 456(sp)
lw t0, 448(sp)
sw t0, 112(sp)
lw t0, 452(sp)
sw t0, 116(sp)
lw t0, 456(sp)
sw t0, 120(sp)
lw a0, 112(sp)
lw a1, 116(sp)
lw a2, 120(sp)
lw a3, 16(sp)
lw a4, 20(sp)
lw a5, 24(sp)
jal ra, vec3_dot
sw a0, 460(sp)
lw t0, 460(sp)
sw t0, 124(sp)
lw t0, 124(sp)
lw t1, 104(sp)
slt t0, t0, t1
xori t0, t0, 1
sw t0, 464(sp)
lw t0, 464(sp)
bnez t0, .L_hit_sphere_1
j .L_hit_sphere_2
.L_hit_sphere_1:
lw a0, 36(sp)
lw a1, 40(sp)
lw a2, 44(sp)
lw a3, 48(sp)
lw a4, 52(sp)
lw a5, 56(sp)
lw a6, 60(sp)
lw a7, 64(sp)
lw t0, 68(sp)
sw t0, 692(sp)
lw t0, 72(sp)
sw t0, 696(sp)
lw t0, 76(sp)
sw t0, 700(sp)
lw t0, 80(sp)
sw t0, 704(sp)
lw t0, 84(sp)
sw t0, 708(sp)
lw t0, 88(sp)
sw t0, 712(sp)
lw ra, 688(sp)
addi sp, sp, 692
jalr x0, ra, 0
.L_hit_sphere_2:
lw a0, 16(sp)
lw a1, 20(sp)
lw a2, 24(sp)
lw a3, 124(sp)
jal ra, vec3_scale
sw a0, 468(sp)
sw a1, 472(sp)
sw a2, 476(sp)
lw a0, 112(sp)
lw a1, 116(sp)
lw a2, 120(sp)
lw a3, 468(sp)
lw a4, 472(sp)
lw a5, 476(sp)
jal ra, vec3_sub
sw a0, 480(sp)
sw a1, 484(sp)
sw a2, 488(sp)
lw t0, 480(sp)
sw t0, 128(sp)
lw t0, 484(sp)
sw t0, 132(sp)
lw t0, 488(sp)
sw t0, 136(sp)
lw a0, 128(sp)
jal ra, q_abs
sw a0, 500(sp)
lw t0, 500(sp)
lw t1, 104(sp)
slt t0, t1, t0
sw t0, 504(sp)
lw t0, 504(sp)
bnez t0, .L_hit_sphere_4
j .L_hit_sphere_3
.L_hit_sphere_3:
lw a0, 132(sp)
jal ra, q_abs
sw a0, 508(sp)
lw t0, 508(sp)
lw t1, 104(sp)
slt t0, t1, t0
sw t0, 512(sp)
lw t0, 512(sp)
sw t0, 496(sp)
j .L_hit_sphere_5
.L_hit_sphere_4:
li t0, 1
sw t0, 496(sp)
j .L_hit_sphere_5
.L_hit_sphere_5:
lw t0, 496(sp)
bnez t0, .L_hit_sphere_7
j .L_hit_sphere_6
.L_hit_sphere_6:
lw a0, 136(sp)
jal ra, q_abs
sw a0, 516(sp)
lw t0, 516(sp)
lw t1, 104(sp)
slt t0, t1, t0
sw t0, 520(sp)
lw t0, 520(sp)
sw t0, 492(sp)
j .L_hit_sphere_8
.L_hit_sphere_7:
li t0, 1
sw t0, 492(sp)
j .L_hit_sphere_8
.L_hit_sphere_8:
lw t0, 492(sp)
bnez t0, .L_hit_sphere_9
j .L_hit_sphere_10
.L_hit_sphere_9:
lw a0, 36(sp)
lw a1, 40(sp)
lw a2, 44(sp)
lw a3, 48(sp)
lw a4, 52(sp)
lw a5, 56(sp)
lw a6, 60(sp)
lw a7, 64(sp)
lw t0, 68(sp)
sw t0, 692(sp)
lw t0, 72(sp)
sw t0, 696(sp)
lw t0, 76(sp)
sw t0, 700(sp)
lw t0, 80(sp)
sw t0, 704(sp)
lw t0, 84(sp)
sw t0, 708(sp)
lw t0, 88(sp)
sw t0, 712(sp)
lw ra, 688(sp)
addi sp, sp, 692
jalr x0, ra, 0
.L_hit_sphere_10:
lw a0, 128(sp)
lw a1, 132(sp)
lw a2, 136(sp)
jal ra, vec3_length_squared
sw a0, 524(sp)
lw t0, 108(sp)
lw t1, 524(sp)
sub t0, t0, t1
sw t0, 528(sp)
lw t0, 528(sp)
sw t0, 140(sp)
li t0, 0
sw t0, 532(sp)
lw t0, 140(sp)
lw t1, 532(sp)
slt t0, t0, t1
sw t0, 536(sp)
lw t0, 536(sp)
bnez t0, .L_hit_sphere_11
j .L_hit_sphere_12
.L_hit_sphere_11:
lw a0, 36(sp)
lw a1, 40(sp)
lw a2, 44(sp)
lw a3, 48(sp)
lw a4, 52(sp)
lw a5, 56(sp)
lw a6, 60(sp)
lw a7, 64(sp)
lw t0, 68(sp)
sw t0, 692(sp)
lw t0, 72(sp)
sw t0, 696(sp)
lw t0, 76(sp)
sw t0, 700(sp)
lw t0, 80(sp)
sw t0, 704(sp)
lw t0, 84(sp)
sw t0, 708(sp)
lw t0, 88(sp)
sw t0, 712(sp)
lw ra, 688(sp)
addi sp, sp, 692
jalr x0, ra, 0
.L_hit_sphere_12:
lw t0, 140(sp)
qsqrt t0, t0
sw t0, 540(sp)
lw t0, 540(sp)
sw t0, 144(sp)
lw t0, 124(sp)
sub t0, x0, t0
sw t0, 544(sp)
lw t0, 544(sp)
lw t1, 144(sp)
sub t0, t0, t1
sw t0, 548(sp)
lw t0, 548(sp)
sw t0, 148(sp)
lw t0, 148(sp)
lw t1, 28(sp)
slt t0, t1, t0
xori t0, t0, 1
sw t0, 556(sp)
lw t0, 556(sp)
bnez t0, .L_hit_sphere_14
j .L_hit_sphere_13
.L_hit_sphere_13:
lw t0, 148(sp)
lw t1, 32(sp)
slt t0, t0, t1
xori t0, t0, 1
sw t0, 560(sp)
lw t0, 560(sp)
sw t0, 552(sp)
j .L_hit_sphere_15
.L_hit_sphere_14:
li t0, 1
sw t0, 552(sp)
j .L_hit_sphere_15
.L_hit_sphere_15:
lw t0, 552(sp)
bnez t0, .L_hit_sphere_16
j .L_hit_sphere_17
.L_hit_sphere_16:
li t0, 2
sw t0, 564(sp)
lw t0, 72(sp)
lw t1, 564(sp)
sub t0, t0, t1
sltu t0, x0, t0
sw t0, 568(sp)
lw t0, 568(sp)
bnez t0, .L_hit_sphere_18
j .L_hit_sphere_19
.L_hit_sphere_18:
lw a0, 36(sp)
lw a1, 40(sp)
lw a2, 44(sp)
lw a3, 48(sp)
lw a4, 52(sp)
lw a5, 56(sp)
lw a6, 60(sp)
lw a7, 64(sp)
lw t0, 68(sp)
sw t0, 692(sp)
lw t0, 72(sp)
sw t0, 696(sp)
lw t0, 76(sp)
sw t0, 700(sp)
lw t0, 80(sp)
sw t0, 704(sp)
lw t0, 84(sp)
sw t0, 708(sp)
lw t0, 88(sp)
sw t0, 712(sp)
lw ra, 688(sp)
addi sp, sp, 692
jalr x0, ra, 0
.L_hit_sphere_19:
lw t0, 124(sp)
sub t0, x0, t0
sw t0, 572(sp)
lw t0, 572(sp)
lw t1, 144(sp)
add t0, t0, t1
sw t0, 576(sp)
lw t0, 576(sp)
sw t0, 148(sp)
lw t0, 148(sp)
lw t1, 28(sp)
slt t0, t1, t0
xori t0, t0, 1
sw t0, 584(sp)
lw t0, 584(sp)
bnez t0, .L_hit_sphere_21
j .L_hit_sphere_20
.L_hit_sphere_20:
lw t0, 148(sp)
lw t1, 32(sp)
slt t0, t0, t1
xori t0, t0, 1
sw t0, 588(sp)
lw t0, 588(sp)
sw t0, 580(sp)
j .L_hit_sphere_22
.L_hit_sphere_21:
li t0, 1
sw t0, 580(sp)
j .L_hit_sphere_22
.L_hit_sphere_22:
lw t0, 580(sp)
bnez t0, .L_hit_sphere_23
j .L_hit_sphere_24
.L_hit_sphere_23:
lw a0, 36(sp)
lw a1, 40(sp)
lw a2, 44(sp)
lw a3, 48(sp)
lw a4, 52(sp)
lw a5, 56(sp)
lw a6, 60(sp)
lw a7, 64(sp)
lw t0, 68(sp)
sw t0, 692(sp)
lw t0, 72(sp)
sw t0, 696(sp)
lw t0, 76(sp)
sw t0, 700(sp)
lw t0, 80(sp)
sw t0, 704(sp)
lw t0, 84(sp)
sw t0, 708(sp)
lw t0, 88(sp)
sw t0, 712(sp)
lw ra, 688(sp)
addi sp, sp, 692
jalr x0, ra, 0
.L_hit_sphere_24:
j .L_hit_sphere_17
.L_hit_sphere_17:
lw a0, 4(sp)
lw a1, 8(sp)
lw a2, 12(sp)
lw a3, 16(sp)
lw a4, 20(sp)
lw a5, 24(sp)
lw a6, 148(sp)
jal ra, ray_at
sw a0, 592(sp)
sw a1, 596(sp)
sw a2, 600(sp)
lw a0, 592(sp)
lw a1, 596(sp)
lw a2, 600(sp)
lw a3, 92(sp)
lw a4, 96(sp)
lw a5, 100(sp)
jal ra, vec3_sub
sw a0, 604(sp)
sw a1, 608(sp)
sw a2, 612(sp)
lw a0, 604(sp)
lw a1, 608(sp)
lw a2, 612(sp)
jal ra, vec3_unit
sw a0, 616(sp)
sw a1, 620(sp)
sw a2, 624(sp)
lw t0, 616(sp)
sw t0, 152(sp)
lw t0, 620(sp)
sw t0, 156(sp)
lw t0, 624(sp)
sw t0, 160(sp)
li t0, 1
sw t0, 628(sp)
lw t0, 628(sp)
sw t0, 36(sp)
lw t0, 148(sp)
sw t0, 64(sp)
lw a0, 152(sp)
lw a1, 156(sp)
lw a2, 160(sp)
lw a3, 104(sp)
jal ra, vec3_scale
sw a0, 632(sp)
sw a1, 636(sp)
sw a2, 640(sp)
lw a0, 92(sp)
lw a1, 96(sp)
lw a2, 100(sp)
lw a3, 632(sp)
lw a4, 636(sp)
lw a5, 640(sp)
jal ra, vec3_add
sw a0, 644(sp)
sw a1, 648(sp)
sw a2, 652(sp)
lw t0, 644(sp)
sw t0, 40(sp)
lw t0, 648(sp)
sw t0, 44(sp)
lw t0, 652(sp)
sw t0, 48(sp)
lw a0, 16(sp)
lw a1, 20(sp)
lw a2, 24(sp)
lw a3, 152(sp)
lw a4, 156(sp)
lw a5, 160(sp)
jal ra, vec3_dot
sw a0, 656(sp)
li t0, 0
sw t0, 660(sp)
lw t0, 656(sp)
lw t1, 660(sp)
slt t0, t0, t1
sw t0, 664(sp)
lw t0, 664(sp)
bnez t0, .L_hit_sphere_25
j .L_hit_sphere_26
.L_hit_sphere_25:
li t0, 1
sw t0, 668(sp)
lw t0, 668(sp)
sw t0, 68(sp)
lw t0, 152(sp)
sw t0, 52(sp)
lw t0, 156(sp)
sw t0, 56(sp)
lw t0, 160(sp)
sw t0, 60(sp)
j .L_hit_sphere_27
.L_hit_sphere_26:
li t0, 0
sw t0, 672(sp)
lw t0, 672(sp)
sw t0, 68(sp)
lw a0, 152(sp)
lw a1, 156(sp)
lw a2, 160(sp)
jal ra, vec3_neg
sw a0, 676(sp)
sw a1, 680(sp)
sw a2, 684(sp)
lw t0, 676(sp)
sw t0, 52(sp)
lw t0, 680(sp)
sw t0, 56(sp)
lw t0, 684(sp)
sw t0, 60(sp)
j .L_hit_sphere_27
.L_hit_sphere_27:
lw a0, 36(sp)
lw a1, 40(sp)
lw a2, 44(sp)
lw a3, 48(sp)
lw a4, 52(sp)
lw a5, 56(sp)
lw a6, 60(sp)
lw a7, 64(sp)
lw t0, 68(sp)
sw t0, 692(sp)
lw t0, 72(sp)
sw t0, 696(sp)
lw t0, 76(sp)
sw t0, 700(sp)
lw t0, 80(sp)
sw t0, 704(sp)
lw t0, 84(sp)
sw t0, 708(sp)
lw t0, 88(sp)
sw t0, 712(sp)
lw ra, 688(sp)
addi sp, sp, 692
jalr x0, ra, 0

.globl main
main:
addi sp, sp, -208
sw ra, 204(sp)
.L_main_0:
jal ra, camera_init
sw a0, 124(sp)
sw a1, 128(sp)
sw a2, 132(sp)
sw a3, 136(sp)
sw a4, 140(sp)
sw a5, 144(sp)
sw a6, 148(sp)
sw a7, 152(sp)
lw t0, 0(sp)
sw t0, 156(sp)
lw t0, 4(sp)
sw t0, 160(sp)
lw t0, 8(sp)
sw t0, 164(sp)
lw t0, 12(sp)
sw t0, 168(sp)
lw t0, 16(sp)
sw t0, 172(sp)
lw t0, 20(sp)
sw t0, 176(sp)
lw t0, 24(sp)
sw t0, 180(sp)
lw t0, 28(sp)
sw t0, 184(sp)
lw t0, 32(sp)
sw t0, 188(sp)
lw t0, 36(sp)
sw t0, 192(sp)
lw t0, 40(sp)
sw t0, 196(sp)
lw t0, 124(sp)
sw t0, 48(sp)
lw t0, 128(sp)
sw t0, 52(sp)
lw t0, 132(sp)
sw t0, 56(sp)
lw t0, 136(sp)
sw t0, 60(sp)
lw t0, 140(sp)
sw t0, 64(sp)
lw t0, 144(sp)
sw t0, 68(sp)
lw t0, 148(sp)
sw t0, 72(sp)
lw t0, 152(sp)
sw t0, 76(sp)
lw t0, 156(sp)
sw t0, 80(sp)
lw t0, 160(sp)
sw t0, 84(sp)
lw t0, 164(sp)
sw t0, 88(sp)
lw t0, 168(sp)
sw t0, 92(sp)
lw t0, 172(sp)
sw t0, 96(sp)
lw t0, 176(sp)
sw t0, 100(sp)
lw t0, 180(sp)
sw t0, 104(sp)
lw t0, 184(sp)
sw t0, 108(sp)
lw t0, 188(sp)
sw t0, 112(sp)
lw t0, 192(sp)
sw t0, 116(sp)
lw t0, 196(sp)
sw t0, 120(sp)
li t0, 42
sw t0, 200(sp)
lw a0, 200(sp)
lw a1, 48(sp)
lw a2, 52(sp)
lw a3, 56(sp)
lw a4, 60(sp)
lw a5, 64(sp)
lw a6, 68(sp)
lw a7, 72(sp)
lw t0, 76(sp)
sw t0, 0(sp)
lw t0, 80(sp)
sw t0, 4(sp)
lw t0, 84(sp)
sw t0, 8(sp)
lw t0, 88(sp)
sw t0, 12(sp)
lw t0, 92(sp)
sw t0, 16(sp)
lw t0, 96(sp)
sw t0, 20(sp)
lw t0, 100(sp)
sw t0, 24(sp)
lw t0, 104(sp)
sw t0, 28(sp)
lw t0, 108(sp)
sw t0, 32(sp)
lw t0, 112(sp)
sw t0, 36(sp)
lw t0, 116(sp)
sw t0, 40(sp)
lw t0, 120(sp)
sw t0, 44(sp)
jal ra, camera_render
lw ra, 204(sp)
addi sp, sp, 208
jalr x0, ra, 0

.globl make_ray
make_ray:
addi sp, sp, -64
sw ra, 60(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
sw a3, 12(sp)
sw a4, 16(sp)
sw a5, 20(sp)
.L_make_ray_0:
lw t0, 0(sp)
sw t0, 24(sp)
lw t0, 4(sp)
sw t0, 28(sp)
lw t0, 8(sp)
sw t0, 32(sp)
lw a0, 12(sp)
lw a1, 16(sp)
lw a2, 20(sp)
jal ra, vec3_unit
sw a0, 48(sp)
sw a1, 52(sp)
sw a2, 56(sp)
lw t0, 48(sp)
sw t0, 36(sp)
lw t0, 52(sp)
sw t0, 40(sp)
lw t0, 56(sp)
sw t0, 44(sp)
lw a0, 24(sp)
lw a1, 28(sp)
lw a2, 32(sp)
lw a3, 36(sp)
lw a4, 40(sp)
lw a5, 44(sp)
lw ra, 60(sp)
addi sp, sp, 64
jalr x0, ra, 0

.globl material_scatter
material_scatter:
addi sp, sp, -588
sw ra, 584(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
sw a3, 12(sp)
sw a4, 16(sp)
sw a5, 20(sp)
sw a6, 24(sp)
sw a7, 28(sp)
lw t0, 588(sp)
sw t0, 32(sp)
lw t0, 592(sp)
sw t0, 36(sp)
lw t0, 596(sp)
sw t0, 40(sp)
lw t0, 600(sp)
sw t0, 44(sp)
lw t0, 604(sp)
sw t0, 48(sp)
lw t0, 608(sp)
sw t0, 52(sp)
lw t0, 612(sp)
sw t0, 56(sp)
lw t0, 616(sp)
sw t0, 60(sp)
lw t0, 620(sp)
sw t0, 64(sp)
lw t0, 624(sp)
sw t0, 68(sp)
lw t0, 628(sp)
sw t0, 72(sp)
lw t0, 632(sp)
sw t0, 76(sp)
lw t0, 636(sp)
sw t0, 80(sp)
.L_material_scatter_0:
lw t0, 0(sp)
sw t0, 84(sp)
li t0, 0
sw t0, 228(sp)
lw t0, 228(sp)
sw t0, 88(sp)
lw t0, 68(sp)
sw t0, 92(sp)
lw t0, 72(sp)
sw t0, 96(sp)
lw t0, 76(sp)
sw t0, 100(sp)
lw t0, 4(sp)
sw t0, 104(sp)
lw t0, 8(sp)
sw t0, 108(sp)
lw t0, 12(sp)
sw t0, 112(sp)
lw t0, 16(sp)
sw t0, 116(sp)
lw t0, 20(sp)
sw t0, 120(sp)
lw t0, 24(sp)
sw t0, 124(sp)
li t0, 0
sw t0, 232(sp)
lw t0, 64(sp)
lw t1, 232(sp)
sub t0, t0, t1
sltiu t0, t0, 1
sw t0, 236(sp)
lw t0, 236(sp)
bnez t0, .L_material_scatter_1
j .L_material_scatter_2
.L_material_scatter_1:
lw a0, 84(sp)
jal ra, random_unit_vector
sw a0, 240(sp)
sw a1, 244(sp)
sw a2, 248(sp)
sw a3, 252(sp)
lw t0, 240(sp)
sw t0, 128(sp)
lw t0, 244(sp)
sw t0, 132(sp)
lw t0, 248(sp)
sw t0, 136(sp)
lw t0, 252(sp)
sw t0, 140(sp)
lw t0, 128(sp)
sw t0, 84(sp)
lw a0, 44(sp)
lw a1, 48(sp)
lw a2, 52(sp)
lw a3, 132(sp)
lw a4, 136(sp)
lw a5, 140(sp)
jal ra, vec3_add
sw a0, 256(sp)
sw a1, 260(sp)
sw a2, 264(sp)
lw t0, 256(sp)
sw t0, 152(sp)
lw t0, 260(sp)
sw t0, 156(sp)
lw t0, 264(sp)
sw t0, 160(sp)
lw a0, 152(sp)
lw a1, 156(sp)
lw a2, 160(sp)
jal ra, vec3_near_zero
sw a0, 268(sp)
li t0, 0
sw t0, 272(sp)
lw t0, 268(sp)
lw t1, 272(sp)
sub t0, t0, t1
sltu t0, x0, t0
sw t0, 276(sp)
lw t0, 276(sp)
bnez t0, .L_material_scatter_3
j .L_material_scatter_4
.L_material_scatter_3:
lw t0, 44(sp)
sw t0, 152(sp)
lw t0, 48(sp)
sw t0, 156(sp)
lw t0, 52(sp)
sw t0, 160(sp)
j .L_material_scatter_4
.L_material_scatter_4:
lw a0, 32(sp)
lw a1, 36(sp)
lw a2, 40(sp)
lw a3, 152(sp)
lw a4, 156(sp)
lw a5, 160(sp)
jal ra, make_ray
sw a0, 280(sp)
sw a1, 284(sp)
sw a2, 288(sp)
sw a3, 292(sp)
sw a4, 296(sp)
sw a5, 300(sp)
lw t0, 280(sp)
sw t0, 104(sp)
lw t0, 284(sp)
sw t0, 108(sp)
lw t0, 288(sp)
sw t0, 112(sp)
lw t0, 292(sp)
sw t0, 116(sp)
lw t0, 296(sp)
sw t0, 120(sp)
lw t0, 300(sp)
sw t0, 124(sp)
li t0, 1
sw t0, 304(sp)
lw t0, 304(sp)
sw t0, 88(sp)
lw a0, 84(sp)
lw a1, 88(sp)
lw a2, 92(sp)
lw a3, 96(sp)
lw a4, 100(sp)
lw a5, 104(sp)
lw a6, 108(sp)
lw a7, 112(sp)
lw t0, 116(sp)
sw t0, 588(sp)
lw t0, 120(sp)
sw t0, 592(sp)
lw t0, 124(sp)
sw t0, 596(sp)
lw ra, 584(sp)
addi sp, sp, 588
jalr x0, ra, 0
.L_material_scatter_2:
li t0, 1
sw t0, 308(sp)
lw t0, 64(sp)
lw t1, 308(sp)
sub t0, t0, t1
sltiu t0, t0, 1
sw t0, 312(sp)
lw t0, 312(sp)
bnez t0, .L_material_scatter_5
j .L_material_scatter_6
.L_material_scatter_5:
lw a0, 16(sp)
lw a1, 20(sp)
lw a2, 24(sp)
lw a3, 44(sp)
lw a4, 48(sp)
lw a5, 52(sp)
jal ra, vec3_reflect
sw a0, 316(sp)
sw a1, 320(sp)
sw a2, 324(sp)
lw t0, 316(sp)
sw t0, 164(sp)
lw t0, 320(sp)
sw t0, 168(sp)
lw t0, 324(sp)
sw t0, 172(sp)
lw a0, 84(sp)
jal ra, random_unit_vector
sw a0, 328(sp)
sw a1, 332(sp)
sw a2, 336(sp)
sw a3, 340(sp)
lw t0, 328(sp)
sw t0, 128(sp)
lw t0, 332(sp)
sw t0, 132(sp)
lw t0, 336(sp)
sw t0, 136(sp)
lw t0, 340(sp)
sw t0, 140(sp)
lw t0, 128(sp)
sw t0, 84(sp)
lw a0, 164(sp)
lw a1, 168(sp)
lw a2, 172(sp)
jal ra, vec3_unit
sw a0, 344(sp)
sw a1, 348(sp)
sw a2, 352(sp)
lw a0, 132(sp)
lw a1, 136(sp)
lw a2, 140(sp)
lw a3, 80(sp)
jal ra, vec3_scale
sw a0, 356(sp)
sw a1, 360(sp)
sw a2, 364(sp)
lw a0, 344(sp)
lw a1, 348(sp)
lw a2, 352(sp)
lw a3, 356(sp)
lw a4, 360(sp)
lw a5, 364(sp)
jal ra, vec3_add
sw a0, 368(sp)
sw a1, 372(sp)
sw a2, 376(sp)
lw t0, 368(sp)
sw t0, 152(sp)
lw t0, 372(sp)
sw t0, 156(sp)
lw t0, 376(sp)
sw t0, 160(sp)
lw a0, 32(sp)
lw a1, 36(sp)
lw a2, 40(sp)
lw a3, 152(sp)
lw a4, 156(sp)
lw a5, 160(sp)
jal ra, make_ray
sw a0, 380(sp)
sw a1, 384(sp)
sw a2, 388(sp)
sw a3, 392(sp)
sw a4, 396(sp)
sw a5, 400(sp)
lw t0, 380(sp)
sw t0, 104(sp)
lw t0, 384(sp)
sw t0, 108(sp)
lw t0, 388(sp)
sw t0, 112(sp)
lw t0, 392(sp)
sw t0, 116(sp)
lw t0, 396(sp)
sw t0, 120(sp)
lw t0, 400(sp)
sw t0, 124(sp)
lw a0, 116(sp)
lw a1, 120(sp)
lw a2, 124(sp)
lw a3, 44(sp)
lw a4, 48(sp)
lw a5, 52(sp)
jal ra, vec3_dot
sw a0, 404(sp)
li t0, 0
sw t0, 408(sp)
lw t0, 404(sp)
lw t1, 408(sp)
slt t0, t1, t0
sw t0, 412(sp)
lw t0, 412(sp)
bnez t0, .L_material_scatter_7
j .L_material_scatter_8
.L_material_scatter_7:
li t0, 1
sw t0, 416(sp)
lw t0, 416(sp)
sw t0, 88(sp)
j .L_material_scatter_8
.L_material_scatter_8:
lw a0, 84(sp)
lw a1, 88(sp)
lw a2, 92(sp)
lw a3, 96(sp)
lw a4, 100(sp)
lw a5, 104(sp)
lw a6, 108(sp)
lw a7, 112(sp)
lw t0, 116(sp)
sw t0, 588(sp)
lw t0, 120(sp)
sw t0, 592(sp)
lw t0, 124(sp)
sw t0, 596(sp)
lw ra, 584(sp)
addi sp, sp, 588
jalr x0, ra, 0
.L_material_scatter_6:
li t0, 0
sw t0, 420(sp)
lw t0, 60(sp)
lw t1, 420(sp)
sub t0, t0, t1
sltu t0, x0, t0
sw t0, 424(sp)
lw t0, 424(sp)
bnez t0, .L_material_scatter_9
j .L_material_scatter_10
.L_material_scatter_9:
lw t0, 80(sp)
qrcp t0, t0
sw t0, 428(sp)
lw t0, 428(sp)
sw t0, 176(sp)
j .L_material_scatter_11
.L_material_scatter_10:
lw t0, 80(sp)
sw t0, 176(sp)
j .L_material_scatter_11
.L_material_scatter_11:
lw a0, 16(sp)
lw a1, 20(sp)
lw a2, 24(sp)
jal ra, vec3_neg
sw a0, 432(sp)
sw a1, 436(sp)
sw a2, 440(sp)
lw a0, 432(sp)
lw a1, 436(sp)
lw a2, 440(sp)
lw a3, 44(sp)
lw a4, 48(sp)
lw a5, 52(sp)
jal ra, vec3_dot
sw a0, 444(sp)
li t0, 65536
sw t0, 448(sp)
lw a0, 444(sp)
lw a1, 448(sp)
jal ra, q_min
sw a0, 452(sp)
lw t0, 452(sp)
sw t0, 180(sp)
li t0, 65536
sw t0, 456(sp)
lw t0, 180(sp)
lw t1, 180(sp)
qmul t0, t0, t1
sw t0, 460(sp)
lw t0, 456(sp)
lw t1, 460(sp)
sub t0, t0, t1
sw t0, 464(sp)
lw a0, 464(sp)
jal ra, q_abs
sw a0, 468(sp)
lw t0, 468(sp)
qsqrt t0, t0
sw t0, 472(sp)
lw t0, 472(sp)
sw t0, 184(sp)
li t0, 0
sw t0, 476(sp)
lw t0, 476(sp)
sw t0, 224(sp)
lw t0, 176(sp)
lw t1, 184(sp)
qmul t0, t0, t1
sw t0, 480(sp)
li t0, 65536
sw t0, 484(sp)
lw t0, 480(sp)
lw t1, 484(sp)
slt t0, t1, t0
sw t0, 488(sp)
lw t0, 488(sp)
bnez t0, .L_material_scatter_12
j .L_material_scatter_13
.L_material_scatter_12:
li t0, 1
sw t0, 492(sp)
lw t0, 492(sp)
sw t0, 224(sp)
j .L_material_scatter_13
.L_material_scatter_13:
li t0, 0
sw t0, 496(sp)
lw t0, 224(sp)
lw t1, 496(sp)
sub t0, t0, t1
sltu t0, x0, t0
sw t0, 500(sp)
lw t0, 500(sp)
bnez t0, .L_material_scatter_14
j .L_material_scatter_15
.L_material_scatter_14:
lw a0, 16(sp)
lw a1, 20(sp)
lw a2, 24(sp)
lw a3, 44(sp)
lw a4, 48(sp)
lw a5, 52(sp)
jal ra, vec3_reflect
sw a0, 504(sp)
sw a1, 508(sp)
sw a2, 512(sp)
lw t0, 504(sp)
sw t0, 188(sp)
lw t0, 508(sp)
sw t0, 192(sp)
lw t0, 512(sp)
sw t0, 196(sp)
j .L_material_scatter_16
.L_material_scatter_15:
lw a0, 84(sp)
jal ra, random_q16
sw a0, 516(sp)
sw a1, 520(sp)
lw t0, 516(sp)
sw t0, 144(sp)
lw t0, 520(sp)
sw t0, 148(sp)
lw t0, 144(sp)
sw t0, 84(sp)
lw a0, 180(sp)
lw a1, 176(sp)
jal ra, schlick_reflectance
sw a0, 524(sp)
lw t0, 524(sp)
lw t1, 148(sp)
slt t0, t1, t0
sw t0, 528(sp)
lw t0, 528(sp)
bnez t0, .L_material_scatter_17
j .L_material_scatter_18
.L_material_scatter_17:
lw a0, 16(sp)
lw a1, 20(sp)
lw a2, 24(sp)
lw a3, 44(sp)
lw a4, 48(sp)
lw a5, 52(sp)
jal ra, vec3_reflect
sw a0, 532(sp)
sw a1, 536(sp)
sw a2, 540(sp)
lw t0, 532(sp)
sw t0, 188(sp)
lw t0, 536(sp)
sw t0, 192(sp)
lw t0, 540(sp)
sw t0, 196(sp)
j .L_material_scatter_19
.L_material_scatter_18:
lw a0, 16(sp)
lw a1, 20(sp)
lw a2, 24(sp)
lw a3, 44(sp)
lw a4, 48(sp)
lw a5, 52(sp)
lw a6, 176(sp)
jal ra, vec3_refract
sw a0, 544(sp)
sw a1, 548(sp)
sw a2, 552(sp)
lw t0, 544(sp)
sw t0, 188(sp)
lw t0, 548(sp)
sw t0, 192(sp)
lw t0, 552(sp)
sw t0, 196(sp)
j .L_material_scatter_19
.L_material_scatter_19:
j .L_material_scatter_16
.L_material_scatter_16:
lw a0, 32(sp)
lw a1, 36(sp)
lw a2, 40(sp)
lw a3, 188(sp)
lw a4, 192(sp)
lw a5, 196(sp)
jal ra, make_ray
sw a0, 556(sp)
sw a1, 560(sp)
sw a2, 564(sp)
sw a3, 568(sp)
sw a4, 572(sp)
sw a5, 576(sp)
lw t0, 556(sp)
sw t0, 104(sp)
lw t0, 560(sp)
sw t0, 108(sp)
lw t0, 564(sp)
sw t0, 112(sp)
lw t0, 568(sp)
sw t0, 116(sp)
lw t0, 572(sp)
sw t0, 120(sp)
lw t0, 576(sp)
sw t0, 124(sp)
li t0, 1
sw t0, 580(sp)
lw t0, 580(sp)
sw t0, 88(sp)
lw a0, 84(sp)
lw a1, 88(sp)
lw a2, 92(sp)
lw a3, 96(sp)
lw a4, 100(sp)
lw a5, 104(sp)
lw a6, 108(sp)
lw a7, 112(sp)
lw t0, 116(sp)
sw t0, 588(sp)
lw t0, 120(sp)
sw t0, 592(sp)
lw t0, 124(sp)
sw t0, 596(sp)
lw ra, 584(sp)
addi sp, sp, 588
jalr x0, ra, 0

.globl q_abs
q_abs:
addi sp, sp, -20
sw ra, 16(sp)
sw a0, 0(sp)
.L_q_abs_0:
li t0, 0
sw t0, 4(sp)
lw t0, 0(sp)
lw t1, 4(sp)
slt t0, t0, t1
sw t0, 8(sp)
lw t0, 8(sp)
bnez t0, .L_q_abs_1
j .L_q_abs_2
.L_q_abs_1:
lw t0, 0(sp)
sub t0, x0, t0
sw t0, 12(sp)
lw a0, 12(sp)
lw ra, 16(sp)
addi sp, sp, 20
jalr x0, ra, 0
.L_q_abs_2:
lw a0, 0(sp)
lw ra, 16(sp)
addi sp, sp, 20
jalr x0, ra, 0

.globl q_clamp
q_clamp:
addi sp, sp, -24
sw ra, 20(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
.L_q_clamp_0:
lw t0, 0(sp)
lw t1, 4(sp)
slt t0, t0, t1
sw t0, 12(sp)
lw t0, 12(sp)
bnez t0, .L_q_clamp_1
j .L_q_clamp_2
.L_q_clamp_1:
lw a0, 4(sp)
lw ra, 20(sp)
addi sp, sp, 24
jalr x0, ra, 0
.L_q_clamp_2:
lw t0, 0(sp)
lw t1, 8(sp)
slt t0, t1, t0
sw t0, 16(sp)
lw t0, 16(sp)
bnez t0, .L_q_clamp_3
j .L_q_clamp_4
.L_q_clamp_3:
lw a0, 8(sp)
lw ra, 20(sp)
addi sp, sp, 24
jalr x0, ra, 0
.L_q_clamp_4:
lw a0, 0(sp)
lw ra, 20(sp)
addi sp, sp, 24
jalr x0, ra, 0

.globl q_min
q_min:
addi sp, sp, -16
sw ra, 12(sp)
sw a0, 0(sp)
sw a1, 4(sp)
.L_q_min_0:
lw t0, 0(sp)
lw t1, 4(sp)
slt t0, t0, t1
sw t0, 8(sp)
lw t0, 8(sp)
bnez t0, .L_q_min_1
j .L_q_min_2
.L_q_min_1:
lw a0, 0(sp)
lw ra, 12(sp)
addi sp, sp, 16
jalr x0, ra, 0
.L_q_min_2:
lw a0, 4(sp)
lw ra, 12(sp)
addi sp, sp, 16
jalr x0, ra, 0

.globl q_tan_small
q_tan_small:
addi sp, sp, -96
sw ra, 92(sp)
sw a0, 0(sp)
.L_q_tan_small_0:
lw t0, 0(sp)
lw t1, 0(sp)
qmul t0, t0, t1
sw t0, 24(sp)
lw t0, 24(sp)
sw t0, 4(sp)
lw t0, 4(sp)
lw t1, 0(sp)
qmul t0, t0, t1
sw t0, 28(sp)
lw t0, 28(sp)
sw t0, 8(sp)
lw t0, 8(sp)
lw t1, 4(sp)
qmul t0, t0, t1
sw t0, 32(sp)
lw t0, 32(sp)
sw t0, 12(sp)
li t0, 3
sw t0, 36(sp)
li t0, 16
sw t0, 40(sp)
lw t0, 36(sp)
lw t1, 40(sp)
sll t0, t0, t1
sw t0, 44(sp)
lw t0, 44(sp)
qrcp t0, t0
sw t0, 48(sp)
lw t0, 8(sp)
lw t1, 48(sp)
qmul t0, t0, t1
sw t0, 52(sp)
lw t0, 52(sp)
sw t0, 16(sp)
li t0, 131072
sw t0, 56(sp)
lw t0, 56(sp)
lw t1, 12(sp)
qmul t0, t0, t1
sw t0, 60(sp)
li t0, 15
sw t0, 64(sp)
li t0, 16
sw t0, 68(sp)
lw t0, 64(sp)
lw t1, 68(sp)
sll t0, t0, t1
sw t0, 72(sp)
lw t0, 72(sp)
qrcp t0, t0
sw t0, 76(sp)
lw t0, 60(sp)
lw t1, 76(sp)
qmul t0, t0, t1
sw t0, 80(sp)
lw t0, 80(sp)
sw t0, 20(sp)
lw t0, 0(sp)
lw t1, 16(sp)
add t0, t0, t1
sw t0, 84(sp)
lw t0, 84(sp)
lw t1, 20(sp)
add t0, t0, t1
sw t0, 88(sp)
lw a0, 88(sp)
lw ra, 92(sp)
addi sp, sp, 96
jalr x0, ra, 0

.globl random_in_unit_disk
random_in_unit_disk:
addi sp, sp, -172
sw ra, 168(sp)
sw a0, 0(sp)
.L_random_in_unit_disk_0:
lw t0, 0(sp)
sw t0, 4(sp)
li t0, 0
sw t0, 56(sp)
li t0, 64
sw t0, 60(sp)
lw t0, 56(sp)
sw t0, 52(sp)
lw t0, 60(sp)
sw t0, 64(sp)
j .L_random_in_unit_disk_1
.L_random_in_unit_disk_1:
lw t0, 52(sp)
lw t1, 64(sp)
slt t0, t0, t1
sw t0, 68(sp)
lw t0, 68(sp)
bnez t0, .L_random_in_unit_disk_2
j .L_random_in_unit_disk_4
.L_random_in_unit_disk_2:
li t0, 65536
sw t0, 72(sp)
lw t0, 72(sp)
sub t0, x0, t0
sw t0, 76(sp)
li t0, 65536
sw t0, 80(sp)
lw a0, 4(sp)
lw a1, 76(sp)
lw a2, 80(sp)
jal ra, random_q16_range
sw a0, 84(sp)
sw a1, 88(sp)
lw t0, 84(sp)
sw t0, 8(sp)
lw t0, 88(sp)
sw t0, 12(sp)
li t0, 65536
sw t0, 92(sp)
lw t0, 92(sp)
sub t0, x0, t0
sw t0, 96(sp)
li t0, 65536
sw t0, 100(sp)
lw a0, 8(sp)
lw a1, 96(sp)
lw a2, 100(sp)
jal ra, random_q16_range
sw a0, 104(sp)
sw a1, 108(sp)
lw t0, 104(sp)
sw t0, 16(sp)
lw t0, 108(sp)
sw t0, 20(sp)
lw t0, 16(sp)
sw t0, 4(sp)
li t0, 0
sw t0, 112(sp)
lw t0, 12(sp)
sw t0, 116(sp)
lw t0, 20(sp)
sw t0, 120(sp)
lw t0, 112(sp)
sw t0, 124(sp)
lw t0, 116(sp)
sw t0, 24(sp)
lw t0, 120(sp)
sw t0, 28(sp)
lw t0, 124(sp)
sw t0, 32(sp)
lw a0, 24(sp)
lw a1, 28(sp)
lw a2, 32(sp)
jal ra, vec3_length_squared
sw a0, 128(sp)
li t0, 65536
sw t0, 132(sp)
lw t0, 128(sp)
lw t1, 132(sp)
slt t0, t0, t1
sw t0, 136(sp)
lw t0, 136(sp)
bnez t0, .L_random_in_unit_disk_5
j .L_random_in_unit_disk_6
.L_random_in_unit_disk_5:
lw t0, 4(sp)
sw t0, 36(sp)
lw t0, 24(sp)
sw t0, 40(sp)
lw t0, 28(sp)
sw t0, 44(sp)
lw t0, 32(sp)
sw t0, 48(sp)
lw a0, 36(sp)
lw a1, 40(sp)
lw a2, 44(sp)
lw a3, 48(sp)
lw ra, 168(sp)
addi sp, sp, 172
jalr x0, ra, 0
.L_random_in_unit_disk_6:
j .L_random_in_unit_disk_3
.L_random_in_unit_disk_3:
li t0, 1
sw t0, 140(sp)
lw t0, 52(sp)
lw t1, 140(sp)
add t0, t0, t1
sw t0, 52(sp)
j .L_random_in_unit_disk_1
.L_random_in_unit_disk_4:
lw t0, 4(sp)
sw t0, 36(sp)
li t0, 0
sw t0, 144(sp)
li t0, 0
sw t0, 148(sp)
li t0, 0
sw t0, 152(sp)
lw t0, 144(sp)
sw t0, 156(sp)
lw t0, 148(sp)
sw t0, 160(sp)
lw t0, 152(sp)
sw t0, 164(sp)
lw t0, 156(sp)
sw t0, 40(sp)
lw t0, 160(sp)
sw t0, 44(sp)
lw t0, 164(sp)
sw t0, 48(sp)
lw a0, 36(sp)
lw a1, 40(sp)
lw a2, 44(sp)
lw a3, 48(sp)
lw ra, 168(sp)
addi sp, sp, 172
jalr x0, ra, 0

.globl random_q16
random_q16:
addi sp, sp, -56
sw ra, 52(sp)
sw a0, 0(sp)
.L_random_q16_0:
lw a0, 0(sp)
jal ra, rng_next_i32
sw a0, 20(sp)
sw a1, 24(sp)
lw t0, 20(sp)
sw t0, 4(sp)
lw t0, 24(sp)
sw t0, 8(sp)
lw t0, 4(sp)
sw t0, 12(sp)
li t0, 1
sw t0, 28(sp)
li t0, 8
sw t0, 32(sp)
lw t0, 8(sp)
lw t1, 32(sp)
sra t0, t0, t1
sw t0, 36(sp)
li t0, 65535
sw t0, 40(sp)
lw t0, 36(sp)
lw t1, 40(sp)
and t0, t0, t1
sw t0, 44(sp)
lw t0, 28(sp)
lw t1, 44(sp)
mul t0, t0, t1
sw t0, 48(sp)
lw t0, 48(sp)
sw t0, 16(sp)
lw a0, 12(sp)
lw a1, 16(sp)
lw ra, 52(sp)
addi sp, sp, 56
jalr x0, ra, 0

.globl random_q16_range
random_q16_range:
addi sp, sp, -52
sw ra, 48(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
.L_random_q16_range_0:
lw a0, 0(sp)
jal ra, random_q16
sw a0, 28(sp)
sw a1, 32(sp)
lw t0, 28(sp)
sw t0, 12(sp)
lw t0, 32(sp)
sw t0, 16(sp)
lw t0, 12(sp)
sw t0, 20(sp)
lw t0, 8(sp)
lw t1, 4(sp)
sub t0, t0, t1
sw t0, 36(sp)
lw t0, 36(sp)
lw t1, 16(sp)
qmul t0, t0, t1
sw t0, 40(sp)
lw t0, 4(sp)
lw t1, 40(sp)
add t0, t0, t1
sw t0, 44(sp)
lw t0, 44(sp)
sw t0, 24(sp)
lw a0, 20(sp)
lw a1, 24(sp)
lw ra, 48(sp)
addi sp, sp, 52
jalr x0, ra, 0

.globl random_unit_vector
random_unit_vector:
addi sp, sp, -164
sw ra, 160(sp)
sw a0, 0(sp)
.L_random_unit_vector_0:
lw t0, 0(sp)
sw t0, 4(sp)
li t0, 0
sw t0, 48(sp)
li t0, 64
sw t0, 52(sp)
lw t0, 48(sp)
sw t0, 44(sp)
lw t0, 52(sp)
sw t0, 56(sp)
j .L_random_unit_vector_1
.L_random_unit_vector_1:
lw t0, 44(sp)
lw t1, 56(sp)
slt t0, t0, t1
sw t0, 60(sp)
lw t0, 60(sp)
bnez t0, .L_random_unit_vector_2
j .L_random_unit_vector_4
.L_random_unit_vector_2:
li t0, 65536
sw t0, 64(sp)
lw t0, 64(sp)
sub t0, x0, t0
sw t0, 68(sp)
li t0, 65536
sw t0, 72(sp)
lw a0, 4(sp)
lw a1, 68(sp)
lw a2, 72(sp)
jal ra, random_vec3_range
sw a0, 76(sp)
sw a1, 80(sp)
sw a2, 84(sp)
sw a3, 88(sp)
lw t0, 76(sp)
sw t0, 8(sp)
lw t0, 80(sp)
sw t0, 12(sp)
lw t0, 84(sp)
sw t0, 16(sp)
lw t0, 88(sp)
sw t0, 20(sp)
lw t0, 8(sp)
sw t0, 4(sp)
lw a0, 12(sp)
lw a1, 16(sp)
lw a2, 20(sp)
jal ra, vec3_length_squared
sw a0, 92(sp)
lw t0, 92(sp)
sw t0, 24(sp)
li t0, 655
sw t0, 100(sp)
lw t0, 24(sp)
lw t1, 100(sp)
slt t0, t0, t1
xori t0, t0, 1
sw t0, 104(sp)
lw t0, 104(sp)
bnez t0, .L_random_unit_vector_5
j .L_random_unit_vector_6
.L_random_unit_vector_5:
li t0, 65536
sw t0, 108(sp)
lw t0, 24(sp)
lw t1, 108(sp)
slt t0, t1, t0
xori t0, t0, 1
sw t0, 112(sp)
lw t0, 112(sp)
sw t0, 96(sp)
j .L_random_unit_vector_7
.L_random_unit_vector_6:
li t0, 0
sw t0, 96(sp)
j .L_random_unit_vector_7
.L_random_unit_vector_7:
lw t0, 96(sp)
bnez t0, .L_random_unit_vector_8
j .L_random_unit_vector_9
.L_random_unit_vector_8:
lw t0, 4(sp)
sw t0, 28(sp)
lw t0, 24(sp)
qrsqrt t0, t0
sw t0, 116(sp)
lw a0, 12(sp)
lw a1, 16(sp)
lw a2, 20(sp)
lw a3, 116(sp)
jal ra, vec3_scale
sw a0, 120(sp)
sw a1, 124(sp)
sw a2, 128(sp)
lw t0, 120(sp)
sw t0, 32(sp)
lw t0, 124(sp)
sw t0, 36(sp)
lw t0, 128(sp)
sw t0, 40(sp)
lw a0, 28(sp)
lw a1, 32(sp)
lw a2, 36(sp)
lw a3, 40(sp)
lw ra, 160(sp)
addi sp, sp, 164
jalr x0, ra, 0
.L_random_unit_vector_9:
j .L_random_unit_vector_3
.L_random_unit_vector_3:
li t0, 1
sw t0, 132(sp)
lw t0, 44(sp)
lw t1, 132(sp)
add t0, t0, t1
sw t0, 44(sp)
j .L_random_unit_vector_1
.L_random_unit_vector_4:
lw t0, 4(sp)
sw t0, 28(sp)
li t0, 0
sw t0, 136(sp)
li t0, 65536
sw t0, 140(sp)
li t0, 0
sw t0, 144(sp)
lw t0, 136(sp)
sw t0, 148(sp)
lw t0, 140(sp)
sw t0, 152(sp)
lw t0, 144(sp)
sw t0, 156(sp)
lw t0, 148(sp)
sw t0, 32(sp)
lw t0, 152(sp)
sw t0, 36(sp)
lw t0, 156(sp)
sw t0, 40(sp)
lw a0, 28(sp)
lw a1, 32(sp)
lw a2, 36(sp)
lw a3, 40(sp)
lw ra, 160(sp)
addi sp, sp, 164
jalr x0, ra, 0

.globl random_vec3_range
random_vec3_range:
addi sp, sp, -92
sw ra, 88(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
.L_random_vec3_range_0:
lw a0, 0(sp)
lw a1, 4(sp)
lw a2, 8(sp)
jal ra, random_q16_range
sw a0, 52(sp)
sw a1, 56(sp)
lw t0, 52(sp)
sw t0, 12(sp)
lw t0, 56(sp)
sw t0, 16(sp)
lw a0, 12(sp)
lw a1, 4(sp)
lw a2, 8(sp)
jal ra, random_q16_range
sw a0, 60(sp)
sw a1, 64(sp)
lw t0, 60(sp)
sw t0, 20(sp)
lw t0, 64(sp)
sw t0, 24(sp)
lw a0, 20(sp)
lw a1, 4(sp)
lw a2, 8(sp)
jal ra, random_q16_range
sw a0, 68(sp)
sw a1, 72(sp)
lw t0, 68(sp)
sw t0, 28(sp)
lw t0, 72(sp)
sw t0, 32(sp)
lw t0, 28(sp)
sw t0, 36(sp)
lw t0, 16(sp)
sw t0, 76(sp)
lw t0, 24(sp)
sw t0, 80(sp)
lw t0, 32(sp)
sw t0, 84(sp)
lw t0, 76(sp)
sw t0, 40(sp)
lw t0, 80(sp)
sw t0, 44(sp)
lw t0, 84(sp)
sw t0, 48(sp)
lw a0, 36(sp)
lw a1, 40(sp)
lw a2, 44(sp)
lw a3, 48(sp)
lw ra, 88(sp)
addi sp, sp, 92
jalr x0, ra, 0

.globl ratio_i32
ratio_i32:
addi sp, sp, -32
sw ra, 28(sp)
sw a0, 0(sp)
sw a1, 4(sp)
.L_ratio_i32_0:
li t0, 1
sw t0, 8(sp)
li t0, 16
sw t0, 12(sp)
lw t0, 0(sp)
lw t1, 12(sp)
sll t0, t0, t1
sw t0, 16(sp)
lw t0, 16(sp)
lw t1, 4(sp)
div t0, t0, t1
sw t0, 20(sp)
lw t0, 8(sp)
lw t1, 20(sp)
mul t0, t0, t1
sw t0, 24(sp)
lw a0, 24(sp)
lw ra, 28(sp)
addi sp, sp, 32
jalr x0, ra, 0

.globl ray_at
ray_at:
addi sp, sp, -56
sw ra, 52(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
sw a3, 12(sp)
sw a4, 16(sp)
sw a5, 20(sp)
sw a6, 24(sp)
.L_ray_at_0:
lw a0, 12(sp)
lw a1, 16(sp)
lw a2, 20(sp)
lw a3, 24(sp)
jal ra, vec3_scale
sw a0, 28(sp)
sw a1, 32(sp)
sw a2, 36(sp)
lw a0, 0(sp)
lw a1, 4(sp)
lw a2, 8(sp)
lw a3, 28(sp)
lw a4, 32(sp)
lw a5, 36(sp)
jal ra, vec3_add
sw a0, 40(sp)
sw a1, 44(sp)
sw a2, 48(sp)
lw a0, 40(sp)
lw a1, 44(sp)
lw a2, 48(sp)
lw ra, 52(sp)
addi sp, sp, 56
jalr x0, ra, 0

.globl ray_color
ray_color:
addi sp, sp, -612
sw ra, 608(sp)
sw a0, 52(sp)
sw a1, 56(sp)
sw a2, 60(sp)
sw a3, 64(sp)
sw a4, 68(sp)
sw a5, 72(sp)
sw a6, 76(sp)
.L_ray_color_0:
lw t0, 52(sp)
sw t0, 80(sp)
lw t0, 56(sp)
sw t0, 84(sp)
lw t0, 60(sp)
sw t0, 88(sp)
lw t0, 64(sp)
sw t0, 92(sp)
lw t0, 68(sp)
sw t0, 96(sp)
lw t0, 72(sp)
sw t0, 100(sp)
lw t0, 76(sp)
sw t0, 104(sp)
li t0, 65536
sw t0, 256(sp)
li t0, 65536
sw t0, 260(sp)
li t0, 65536
sw t0, 264(sp)
lw t0, 256(sp)
sw t0, 268(sp)
lw t0, 260(sp)
sw t0, 272(sp)
lw t0, 264(sp)
sw t0, 276(sp)
lw t0, 268(sp)
sw t0, 108(sp)
lw t0, 272(sp)
sw t0, 112(sp)
lw t0, 276(sp)
sw t0, 116(sp)
li t0, 0
sw t0, 280(sp)
li t0, 20
sw t0, 284(sp)
lw t0, 280(sp)
sw t0, 252(sp)
lw t0, 284(sp)
sw t0, 288(sp)
j .L_ray_color_1
.L_ray_color_1:
lw t0, 252(sp)
lw t1, 288(sp)
slt t0, t0, t1
sw t0, 292(sp)
lw t0, 292(sp)
bnez t0, .L_ray_color_2
j .L_ray_color_4
.L_ray_color_2:
li t0, 256
sw t0, 296(sp)
li t0, 2147418112
sw t0, 300(sp)
lw a0, 84(sp)
lw a1, 88(sp)
lw a2, 92(sp)
lw a3, 96(sp)
lw a4, 100(sp)
lw a5, 104(sp)
lw a6, 296(sp)
lw a7, 300(sp)
jal ra, world_hit
sw a0, 304(sp)
sw a1, 308(sp)
sw a2, 312(sp)
sw a3, 316(sp)
sw a4, 320(sp)
sw a5, 324(sp)
sw a6, 328(sp)
sw a7, 332(sp)
lw t0, 0(sp)
sw t0, 336(sp)
lw t0, 4(sp)
sw t0, 340(sp)
lw t0, 8(sp)
sw t0, 344(sp)
lw t0, 12(sp)
sw t0, 348(sp)
lw t0, 16(sp)
sw t0, 352(sp)
lw t0, 20(sp)
sw t0, 356(sp)
lw t0, 304(sp)
sw t0, 120(sp)
lw t0, 308(sp)
sw t0, 124(sp)
lw t0, 312(sp)
sw t0, 128(sp)
lw t0, 316(sp)
sw t0, 132(sp)
lw t0, 320(sp)
sw t0, 136(sp)
lw t0, 324(sp)
sw t0, 140(sp)
lw t0, 328(sp)
sw t0, 144(sp)
lw t0, 332(sp)
sw t0, 148(sp)
lw t0, 336(sp)
sw t0, 152(sp)
lw t0, 340(sp)
sw t0, 156(sp)
lw t0, 344(sp)
sw t0, 160(sp)
lw t0, 348(sp)
sw t0, 164(sp)
lw t0, 352(sp)
sw t0, 168(sp)
lw t0, 356(sp)
sw t0, 172(sp)
li t0, 0
sw t0, 360(sp)
lw t0, 120(sp)
lw t1, 360(sp)
sub t0, t0, t1
sltu t0, x0, t0
sw t0, 364(sp)
lw t0, 364(sp)
bnez t0, .L_ray_color_5
j .L_ray_color_6
.L_ray_color_5:
lw a0, 80(sp)
lw a1, 84(sp)
lw a2, 88(sp)
lw a3, 92(sp)
lw a4, 96(sp)
lw a5, 100(sp)
lw a6, 104(sp)
lw a7, 120(sp)
lw t0, 124(sp)
sw t0, 0(sp)
lw t0, 128(sp)
sw t0, 4(sp)
lw t0, 132(sp)
sw t0, 8(sp)
lw t0, 136(sp)
sw t0, 12(sp)
lw t0, 140(sp)
sw t0, 16(sp)
lw t0, 144(sp)
sw t0, 20(sp)
lw t0, 148(sp)
sw t0, 24(sp)
lw t0, 152(sp)
sw t0, 28(sp)
lw t0, 156(sp)
sw t0, 32(sp)
lw t0, 160(sp)
sw t0, 36(sp)
lw t0, 164(sp)
sw t0, 40(sp)
lw t0, 168(sp)
sw t0, 44(sp)
lw t0, 172(sp)
sw t0, 48(sp)
jal ra, material_scatter
sw a0, 368(sp)
sw a1, 372(sp)
sw a2, 376(sp)
sw a3, 380(sp)
sw a4, 384(sp)
sw a5, 388(sp)
sw a6, 392(sp)
sw a7, 396(sp)
lw t0, 0(sp)
sw t0, 400(sp)
lw t0, 4(sp)
sw t0, 404(sp)
lw t0, 8(sp)
sw t0, 408(sp)
lw t0, 368(sp)
sw t0, 176(sp)
lw t0, 372(sp)
sw t0, 180(sp)
lw t0, 376(sp)
sw t0, 184(sp)
lw t0, 380(sp)
sw t0, 188(sp)
lw t0, 384(sp)
sw t0, 192(sp)
lw t0, 388(sp)
sw t0, 196(sp)
lw t0, 392(sp)
sw t0, 200(sp)
lw t0, 396(sp)
sw t0, 204(sp)
lw t0, 400(sp)
sw t0, 208(sp)
lw t0, 404(sp)
sw t0, 212(sp)
lw t0, 408(sp)
sw t0, 216(sp)
lw t0, 176(sp)
sw t0, 80(sp)
li t0, 0
sw t0, 412(sp)
lw t0, 180(sp)
lw t1, 412(sp)
sub t0, t0, t1
sltiu t0, t0, 1
sw t0, 416(sp)
lw t0, 416(sp)
bnez t0, .L_ray_color_8
j .L_ray_color_9
.L_ray_color_8:
lw t0, 80(sp)
sw t0, 236(sp)
li t0, 0
sw t0, 420(sp)
li t0, 0
sw t0, 424(sp)
li t0, 0
sw t0, 428(sp)
lw t0, 420(sp)
sw t0, 432(sp)
lw t0, 424(sp)
sw t0, 436(sp)
lw t0, 428(sp)
sw t0, 440(sp)
lw t0, 432(sp)
sw t0, 240(sp)
lw t0, 436(sp)
sw t0, 244(sp)
lw t0, 440(sp)
sw t0, 248(sp)
lw a0, 236(sp)
lw a1, 240(sp)
lw a2, 244(sp)
lw a3, 248(sp)
lw ra, 608(sp)
addi sp, sp, 612
jalr x0, ra, 0
.L_ray_color_9:
lw a0, 108(sp)
lw a1, 112(sp)
lw a2, 116(sp)
lw a3, 184(sp)
lw a4, 188(sp)
lw a5, 192(sp)
jal ra, vec3_mul_elem
sw a0, 444(sp)
sw a1, 448(sp)
sw a2, 452(sp)
lw t0, 444(sp)
sw t0, 108(sp)
lw t0, 448(sp)
sw t0, 112(sp)
lw t0, 452(sp)
sw t0, 116(sp)
lw t0, 196(sp)
sw t0, 84(sp)
lw t0, 200(sp)
sw t0, 88(sp)
lw t0, 204(sp)
sw t0, 92(sp)
lw t0, 208(sp)
sw t0, 96(sp)
lw t0, 212(sp)
sw t0, 100(sp)
lw t0, 216(sp)
sw t0, 104(sp)
j .L_ray_color_7
.L_ray_color_6:
li t0, 32768
sw t0, 456(sp)
li t0, 65536
sw t0, 460(sp)
lw t0, 100(sp)
lw t1, 460(sp)
add t0, t0, t1
sw t0, 464(sp)
lw t0, 456(sp)
lw t1, 464(sp)
qmul t0, t0, t1
sw t0, 468(sp)
lw t0, 468(sp)
sw t0, 220(sp)
li t0, 65536
sw t0, 472(sp)
li t0, 65536
sw t0, 476(sp)
lw t0, 476(sp)
lw t1, 220(sp)
sub t0, t0, t1
sw t0, 480(sp)
lw t0, 472(sp)
lw t1, 480(sp)
qmul t0, t0, t1
sw t0, 484(sp)
li t0, 32768
sw t0, 488(sp)
lw t0, 488(sp)
lw t1, 220(sp)
qmul t0, t0, t1
sw t0, 492(sp)
lw t0, 484(sp)
lw t1, 492(sp)
add t0, t0, t1
sw t0, 496(sp)
li t0, 65536
sw t0, 500(sp)
li t0, 65536
sw t0, 504(sp)
lw t0, 504(sp)
lw t1, 220(sp)
sub t0, t0, t1
sw t0, 508(sp)
lw t0, 500(sp)
lw t1, 508(sp)
qmul t0, t0, t1
sw t0, 512(sp)
li t0, 45875
sw t0, 516(sp)
lw t0, 516(sp)
lw t1, 220(sp)
qmul t0, t0, t1
sw t0, 520(sp)
lw t0, 512(sp)
lw t1, 520(sp)
add t0, t0, t1
sw t0, 524(sp)
li t0, 65536
sw t0, 528(sp)
li t0, 65536
sw t0, 532(sp)
lw t0, 532(sp)
lw t1, 220(sp)
sub t0, t0, t1
sw t0, 536(sp)
lw t0, 528(sp)
lw t1, 536(sp)
qmul t0, t0, t1
sw t0, 540(sp)
li t0, 65536
sw t0, 544(sp)
lw t0, 544(sp)
lw t1, 220(sp)
qmul t0, t0, t1
sw t0, 548(sp)
lw t0, 540(sp)
lw t1, 548(sp)
add t0, t0, t1
sw t0, 552(sp)
lw t0, 496(sp)
sw t0, 556(sp)
lw t0, 524(sp)
sw t0, 560(sp)
lw t0, 552(sp)
sw t0, 564(sp)
lw t0, 556(sp)
sw t0, 224(sp)
lw t0, 560(sp)
sw t0, 228(sp)
lw t0, 564(sp)
sw t0, 232(sp)
lw t0, 80(sp)
sw t0, 236(sp)
lw a0, 108(sp)
lw a1, 112(sp)
lw a2, 116(sp)
lw a3, 224(sp)
lw a4, 228(sp)
lw a5, 232(sp)
jal ra, vec3_mul_elem
sw a0, 568(sp)
sw a1, 572(sp)
sw a2, 576(sp)
lw t0, 568(sp)
sw t0, 240(sp)
lw t0, 572(sp)
sw t0, 244(sp)
lw t0, 576(sp)
sw t0, 248(sp)
lw a0, 236(sp)
lw a1, 240(sp)
lw a2, 244(sp)
lw a3, 248(sp)
lw ra, 608(sp)
addi sp, sp, 612
jalr x0, ra, 0
.L_ray_color_7:
j .L_ray_color_3
.L_ray_color_3:
li t0, 1
sw t0, 580(sp)
lw t0, 252(sp)
lw t1, 580(sp)
add t0, t0, t1
sw t0, 252(sp)
j .L_ray_color_1
.L_ray_color_4:
lw t0, 80(sp)
sw t0, 236(sp)
li t0, 0
sw t0, 584(sp)
li t0, 0
sw t0, 588(sp)
li t0, 0
sw t0, 592(sp)
lw t0, 584(sp)
sw t0, 596(sp)
lw t0, 588(sp)
sw t0, 600(sp)
lw t0, 592(sp)
sw t0, 604(sp)
lw t0, 596(sp)
sw t0, 240(sp)
lw t0, 600(sp)
sw t0, 244(sp)
lw t0, 604(sp)
sw t0, 248(sp)
lw a0, 236(sp)
lw a1, 240(sp)
lw a2, 244(sp)
lw a3, 248(sp)
lw ra, 608(sp)
addi sp, sp, 612
jalr x0, ra, 0

.globl rng_next_i32
rng_next_i32:
addi sp, sp, -72
sw ra, 68(sp)
sw a0, 0(sp)
.L_rng_next_i32_0:
li t0, 13
sw t0, 16(sp)
lw t0, 0(sp)
lw t1, 16(sp)
sll t0, t0, t1
sw t0, 20(sp)
lw t0, 0(sp)
lw t1, 20(sp)
xor t0, t0, t1
sw t0, 24(sp)
lw t0, 24(sp)
sw t0, 4(sp)
li t0, 17
sw t0, 28(sp)
lw t0, 4(sp)
lw t1, 28(sp)
sra t0, t0, t1
sw t0, 32(sp)
li t0, 32767
sw t0, 36(sp)
lw t0, 32(sp)
lw t1, 36(sp)
and t0, t0, t1
sw t0, 40(sp)
lw t0, 4(sp)
lw t1, 40(sp)
xor t0, t0, t1
sw t0, 44(sp)
lw t0, 44(sp)
sw t0, 4(sp)
li t0, 5
sw t0, 48(sp)
lw t0, 4(sp)
lw t1, 48(sp)
sll t0, t0, t1
sw t0, 52(sp)
lw t0, 4(sp)
lw t1, 52(sp)
xor t0, t0, t1
sw t0, 56(sp)
lw t0, 56(sp)
sw t0, 4(sp)
lw t0, 4(sp)
sw t0, 8(sp)
li t0, 2147483647
sw t0, 60(sp)
lw t0, 4(sp)
lw t1, 60(sp)
and t0, t0, t1
sw t0, 64(sp)
lw t0, 64(sp)
sw t0, 12(sp)
lw a0, 8(sp)
lw a1, 12(sp)
lw ra, 68(sp)
addi sp, sp, 72
jalr x0, ra, 0

.globl schlick_reflectance
schlick_reflectance:
addi sp, sp, -100
sw ra, 96(sp)
sw a0, 0(sp)
sw a1, 4(sp)
.L_schlick_reflectance_0:
li t0, 65536
sw t0, 32(sp)
lw t0, 32(sp)
lw t1, 4(sp)
sub t0, t0, t1
sw t0, 36(sp)
li t0, 65536
sw t0, 40(sp)
lw t0, 40(sp)
lw t1, 4(sp)
add t0, t0, t1
sw t0, 44(sp)
lw t0, 44(sp)
qrcp t0, t0
sw t0, 48(sp)
lw t0, 36(sp)
lw t1, 48(sp)
qmul t0, t0, t1
sw t0, 52(sp)
lw t0, 52(sp)
sw t0, 8(sp)
lw t0, 8(sp)
lw t1, 8(sp)
qmul t0, t0, t1
sw t0, 56(sp)
lw t0, 56(sp)
sw t0, 12(sp)
li t0, 65536
sw t0, 60(sp)
lw t0, 60(sp)
lw t1, 0(sp)
sub t0, t0, t1
sw t0, 64(sp)
lw t0, 64(sp)
sw t0, 16(sp)
lw t0, 16(sp)
lw t1, 16(sp)
qmul t0, t0, t1
sw t0, 68(sp)
lw t0, 68(sp)
sw t0, 20(sp)
lw t0, 20(sp)
lw t1, 20(sp)
qmul t0, t0, t1
sw t0, 72(sp)
lw t0, 72(sp)
sw t0, 24(sp)
lw t0, 24(sp)
lw t1, 16(sp)
qmul t0, t0, t1
sw t0, 76(sp)
lw t0, 76(sp)
sw t0, 28(sp)
li t0, 65536
sw t0, 80(sp)
lw t0, 80(sp)
lw t1, 12(sp)
sub t0, t0, t1
sw t0, 84(sp)
lw t0, 84(sp)
lw t1, 28(sp)
qmul t0, t0, t1
sw t0, 88(sp)
lw t0, 12(sp)
lw t1, 88(sp)
add t0, t0, t1
sw t0, 92(sp)
lw a0, 92(sp)
lw ra, 96(sp)
addi sp, sp, 100
jalr x0, ra, 0

.globl vec3_add
vec3_add:
addi sp, sp, -52
sw ra, 48(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
sw a3, 12(sp)
sw a4, 16(sp)
sw a5, 20(sp)
.L_vec3_add_0:
lw t0, 0(sp)
lw t1, 12(sp)
add t0, t0, t1
sw t0, 24(sp)
lw t0, 4(sp)
lw t1, 16(sp)
add t0, t0, t1
sw t0, 28(sp)
lw t0, 8(sp)
lw t1, 20(sp)
add t0, t0, t1
sw t0, 32(sp)
lw t0, 24(sp)
sw t0, 36(sp)
lw t0, 28(sp)
sw t0, 40(sp)
lw t0, 32(sp)
sw t0, 44(sp)
lw a0, 36(sp)
lw a1, 40(sp)
lw a2, 44(sp)
lw ra, 48(sp)
addi sp, sp, 52
jalr x0, ra, 0

.globl vec3_cross
vec3_cross:
addi sp, sp, -76
sw ra, 72(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
sw a3, 12(sp)
sw a4, 16(sp)
sw a5, 20(sp)
.L_vec3_cross_0:
lw t0, 4(sp)
lw t1, 20(sp)
qmul t0, t0, t1
sw t0, 24(sp)
lw t0, 8(sp)
lw t1, 16(sp)
qmul t0, t0, t1
sw t0, 28(sp)
lw t0, 24(sp)
lw t1, 28(sp)
sub t0, t0, t1
sw t0, 32(sp)
lw t0, 8(sp)
lw t1, 12(sp)
qmul t0, t0, t1
sw t0, 36(sp)
lw t0, 0(sp)
lw t1, 20(sp)
qmul t0, t0, t1
sw t0, 40(sp)
lw t0, 36(sp)
lw t1, 40(sp)
sub t0, t0, t1
sw t0, 44(sp)
lw t0, 0(sp)
lw t1, 16(sp)
qmul t0, t0, t1
sw t0, 48(sp)
lw t0, 4(sp)
lw t1, 12(sp)
qmul t0, t0, t1
sw t0, 52(sp)
lw t0, 48(sp)
lw t1, 52(sp)
sub t0, t0, t1
sw t0, 56(sp)
lw t0, 32(sp)
sw t0, 60(sp)
lw t0, 44(sp)
sw t0, 64(sp)
lw t0, 56(sp)
sw t0, 68(sp)
lw a0, 60(sp)
lw a1, 64(sp)
lw a2, 68(sp)
lw ra, 72(sp)
addi sp, sp, 76
jalr x0, ra, 0

.globl vec3_dot
vec3_dot:
addi sp, sp, -48
sw ra, 44(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
sw a3, 12(sp)
sw a4, 16(sp)
sw a5, 20(sp)
.L_vec3_dot_0:
lw t0, 0(sp)
lw t1, 12(sp)
qmul t0, t0, t1
sw t0, 24(sp)
lw t0, 4(sp)
lw t1, 16(sp)
qmul t0, t0, t1
sw t0, 28(sp)
lw t0, 24(sp)
lw t1, 28(sp)
add t0, t0, t1
sw t0, 32(sp)
lw t0, 8(sp)
lw t1, 20(sp)
qmul t0, t0, t1
sw t0, 36(sp)
lw t0, 32(sp)
lw t1, 36(sp)
add t0, t0, t1
sw t0, 40(sp)
lw a0, 40(sp)
lw ra, 44(sp)
addi sp, sp, 48
jalr x0, ra, 0

.globl vec3_length_squared
vec3_length_squared:
addi sp, sp, -20
sw ra, 16(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
.L_vec3_length_squared_0:
lw a0, 0(sp)
lw a1, 4(sp)
lw a2, 8(sp)
lw a3, 0(sp)
lw a4, 4(sp)
lw a5, 8(sp)
jal ra, vec3_dot
sw a0, 12(sp)
lw a0, 12(sp)
lw ra, 16(sp)
addi sp, sp, 20
jalr x0, ra, 0

.globl vec3_mul_elem
vec3_mul_elem:
addi sp, sp, -52
sw ra, 48(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
sw a3, 12(sp)
sw a4, 16(sp)
sw a5, 20(sp)
.L_vec3_mul_elem_0:
lw t0, 0(sp)
lw t1, 12(sp)
qmul t0, t0, t1
sw t0, 24(sp)
lw t0, 4(sp)
lw t1, 16(sp)
qmul t0, t0, t1
sw t0, 28(sp)
lw t0, 8(sp)
lw t1, 20(sp)
qmul t0, t0, t1
sw t0, 32(sp)
lw t0, 24(sp)
sw t0, 36(sp)
lw t0, 28(sp)
sw t0, 40(sp)
lw t0, 32(sp)
sw t0, 44(sp)
lw a0, 36(sp)
lw a1, 40(sp)
lw a2, 44(sp)
lw ra, 48(sp)
addi sp, sp, 52
jalr x0, ra, 0

.globl vec3_near_zero
vec3_near_zero:
addi sp, sp, -68
sw ra, 64(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
.L_vec3_near_zero_0:
lw a0, 0(sp)
jal ra, q_abs
sw a0, 12(sp)
li t0, 33
sw t0, 16(sp)
lw t0, 12(sp)
lw t1, 16(sp)
slt t0, t0, t1
xori t0, t0, 1
sw t0, 20(sp)
lw t0, 20(sp)
bnez t0, .L_vec3_near_zero_1
j .L_vec3_near_zero_2
.L_vec3_near_zero_1:
li t0, 0
sw t0, 24(sp)
lw a0, 24(sp)
lw ra, 64(sp)
addi sp, sp, 68
jalr x0, ra, 0
.L_vec3_near_zero_2:
lw a0, 4(sp)
jal ra, q_abs
sw a0, 28(sp)
li t0, 33
sw t0, 32(sp)
lw t0, 28(sp)
lw t1, 32(sp)
slt t0, t0, t1
xori t0, t0, 1
sw t0, 36(sp)
lw t0, 36(sp)
bnez t0, .L_vec3_near_zero_3
j .L_vec3_near_zero_4
.L_vec3_near_zero_3:
li t0, 0
sw t0, 40(sp)
lw a0, 40(sp)
lw ra, 64(sp)
addi sp, sp, 68
jalr x0, ra, 0
.L_vec3_near_zero_4:
lw a0, 8(sp)
jal ra, q_abs
sw a0, 44(sp)
li t0, 33
sw t0, 48(sp)
lw t0, 44(sp)
lw t1, 48(sp)
slt t0, t0, t1
xori t0, t0, 1
sw t0, 52(sp)
lw t0, 52(sp)
bnez t0, .L_vec3_near_zero_5
j .L_vec3_near_zero_6
.L_vec3_near_zero_5:
li t0, 0
sw t0, 56(sp)
lw a0, 56(sp)
lw ra, 64(sp)
addi sp, sp, 68
jalr x0, ra, 0
.L_vec3_near_zero_6:
li t0, 1
sw t0, 60(sp)
lw a0, 60(sp)
lw ra, 64(sp)
addi sp, sp, 68
jalr x0, ra, 0

.globl vec3_neg
vec3_neg:
addi sp, sp, -40
sw ra, 36(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
.L_vec3_neg_0:
lw t0, 0(sp)
sub t0, x0, t0
sw t0, 12(sp)
lw t0, 4(sp)
sub t0, x0, t0
sw t0, 16(sp)
lw t0, 8(sp)
sub t0, x0, t0
sw t0, 20(sp)
lw t0, 12(sp)
sw t0, 24(sp)
lw t0, 16(sp)
sw t0, 28(sp)
lw t0, 20(sp)
sw t0, 32(sp)
lw a0, 24(sp)
lw a1, 28(sp)
lw a2, 32(sp)
lw ra, 36(sp)
addi sp, sp, 40
jalr x0, ra, 0

.globl vec3_reflect
vec3_reflect:
addi sp, sp, -68
sw ra, 64(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
sw a3, 12(sp)
sw a4, 16(sp)
sw a5, 20(sp)
.L_vec3_reflect_0:
li t0, 131072
sw t0, 28(sp)
lw a0, 0(sp)
lw a1, 4(sp)
lw a2, 8(sp)
lw a3, 12(sp)
lw a4, 16(sp)
lw a5, 20(sp)
jal ra, vec3_dot
sw a0, 32(sp)
lw t0, 28(sp)
lw t1, 32(sp)
qmul t0, t0, t1
sw t0, 36(sp)
lw t0, 36(sp)
sw t0, 24(sp)
lw a0, 12(sp)
lw a1, 16(sp)
lw a2, 20(sp)
lw a3, 24(sp)
jal ra, vec3_scale
sw a0, 40(sp)
sw a1, 44(sp)
sw a2, 48(sp)
lw a0, 0(sp)
lw a1, 4(sp)
lw a2, 8(sp)
lw a3, 40(sp)
lw a4, 44(sp)
lw a5, 48(sp)
jal ra, vec3_sub
sw a0, 52(sp)
sw a1, 56(sp)
sw a2, 60(sp)
lw a0, 52(sp)
lw a1, 56(sp)
lw a2, 60(sp)
lw ra, 64(sp)
addi sp, sp, 68
jalr x0, ra, 0

.globl vec3_refract
vec3_refract:
addi sp, sp, -176
sw ra, 172(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
sw a3, 12(sp)
sw a4, 16(sp)
sw a5, 20(sp)
sw a6, 24(sp)
.L_vec3_refract_0:
lw a0, 0(sp)
lw a1, 4(sp)
lw a2, 8(sp)
jal ra, vec3_neg
sw a0, 64(sp)
sw a1, 68(sp)
sw a2, 72(sp)
lw a0, 64(sp)
lw a1, 68(sp)
lw a2, 72(sp)
lw a3, 12(sp)
lw a4, 16(sp)
lw a5, 20(sp)
jal ra, vec3_dot
sw a0, 76(sp)
li t0, 65536
sw t0, 80(sp)
lw a0, 76(sp)
lw a1, 80(sp)
jal ra, q_min
sw a0, 84(sp)
lw t0, 84(sp)
sw t0, 28(sp)
lw a0, 12(sp)
lw a1, 16(sp)
lw a2, 20(sp)
lw a3, 28(sp)
jal ra, vec3_scale
sw a0, 88(sp)
sw a1, 92(sp)
sw a2, 96(sp)
lw a0, 0(sp)
lw a1, 4(sp)
lw a2, 8(sp)
lw a3, 88(sp)
lw a4, 92(sp)
lw a5, 96(sp)
jal ra, vec3_add
sw a0, 100(sp)
sw a1, 104(sp)
sw a2, 108(sp)
lw a0, 100(sp)
lw a1, 104(sp)
lw a2, 108(sp)
lw a3, 24(sp)
jal ra, vec3_scale
sw a0, 112(sp)
sw a1, 116(sp)
sw a2, 120(sp)
lw t0, 112(sp)
sw t0, 32(sp)
lw t0, 116(sp)
sw t0, 36(sp)
lw t0, 120(sp)
sw t0, 40(sp)
lw a0, 32(sp)
lw a1, 36(sp)
lw a2, 40(sp)
jal ra, vec3_length_squared
sw a0, 124(sp)
lw t0, 124(sp)
sw t0, 44(sp)
li t0, 65536
sw t0, 128(sp)
lw t0, 128(sp)
lw t1, 44(sp)
sub t0, t0, t1
sw t0, 132(sp)
lw a0, 132(sp)
jal ra, q_abs
sw a0, 136(sp)
lw t0, 136(sp)
qsqrt t0, t0
sw t0, 140(sp)
lw t0, 140(sp)
sw t0, 48(sp)
lw t0, 48(sp)
sub t0, x0, t0
sw t0, 144(sp)
lw a0, 12(sp)
lw a1, 16(sp)
lw a2, 20(sp)
lw a3, 144(sp)
jal ra, vec3_scale
sw a0, 148(sp)
sw a1, 152(sp)
sw a2, 156(sp)
lw t0, 148(sp)
sw t0, 52(sp)
lw t0, 152(sp)
sw t0, 56(sp)
lw t0, 156(sp)
sw t0, 60(sp)
lw a0, 32(sp)
lw a1, 36(sp)
lw a2, 40(sp)
lw a3, 52(sp)
lw a4, 56(sp)
lw a5, 60(sp)
jal ra, vec3_add
sw a0, 160(sp)
sw a1, 164(sp)
sw a2, 168(sp)
lw a0, 160(sp)
lw a1, 164(sp)
lw a2, 168(sp)
lw ra, 172(sp)
addi sp, sp, 176
jalr x0, ra, 0

.globl vec3_scale
vec3_scale:
addi sp, sp, -44
sw ra, 40(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
sw a3, 12(sp)
.L_vec3_scale_0:
lw t0, 0(sp)
lw t1, 12(sp)
qmul t0, t0, t1
sw t0, 16(sp)
lw t0, 4(sp)
lw t1, 12(sp)
qmul t0, t0, t1
sw t0, 20(sp)
lw t0, 8(sp)
lw t1, 12(sp)
qmul t0, t0, t1
sw t0, 24(sp)
lw t0, 16(sp)
sw t0, 28(sp)
lw t0, 20(sp)
sw t0, 32(sp)
lw t0, 24(sp)
sw t0, 36(sp)
lw a0, 28(sp)
lw a1, 32(sp)
lw a2, 36(sp)
lw ra, 40(sp)
addi sp, sp, 44
jalr x0, ra, 0

.globl vec3_sub
vec3_sub:
addi sp, sp, -52
sw ra, 48(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
sw a3, 12(sp)
sw a4, 16(sp)
sw a5, 20(sp)
.L_vec3_sub_0:
lw t0, 0(sp)
lw t1, 12(sp)
sub t0, t0, t1
sw t0, 24(sp)
lw t0, 4(sp)
lw t1, 16(sp)
sub t0, t0, t1
sw t0, 28(sp)
lw t0, 8(sp)
lw t1, 20(sp)
sub t0, t0, t1
sw t0, 32(sp)
lw t0, 24(sp)
sw t0, 36(sp)
lw t0, 28(sp)
sw t0, 40(sp)
lw t0, 32(sp)
sw t0, 44(sp)
lw a0, 36(sp)
lw a1, 40(sp)
lw a2, 44(sp)
lw ra, 48(sp)
addi sp, sp, 52
jalr x0, ra, 0

.globl vec3_unit
vec3_unit:
addi sp, sp, -72
sw ra, 68(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
.L_vec3_unit_0:
lw a0, 0(sp)
lw a1, 4(sp)
lw a2, 8(sp)
jal ra, vec3_length_squared
sw a0, 16(sp)
lw t0, 16(sp)
sw t0, 12(sp)
li t0, 0
sw t0, 20(sp)
lw t0, 12(sp)
lw t1, 20(sp)
slt t0, t1, t0
xori t0, t0, 1
sw t0, 24(sp)
lw t0, 24(sp)
bnez t0, .L_vec3_unit_1
j .L_vec3_unit_2
.L_vec3_unit_1:
li t0, 0
sw t0, 28(sp)
li t0, 65536
sw t0, 32(sp)
li t0, 0
sw t0, 36(sp)
lw t0, 28(sp)
sw t0, 40(sp)
lw t0, 32(sp)
sw t0, 44(sp)
lw t0, 36(sp)
sw t0, 48(sp)
lw a0, 40(sp)
lw a1, 44(sp)
lw a2, 48(sp)
lw ra, 68(sp)
addi sp, sp, 72
jalr x0, ra, 0
.L_vec3_unit_2:
lw t0, 12(sp)
qrsqrt t0, t0
sw t0, 52(sp)
lw a0, 0(sp)
lw a1, 4(sp)
lw a2, 8(sp)
lw a3, 52(sp)
jal ra, vec3_scale
sw a0, 56(sp)
sw a1, 60(sp)
sw a2, 64(sp)
lw a0, 56(sp)
lw a1, 60(sp)
lw a2, 64(sp)
lw ra, 68(sp)
addi sp, sp, 72
jalr x0, ra, 0

.globl vec3_unit_big
vec3_unit_big:
addi sp, sp, -92
sw ra, 88(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
.L_vec3_unit_big_0:
lw t0, 0(sp)
sw t0, 12(sp)
lw t0, 4(sp)
sw t0, 16(sp)
lw t0, 8(sp)
sw t0, 20(sp)
li t0, 0
sw t0, 28(sp)
li t0, 8
sw t0, 32(sp)
lw t0, 28(sp)
sw t0, 24(sp)
lw t0, 32(sp)
sw t0, 36(sp)
j .L_vec3_unit_big_1
.L_vec3_unit_big_1:
lw t0, 24(sp)
lw t1, 36(sp)
slt t0, t0, t1
sw t0, 40(sp)
lw t0, 40(sp)
bnez t0, .L_vec3_unit_big_2
j .L_vec3_unit_big_4
.L_vec3_unit_big_2:
lw a0, 12(sp)
lw a1, 16(sp)
lw a2, 20(sp)
jal ra, vec3_length_squared
sw a0, 44(sp)
li t0, 131072
sw t0, 48(sp)
lw t0, 44(sp)
lw t1, 48(sp)
slt t0, t1, t0
sw t0, 52(sp)
lw t0, 52(sp)
bnez t0, .L_vec3_unit_big_5
j .L_vec3_unit_big_6
.L_vec3_unit_big_5:
li t0, 32768
sw t0, 56(sp)
lw a0, 12(sp)
lw a1, 16(sp)
lw a2, 20(sp)
lw a3, 56(sp)
jal ra, vec3_scale
sw a0, 60(sp)
sw a1, 64(sp)
sw a2, 68(sp)
lw t0, 60(sp)
sw t0, 12(sp)
lw t0, 64(sp)
sw t0, 16(sp)
lw t0, 68(sp)
sw t0, 20(sp)
j .L_vec3_unit_big_6
.L_vec3_unit_big_6:
j .L_vec3_unit_big_3
.L_vec3_unit_big_3:
li t0, 1
sw t0, 72(sp)
lw t0, 24(sp)
lw t1, 72(sp)
add t0, t0, t1
sw t0, 24(sp)
j .L_vec3_unit_big_1
.L_vec3_unit_big_4:
lw a0, 12(sp)
lw a1, 16(sp)
lw a2, 20(sp)
jal ra, vec3_unit
sw a0, 76(sp)
sw a1, 80(sp)
sw a2, 84(sp)
lw a0, 76(sp)
lw a1, 80(sp)
lw a2, 84(sp)
lw ra, 88(sp)
addi sp, sp, 92
jalr x0, ra, 0

.globl world_hit
world_hit:
addi sp, sp, -328
sw ra, 324(sp)
sw a0, 24(sp)
sw a1, 28(sp)
sw a2, 32(sp)
sw a3, 36(sp)
sw a4, 40(sp)
sw a5, 44(sp)
sw a6, 48(sp)
sw a7, 52(sp)
.L_world_hit_0:
lw a0, 24(sp)
lw a1, 28(sp)
lw a2, 32(sp)
lw a3, 36(sp)
lw a4, 40(sp)
lw a5, 44(sp)
lw a6, 48(sp)
lw a7, 52(sp)
jal ra, hit_ground
sw a0, 176(sp)
sw a1, 180(sp)
sw a2, 184(sp)
sw a3, 188(sp)
sw a4, 192(sp)
sw a5, 196(sp)
sw a6, 200(sp)
sw a7, 204(sp)
lw t0, 0(sp)
sw t0, 208(sp)
lw t0, 4(sp)
sw t0, 212(sp)
lw t0, 8(sp)
sw t0, 216(sp)
lw t0, 12(sp)
sw t0, 220(sp)
lw t0, 16(sp)
sw t0, 224(sp)
lw t0, 20(sp)
sw t0, 228(sp)
lw t0, 176(sp)
sw t0, 56(sp)
lw t0, 180(sp)
sw t0, 60(sp)
lw t0, 184(sp)
sw t0, 64(sp)
lw t0, 188(sp)
sw t0, 68(sp)
lw t0, 192(sp)
sw t0, 72(sp)
lw t0, 196(sp)
sw t0, 76(sp)
lw t0, 200(sp)
sw t0, 80(sp)
lw t0, 204(sp)
sw t0, 84(sp)
lw t0, 208(sp)
sw t0, 88(sp)
lw t0, 212(sp)
sw t0, 92(sp)
lw t0, 216(sp)
sw t0, 96(sp)
lw t0, 220(sp)
sw t0, 100(sp)
lw t0, 224(sp)
sw t0, 104(sp)
lw t0, 228(sp)
sw t0, 108(sp)
lw t0, 52(sp)
sw t0, 168(sp)
li t0, 0
sw t0, 232(sp)
lw t0, 56(sp)
lw t1, 232(sp)
sub t0, t0, t1
sltu t0, x0, t0
sw t0, 236(sp)
lw t0, 236(sp)
bnez t0, .L_world_hit_1
j .L_world_hit_2
.L_world_hit_1:
lw t0, 84(sp)
sw t0, 168(sp)
j .L_world_hit_2
.L_world_hit_2:
li t0, 0
sw t0, 240(sp)
li t0, 15
sw t0, 244(sp)
lw t0, 240(sp)
sw t0, 172(sp)
lw t0, 244(sp)
sw t0, 248(sp)
j .L_world_hit_3
.L_world_hit_3:
lw t0, 172(sp)
lw t1, 248(sp)
slt t0, t0, t1
sw t0, 252(sp)
lw t0, 252(sp)
bnez t0, .L_world_hit_4
j .L_world_hit_6
.L_world_hit_4:
lw a0, 172(sp)
lw a1, 24(sp)
lw a2, 28(sp)
lw a3, 32(sp)
lw a4, 36(sp)
lw a5, 40(sp)
lw a6, 44(sp)
lw a7, 48(sp)
lw t0, 168(sp)
sw t0, 0(sp)
jal ra, hit_sphere
sw a0, 256(sp)
sw a1, 260(sp)
sw a2, 264(sp)
sw a3, 268(sp)
sw a4, 272(sp)
sw a5, 276(sp)
sw a6, 280(sp)
sw a7, 284(sp)
lw t0, 0(sp)
sw t0, 288(sp)
lw t0, 4(sp)
sw t0, 292(sp)
lw t0, 8(sp)
sw t0, 296(sp)
lw t0, 12(sp)
sw t0, 300(sp)
lw t0, 16(sp)
sw t0, 304(sp)
lw t0, 20(sp)
sw t0, 308(sp)
lw t0, 256(sp)
sw t0, 112(sp)
lw t0, 260(sp)
sw t0, 116(sp)
lw t0, 264(sp)
sw t0, 120(sp)
lw t0, 268(sp)
sw t0, 124(sp)
lw t0, 272(sp)
sw t0, 128(sp)
lw t0, 276(sp)
sw t0, 132(sp)
lw t0, 280(sp)
sw t0, 136(sp)
lw t0, 284(sp)
sw t0, 140(sp)
lw t0, 288(sp)
sw t0, 144(sp)
lw t0, 292(sp)
sw t0, 148(sp)
lw t0, 296(sp)
sw t0, 152(sp)
lw t0, 300(sp)
sw t0, 156(sp)
lw t0, 304(sp)
sw t0, 160(sp)
lw t0, 308(sp)
sw t0, 164(sp)
li t0, 0
sw t0, 312(sp)
lw t0, 112(sp)
lw t1, 312(sp)
sub t0, t0, t1
sltu t0, x0, t0
sw t0, 316(sp)
lw t0, 316(sp)
bnez t0, .L_world_hit_7
j .L_world_hit_8
.L_world_hit_7:
lw t0, 140(sp)
sw t0, 168(sp)
lw t0, 112(sp)
sw t0, 56(sp)
lw t0, 116(sp)
sw t0, 60(sp)
lw t0, 120(sp)
sw t0, 64(sp)
lw t0, 124(sp)
sw t0, 68(sp)
lw t0, 128(sp)
sw t0, 72(sp)
lw t0, 132(sp)
sw t0, 76(sp)
lw t0, 136(sp)
sw t0, 80(sp)
lw t0, 140(sp)
sw t0, 84(sp)
lw t0, 144(sp)
sw t0, 88(sp)
lw t0, 148(sp)
sw t0, 92(sp)
lw t0, 152(sp)
sw t0, 96(sp)
lw t0, 156(sp)
sw t0, 100(sp)
lw t0, 160(sp)
sw t0, 104(sp)
lw t0, 164(sp)
sw t0, 108(sp)
j .L_world_hit_8
.L_world_hit_8:
j .L_world_hit_5
.L_world_hit_5:
li t0, 1
sw t0, 320(sp)
lw t0, 172(sp)
lw t1, 320(sp)
add t0, t0, t1
sw t0, 172(sp)
j .L_world_hit_3
.L_world_hit_6:
lw a0, 56(sp)
lw a1, 60(sp)
lw a2, 64(sp)
lw a3, 68(sp)
lw a4, 72(sp)
lw a5, 76(sp)
lw a6, 80(sp)
lw a7, 84(sp)
lw t0, 88(sp)
sw t0, 328(sp)
lw t0, 92(sp)
sw t0, 332(sp)
lw t0, 96(sp)
sw t0, 336(sp)
lw t0, 100(sp)
sw t0, 340(sp)
lw t0, 104(sp)
sw t0, 344(sp)
lw t0, 108(sp)
sw t0, 348(sp)
lw ra, 324(sp)
addi sp, sp, 328
jalr x0, ra, 0

.globl write_pixel
write_pixel:
addi sp, sp, -28
sw ra, 24(sp)
sw a0, 0(sp)
sw a1, 4(sp)
sw a2, 8(sp)
.L_write_pixel_0:
lw a0, 0(sp)
jal ra, color_to_byte
sw a0, 12(sp)
lw t0, 12(sp)
li t1, 0x10000000
sb t0, 0(t1)
lw a0, 4(sp)
jal ra, color_to_byte
sw a0, 16(sp)
lw t0, 16(sp)
li t1, 0x10000000
sb t0, 0(t1)
lw a0, 8(sp)
jal ra, color_to_byte
sw a0, 20(sp)
lw t0, 20(sp)
li t1, 0x10000000
sb t0, 0(t1)
lw ra, 24(sp)
addi sp, sp, 28
jalr x0, ra, 0

.section .rodata
.p2align 2
.globl HEIGHT
HEIGHT:
.word 240
.globl MAT_DIELECTRIC
MAT_DIELECTRIC:
.word 2
.globl MAT_LAMBERTIAN
MAT_LAMBERTIAN:
.word 0
.globl MAT_METAL
MAT_METAL:
.word 1
.globl MAX_DEPTH
MAX_DEPTH:
.word 20
.globl NUM_SPHERES
NUM_SPHERES:
.word 15
.globl Q_EPS
Q_EPS:
.word 256
.globl Q_HALF
Q_HALF:
.word 32768
.globl Q_INF
Q_INF:
.word 2147418112
.globl Q_NEAR_ZERO
Q_NEAR_ZERO:
.word 33
.globl Q_ONE
Q_ONE:
.word 65536
.globl Q_PI
Q_PI:
.word 205887
.globl Q_TWO
Q_TWO:
.word 131072
.globl Q_UNIT_MIN_LENSQ
Q_UNIT_MIN_LENSQ:
.word 655
.globl Q_ZERO
Q_ZERO:
.word 0
.globl SAMPLES_PER_PIXEL
SAMPLES_PER_PIXEL:
.word 100
.globl SPHERE_AB
SPHERE_AB:
.word 65536
.word 6554
.word 32768
.word 3277
.word 65536
.word 9830
.word 57672
.word 52429
.word 6554
.word 32768
.word 39322
.word 65536
.word 9830
.word 42598
.word 36045
.globl SPHERE_AG
SPHERE_AG:
.word 65536
.word 13107
.word 39322
.word 3277
.word 65536
.word 29491
.word 55706
.word 19661
.word 36045
.word 42598
.word 6554
.word 65536
.word 16384
.word 49152
.word 39322
.globl SPHERE_AR
SPHERE_AR:
.word 65536
.word 26214
.word 45875
.word 42598
.word 65536
.word 7864
.word 52429
.word 13107
.word 49152
.word 55706
.word 29491
.word 65536
.word 45875
.word 39322
.word 9830
.globl SPHERE_MAT
SPHERE_MAT:
.word 2
.word 0
.word 1
.word 0
.word 2
.word 0
.word 1
.word 0
.word 0
.word 1
.word 0
.word 2
.word 0
.word 1
.word 0
.globl SPHERE_PARAM
SPHERE_PARAM:
.word 98304
.word 0
.word 0
.word 0
.word 98304
.word 0
.word 6554
.word 0
.word 0
.word 13107
.word 0
.word 98304
.word 0
.word 3277
.word 0
.globl SPHERE_R
SPHERE_R:
.word 65536
.word 65536
.word 65536
.word 13107
.word 13107
.word 13107
.word 13107
.word 13107
.word 13107
.word 13107
.word 13107
.word 13107
.word 13107
.word 13107
.word 13107
.globl SPHERE_R2
SPHERE_R2:
.word 65536
.word 65536
.word 65536
.word 2621
.word 2621
.word 2621
.word 2621
.word 2621
.word 2621
.word 2621
.word 2621
.word 2621
.word 2621
.word 2621
.word 2621
.globl SPHERE_X
SPHERE_X:
.word 0
.word -262144
.word 262144
.word 353894
.word 445645
.word 471859
.word 203162
.word 117965
.word 163840
.word 380109
.word 543949
.word 294912
.word -98304
.word -144179
.word 406323
.globl SPHERE_Y
SPHERE_Y:
.word 65536
.word 65536
.word 65536
.word 13107
.word 13107
.word 13107
.word 13107
.word 13107
.word 13107
.word 13107
.word 13107
.word 13107
.word 13107
.word 13107
.word 13107
.globl SPHERE_Z
SPHERE_Z:
.word 0
.word 0
.word 0
.word 78643
.word 52429
.word 163840
.word 137626
.word 104858
.word -91750
.word -78643
.word 98304
.word 209715
.word 117965
.word -98304
.word 249037
.globl ULP
ULP:
.word 1
.globl WIDTH
WIDTH:
.word 320
.globl __str_0
__str_0:
.word 80
.word 54
.word 10
.word 51
.word 50
.word 48
.word 32
.word 50
.word 52
.word 48
.word 10
.word 50
.word 53
.word 53
.word 10
.word 0
