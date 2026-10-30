open Ir

(*出力をためておく*)
let buf = Buffer.create 4096
(*スタックフレーム レコード*)
type frame = {
  out_bytes : int;               (* スタック引数の領域の大きさ *)
  arrays : (int * int) list;     (* 配列の番号 -> sp からのオフセット *)
  ra_off : int;                  (* ra を置く場所 *)
  size : int;                    (* フレーム全体の大きさ F(4の倍数) *)
}
(*コンパイラのモード*)
type mode = Off | Math | Isect

let make_frame (f : func) =
  (* 呼び出し時に必要なスタック引数・戻り値領域の最大ワード数 *)
  let max_outgoing_words =
    List.fold_left (fun m b ->
      List.fold_left (fun m i ->
        match i with
        | Call (rs, _, args) ->
            let stack_args = max 0 (List.length args - 8) in
            let stack_results = max 0 (List.length rs - 8) in
            max m (max stack_args stack_results)
        | _ -> m
      ) m b.body
    ) 0 f.blocks
  in
  let out_bytes = 4 * max_outgoing_words in
  let arr_base = out_bytes + 4 * f.nvregs in
  let arrays, arr_end =
    List.fold_left
      (fun (acc, off) (id, bytes) -> ((id, off) :: acc, off + bytes))
      ([], arr_base) f.arrays
  in
  let size = arr_end + 4 in
  if size > 2044 then failwith ("emitter: frame too large: " ^ f.name);
  { out_bytes; arrays; ra_off = size - 4; size }

