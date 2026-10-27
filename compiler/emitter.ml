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

let make_frame (f : func) =
  (* この関数の中の呼び出しで、スタックに積む引数がいちばん多いもの *)
  let max_stack_args =
    List.fold_left (fun m b ->
      List.fold_left (fun m i ->
        match i with
        | Call (_, _, args) -> max m (List.length args - 8)
        | _ -> m) m b.body) 0 f.blocks
  in
  let out_bytes = 4 * max 0 max_stack_args in (*8個を超えた引数のバイト数*)
  let arr_base = out_bytes + 4 * f.nvregs in (*スロット*)
  let arrays, arr_end =
    List.fold_left (fun (acc, off) (id, bytes) -> ((id, off) :: acc, off + bytes))
      ([], arr_base) f.arrays
  in (*配列*)
  let size = arr_end + 4 in 
  if size > 2044 then failwith ("emitter: frame too large: " ^ f.name);
  { out_bytes; arrays; ra_off = size - 4; size }

(*命令*)
let emit_instr fr (i : instr) =
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
           Printf.bprintf buf "mul t2, t0, t1\n";     (*積の下位 32 ビット*)
           Printf.bprintf buf "mulh t3, t0, t1\n";     (*積の上位 32 ビット*)
           Printf.bprintf buf "srli t2, t2, 16\n";
           Printf.bprintf buf "slli t3, t3, 16\n";
           Printf.bprintf buf "or t0, t2, t3\n"
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
      let name = match f with
        | Sqrt -> "__q16_sqrt" | Rsqrt -> "__q16_rsqrt" | Rcp -> "__q16_rcp" in
      Printf.bprintf buf "lw a0, %d(sp)\n" (s a);
      Printf.bprintf buf "jal ra, %s\n" name;
      Printf.bprintf buf "sw a0, %d(sp)\n" (s d)
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
      (*引数:先頭 8 ワードは a0〜a7、残りは sp+0, sp+4,...*)
      List.iteri (fun k v ->
        if k < 8 then
          Printf.bprintf buf "lw a%d, %d(sp)\n" k (s v)
        else begin
          Printf.bprintf buf "lw t0, %d(sp)\n" (s v);
          Printf.bprintf buf "sw t0, %d(sp)\n" (4 * (k - 8))
        end) args;
      Printf.bprintf buf "jal ra, %s\n" name;
      (*戻り値:a0, a1, ... をスロットへ*)
      List.iteri (fun k r -> Printf.bprintf buf "sw a%d, %d(sp)\n" k (s r)) rs
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
      (*戻り値をa0,a1,...に入れる*)
      List.iteri (fun k v -> Printf.bprintf buf "lw a%d, %d(sp)\n" k (s v)) vs;
      Printf.bprintf buf "lw ra, %d(sp)\n" fr.ra_off;
      Printf.bprintf buf "addi sp, sp, %d\n" fr.size;
      Printf.bprintf buf "jalr x0, ra, 0\n"

(*関数*)
let emit_func (f : func) =
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
    List.iter (emit_instr fr) b.body;
    emit_term f fr b.term) f.blocks

(*c-7*)
let runtime = {|
.globl __q16_rcp
__q16_rcp:
    beqz    a0, .L_rcp_zero_or_small
    bltz    a0, .L_rcp_negative
    li      a5, 2
    bgeu    a5, a0, .L_rcp_zero_or_small
    neg     a5, a0
    divu    a0, a5, a0
    addi    a0, a0, 1
    ret
.L_rcp_negative:
    neg     a5, a0
    li      a4, 2
    lui     a0, 0x80000
    bgeu    a4, a5, .L_rcp_exit
    li      a0, -1
    divu    a0, a0, a5
    not     a0, a0
    ret
.L_rcp_zero_or_small:
    lui     a0, 0x80000
    addi    a0, a0, -1
.L_rcp_exit:
    ret

.globl __q16_sqrt
__q16_sqrt:
    blez    a0, .L_sqrt_zero_or_neg
    srli    a7, a0, 0x10
    slli    a6, a0, 0x10
    li      a5, 0
    lui     a4, 0x40000
.L_sqrt_scale_loop:
    slli    a3, a4, 0x1e
    srli    a5, a5, 0x2
    srli    a4, a4, 0x2
    or      a5, a3, a5
    bltu    a7, a4, .L_sqrt_scale_loop
    bne     a4, a7, .L_sqrt_init
    bltu    a6, a5, .L_sqrt_scale_loop
.L_sqrt_init:
    li      a0, 0
    li      a1, 0
.L_sqrt_loop:
    add     t3, a0, a5
    add     t1, a1, a4
    sltu    a2, t3, a0
    slli    t6, a1, 0x1f
    srli    a3, a0, 0x1
    or      a3, t6, a3
    add     a2, a2, t1
    srli    t1, a1, 0x1
    slli    t5, a4, 0x1e
    srli    t4, a5, 0x2
    mv      a0, a3
    mv      a1, t1
    bltu    a7, a2, .L_sqrt_loop_end
    add     a5, a3, a5
    sub     t6, a6, t3
    sltu    t0, a6, t6
    add     t1, t1, a4
    sub     t2, a7, a2
    sltu    a3, a5, a3
    bne     a2, a7, .L_sqrt_update
    bltu    a6, t3, .L_sqrt_loop_end
.L_sqrt_update:
    mv      a6, t6
    sub     a7, t2, t0
    mv      a0, a5
    add     a1, a3, t1
.L_sqrt_loop_end:
    or      a5, t5, t4
    srli    a4, a4, 0x2
    or      a3, a5, a4
    bnez    a3, .L_sqrt_loop
    ret
.L_sqrt_zero_or_neg:
    li      a0, 0
    ret

.globl q16_rsqrt
q16_rsqrt:
    mv      a1, a0
    blez    a0, .L_rsqrt_zero_or_neg
    li      t1, 25
    lui     a7, 0x1000
    li      a0, 0
    lui     t3, 0x10
.L_rsqrt_loop:
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
    bnez    a5, .L_rsqrt_branch
    bgeu    a2, t3, .L_rsqrt_branch
.L_rsqrt_store:
    mv      a0, a4
.L_rsqrt_next:
    addi    t1, t1, -1
    srli    a7, a7, 0x1
    bnez    t1, .L_rsqrt_loop
    ret
.L_rsqrt_branch:
    bne     a2, t3, .L_rsqrt_next
    bnez    a5, .L_rsqrt_next
    beqz    a6, .L_rsqrt_store
    j       .L_rsqrt_next
.L_rsqrt_zero_or_neg:
    li      a0, 0
    ret
|}

let emit_program (p : program) : string =
  Buffer.clear buf;
  Printf.bprintf buf ".section .text\n";

  List.iter emit_func p.funcs;
  Buffer.add_string buf runtime;
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