(*命令*)
let emit_instr (m : mode) fr (i : instr) =
  let s v = fr.out_bytes + 4 * v in (*vreg vのスロットの場所*)
  match i with
  | Const (d, n) ->
      Printf.bprintf buf "li t0, %ld\n" n;
      Printf.bprintf buf "sw t0, %d(sp)\n" (s d)
  | Move (d, a) ->
      Printf.bprintf buf "lw t0, %d(sp)\n" (s a);
      Printf.bprintf buf "sw t0, %d(sp)\n" (s d)
  | Bin (op, d, a, b) ->
      Printf.bprintf buf "lw t0, %d(sp)\n" (s a);
      Printf.bprintf buf "lw t1, %d(sp)\n" (s b);
      (match op with
       | Add -> Printf.bprintf buf "add t0, t0, t1\n"
       | Sub -> Printf.bprintf buf "sub t0, t0, t1\n"
       | Mul -> Printf.bprintf buf "mul t0, t0, t1\n"
       | QMul ->
          if m = Off then
            (Printf.bprintf buf "mul t2, t0, t1\n";     (*積の下位 32 ビット*)
            Printf.bprintf buf "mulh t3, t0, t1\n";     (*積の上位 32 ビット*)
            Printf.bprintf buf "srli t2, t2, 16\n";
            Printf.bprintf buf "slli t3, t3, 16\n";
            Printf.bprintf buf "or t0, t2, t3\n")
          else
            Printf.bprintf buf "qmul t0, t0, t1\n"
       | Div -> Printf.bprintf buf "div t0, t0, t1\n"
       | Rem -> Printf.bprintf buf "rem t0, t0, t1\n"
       | Shl -> Printf.bprintf buf "sll t0, t0, t1\n"
       | Sra -> Printf.bprintf buf "sra t0, t0, t1\n"
       | And -> Printf.bprintf buf "and t0, t0, t1\n"
       | Or  -> Printf.bprintf buf "or t0, t0, t1\n"
       | Xor -> Printf.bprintf buf "xor t0, t0, t1\n"
       | Eq  -> Printf.bprintf buf "sub t0, t0, t1\nsltiu t0, t0, 1\n"  (*差が0なら1*)
       | Ne  -> Printf.bprintf buf "sub t0, t0, t1\nsltu t0, x0, t0\n"  (*差が0でなければ1*)
       | Lt  -> Printf.bprintf buf "slt t0, t0, t1\n"
       | Gt  -> Printf.bprintf buf "slt t0, t1, t0\n"                      
       | Le  -> Printf.bprintf buf "slt t0, t1, t0\nxori t0, t0, 1\n"   (*a <= b は !(b < a)*)
       | Ge  -> Printf.bprintf buf "slt t0, t0, t1\nxori t0, t0, 1\n"); (*a >= b は !(a < b)*)
      Printf.bprintf buf "sw t0, %d(sp)\n" (s d)
  | Un (Neg, d, a) ->
      Printf.bprintf buf "lw t0, %d(sp)\n" (s a);
      Printf.bprintf buf "sub t0, x0, t0\n";
      Printf.bprintf buf "sw t0, %d(sp)\n" (s d)
  | Un (Not, d, a) ->
      Printf.bprintf buf "lw t0, %d(sp)\n" (s a);
      Printf.bprintf buf "xori t0, t0, 1\n"; (*boolは0か1*)
      Printf.bprintf buf "sw t0, %d(sp)\n" (s d)
  | Intr (f, d, a) ->
      if m = Off then
        (Printf.bprintf buf "lw a0, %d(sp)\n" (s a);
        let name = match f with
          | Sqrt -> "__q16_sqrt" | Rsqrt -> "__q16_rsqrt" | Rcp -> "__q16_rcp" in
        Printf.bprintf buf "jal ra, %s\n" name;
        Printf.bprintf buf "sw a0, %d(sp)\n" (s d))
      else
        (Printf.bprintf buf "lw t0, %d(sp)\n" (s a);
        let cmd = match f with
          | Sqrt -> "qsqrt" | Rsqrt -> "qrsqrt" | Rcp -> "qrcp" in
        Printf.bprintf buf "%s t0, t0\n" cmd;
        Printf.bprintf buf "sw t0, %d(sp)\n" (s d))
  | AddrLocal (d, id) ->
      Printf.bprintf buf "addi t0, sp, %d\n" (List.assoc id fr.arrays);
      Printf.bprintf buf "sw t0, %d(sp)\n" (s d)
  | AddrGlobal (d, name) ->
      Printf.bprintf buf "la t0, %s\n" name;       
      Printf.bprintf buf "sw t0, %d(sp)\n" (s d)
  | Load (d, _, a, ofs) ->
      Printf.bprintf buf "lw t0, %d(sp)\n" (s a); (*アドレス*)
      Printf.bprintf buf "lw t0, %d(t0)\n" ofs;
      Printf.bprintf buf "sw t0, %d(sp)\n" (s d)
  | Store (_, a, ofs, src) ->
      Printf.bprintf buf "lw t0, %d(sp)\n" (s a); (*アドレス*)
      Printf.bprintf buf "lw t1, %d(sp)\n" (s src); (*書く値*)
      Printf.bprintf buf "sw t1, %d(t0)\n" ofs
  | Call (rs, name, args) ->
      (* 引数: 先頭8ワードはa0〜a7、残りはsp+0, sp+4,... *)
      List.iteri (fun k v ->
        if k < 8 then
          Printf.bprintf buf "lw a%d, %d(sp)\n" k (s v)
        else begin
          Printf.bprintf buf "lw t0, %d(sp)\n" (s v);
          Printf.bprintf buf "sw t0, %d(sp)\n" (4 * (k - 8))
        end
      ) args;
      Printf.bprintf buf "jal ra, %s\n" name;
      (* 戻り値: 先頭8ワードはa0〜a7、残りはスタックから取得 *)
      List.iteri (fun k r ->
        if k < 8 then
          Printf.bprintf buf "sw a%d, %d(sp)\n" k (s r)
        else begin
          Printf.bprintf buf "lw t0, %d(sp)\n" (4 * (k - 8));
          Printf.bprintf buf "sw t0, %d(sp)\n" (s r)
        end
      ) rs
  | Bprint a ->
      Printf.bprintf buf "lw t0, %d(sp)\n" (s a);
      Printf.bprintf buf "li t1, 0x10000000\n"; (*UART*)
      Printf.bprintf buf "sb t0, 0(t1)\n" (*下位 8 ビットを送る*)
  | Cycles d ->
      Printf.bprintf buf "li t1, 0x20000000\n"; (*cycles*)
      Printf.bprintf buf "lw t0, 0(t1)\n";
      Printf.bprintf buf "sw t0, %d(sp)\n" (s d)

(*終端*)
(*ブロックのラベルは .L_関数名_番号*)
let emit_term (f : func) fr (t : terminator) =
  let s v = fr.out_bytes + 4 * v in
  match t with
  | Jump l ->
      Printf.bprintf buf "j .L_%s_%d\n" f.name l
  | Branch (c, lt, lf) ->
      Printf.bprintf buf "lw t0, %d(sp)\n" (s c);
      Printf.bprintf buf "bnez t0, .L_%s_%d\n" f.name lt;   (*真(0以外)ならlt*)
      Printf.bprintf buf "j .L_%s_%d\n" f.name lf        (*偽ならlf*)
  | Ret vs ->
      (* 戻り値: 先頭8ワードはa0〜a7、残りは呼び出し側のスタックへ *)
      List.iteri (fun k v ->
        if k < 8 then
          Printf.bprintf buf "lw a%d, %d(sp)\n" k (s v)
        else begin
          Printf.bprintf buf "lw t0, %d(sp)\n" (s v);
          Printf.bprintf buf "sw t0, %d(sp)\n"
            (fr.size + 4 * (k - 8))
        end
      ) vs;
      Printf.bprintf buf "lw ra, %d(sp)\n" fr.ra_off;
      Printf.bprintf buf "addi sp, sp, %d\n" fr.size;
      Printf.bprintf buf "jalr x0, ra, 0\n"

(*関数*)
let emit_func (m : mode) (f : func) =
  let fr = make_frame f in
  let s v = fr.out_bytes + 4 * v in (*vreg vのspからの距離*)
  Printf.bprintf buf "\n.globl %s\n" f.name;
  Printf.bprintf buf "%s:\n" f.name;
  (*入口:フレームを取って、raと引数をしまう*)
  Printf.bprintf buf "addi sp, sp, %d\n" (- fr.size);
  Printf.bprintf buf "sw ra, %d(sp)\n" fr.ra_off;
  List.iteri (fun k p ->
    if k < 8 then                                       (*先頭の8つはa0〜a7*)
      Printf.bprintf buf "sw a%d, %d(sp)\n" k (s p) (*スロットにしまう*)
    else begin                                          (* 残りは呼び出し側のフレームのsp+F+4k*)
      Printf.bprintf buf "lw t0, %d(sp)\n" (fr.size + 4 * (k - 8));
      Printf.bprintf buf "sw t0, %d(sp)\n" (s p) (*スロットにしまう*)
    end) f.params;
  (*ブロック*)
  List.iter (fun b ->
    Printf.bprintf buf ".L_%s_%d:\n" f.name b.label;
    List.iter (emit_instr m fr) b.body;
    emit_term f fr b.term) f.blocks

(*c-7*)
let runtime = {|
.globl __q16_sqrt
__q16_sqrt:
blez a0, .L_sqrt_zero
srai t4, a0, 16
slli t5, a0, 16
li t0, 0
li t1, 0x01000000
li a2, 0
.L_sqrt_loop:
add t2, t0, t1
srli t2, t2, 1
mul t6, t2, t2
mulh a1, t2, t2
blt a1, t4, .L_sqrt_le
bgt a1, t4, .L_sqrt_gt
bgeu t5, t6, .L_sqrt_le
.L_sqrt_gt:
addi t1, t2, -1
j .L_sqrt_check
.L_sqrt_le:
mv a2, t2
addi t0, t2, 1
.L_sqrt_check:
bge t1, t0, .L_sqrt_loop
mv a0, a2
jalr x0, ra, 0
.L_sqrt_zero:
li a0, 0
jalr x0, ra, 0

.globl __q16_rcp
__q16_rcp:
beqz a0, .L_rcp_max
li t0, 0
bgez a0, .L_rcp_abs
li t0, 1
sub a0, x0, a0
.L_rcp_abs:
li t3, 3
bltu a0, t3, .L_rcp_sat
li a1, 1
li a2, 0
li a3, 0
li t1, 32
.L_rcp_loop:
slli a3, a3, 1
srli t2, a2, 31
slli a1, a1, 1
or a1, a1, t2
slli a2, a2, 1
bltu a1, a0, .L_rcp_next
sub a1, a1, a0
ori a3, a3, 1
.L_rcp_next:
addi t1, t1, -1
bnez t1, .L_rcp_loop
beqz t0, .L_rcp_pos_ret
or t3, a1, a2
beqz t3, .L_rcp_neg_exact
addi a3, a3, 1
.L_rcp_neg_exact:
sub a0, x0, a3
jalr x0, ra, 0
.L_rcp_pos_ret:
mv a0, a3
jalr x0, ra, 0
.L_rcp_sat:
bnez t0, .L_rcp_min
.L_rcp_max:
lui a0, 0x80000
addi a0, a0, -1
jalr x0, ra, 0
.L_rcp_min:
lui a0, 0x80000
jalr x0, ra, 0

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
|}

let emit_program (m : mode) (p : program) : string =
  Buffer.clear buf;
  Printf.bprintf buf ".section .text\n";

  List.iter (emit_func m) p.funcs;
  (if m = Off then Buffer.add_string buf runtime);
  (*定数データ*)
  if p.consts <> [] then begin
    Printf.bprintf buf "\n.section .rodata\n";
    Printf.bprintf buf ".p2align 2\n";
    List.iter (fun (name, words) ->
      Printf.bprintf buf ".globl %s\n" name;
      Printf.bprintf buf "%s:\n" name;
      List.iter (fun w -> Printf.bprintf buf ".word %ld\n" w) words) p.consts
  end;
  Buffer.contents buf

