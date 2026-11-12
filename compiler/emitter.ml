open Ir

(*出力をためておく*)
let buf = Buffer.create 4096
(*スタックフレーム レコード*)
type frame = {
  out_bytes : int;               (* スタック引数の領域の大きさ *)
  arrays : (int * int) list;     (* 配列の番号 -> sp からのオフセット *)
  ra_off : int;                  (* ra を置く場所 *)
  size : int;                    (* フレーム全体の大きさ F(4の倍数) *)
  nbases : int;                  (* 遠いスロット用のベースレジスタ(s1, s2, ...)の数 *)
  slot_base : int;               (* vreg のスロットが始まる場所(sp からの距離) *)
}
(*コンパイラのモード*)
type mode = Off | Math | Isect
(*アーキテクチャ指定*)
type march = I | Im | Im_zbb

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
  let rough = out_bytes + 4 * 11 + 4 * f.nvregs
              + List.fold_left (fun acc (_, bytes) -> acc + bytes) 0 f.arrays + 4 in
  let nbases = if rough <= 2048 then 0 else min 11 ((rough - 1 + 2048) / 4096) in
  let slot_base = out_bytes + 4 * nbases in      (* [スタック引数 | s1..sN の保存 | スロット | 配列 | ra] *)
  let arr_base = slot_base + 4 * f.nvregs in
  let arrays, arr_end =
    List.fold_left
      (fun (acc, off) (id, bytes) -> ((id, off) :: acc, off + bytes))
      ([], arr_base) f.arrays
  in
  let size = arr_end + 4 in
  { out_bytes; arrays; ra_off = size - 4; size; nbases; slot_base }

   (*フレームが大きい関数では、入口で s1 = sp+4096, s2 = sp+8192, ... を作っておき、
   遠いスロットは「いちばん近いベースレジスタ + 12 ビット」で 1 命令で読み書きする。
   それでも届かない場所だけ、t6 で番地を計算する。
   s1〜s11 は、使う関数の入口でしまい、出口でもどす*)
let fits n = -2048 <= n && n <= 2044 (*2047*) 

let nbases = ref 0 (*今出している関数のベースレジスタの数*)

(*sp+ off を「レジスタ + 12 ビットの距離」で表せるなら Some (レジスタ, 距離) *)
let locate off =
  if fits off then Some ("sp", off)
  else
    let k = (off + 2048) / 4096 in (* いちばん近いベース s<k> = sp + 4096k *)
    if off > 0 && k >= 1 && k <= !nbases then Some (Printf.sprintf "s%d" k, off - 4096 * k)
    else None

(* reg = mem[base + off](Load 命令用。base は t0 など) *)
let load_from reg base off =
  if fits off then Printf.bprintf buf "lw %s, %d(%s)\n" reg off base
  else Printf.bprintf buf "li t6, %d\nadd t6, %s, t6\nlw %s, 0(t6)\n" off base reg

(* mem[base + off] = reg(Store 命令用) *)
let store_to reg base off =
  if fits off then Printf.bprintf buf "sw %s, %d(%s)\n" reg off base
  else Printf.bprintf buf "li t6, %d\nadd t6, %s, t6\nsw %s, 0(t6)\n" off base reg

(* sp からの読み書き(vreg のスロット、ra など) *)
let load reg off =
  match locate off with
  | Some (b, d) -> Printf.bprintf buf "lw %s, %d(%s)\n" reg d b
  | None -> load_from reg "sp" off

let store reg off =
  match locate off with
  | Some (b, d) -> Printf.bprintf buf "sw %s, %d(%s)\n" reg d b
  | None -> store_to reg "sp" off

(* rd = sp + off(配列の番地) *)
let add_sp rd off =
  match locate off with
  | Some (b, d) -> Printf.bprintf buf "addi %s, %s, %d\n" rd b d
  | None -> Printf.bprintf buf "li t6, %d\nadd %s, sp, t6\n" off rd

(* sp を動かす(フレームを取る・返す)。ベースレジスタは使わない *)
let move_sp delta =
  if fits delta then Printf.bprintf buf "addi sp, sp, %d\n" delta
  else Printf.bprintf buf "li t6, %d\nadd sp, sp, t6\n" delta

(*命令*)
let emit_instr (md : mode) (mrc : march) fr (i : instr) =
  let s v = fr.slot_base + 4 * v in (*vreg vのスロットの場所*)
  match i with
  | Const (d, n) ->
      Printf.bprintf buf "li t0, %ld\n" n;
      store "t0" (s d)
  | Move (d, a) ->
      load "t0" (s a);
      store "t0" (s d)
  | Bin (op, d, a, b) ->
      load "t0" (s a);
      load "t1" (s b);
      (match op with
       | Add -> Printf.bprintf buf "add t0, t0, t1\n"
       | Sub -> Printf.bprintf buf "sub t0, t0, t1\n"
       | Mul -> Printf.bprintf buf "mul t0, t0, t1\n"
       | QMul ->
          if md = Off then
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
      store "t0" (s d)
  | Un (Neg, d, a) ->
      load "t0" (s a);
      Printf.bprintf buf "sub t0, x0, t0\n";
      store "t0" (s d)
  | Un (Not, d, a) ->
      load "t0" (s a);
      Printf.bprintf buf "xori t0, t0, 1\n"; (*boolは0か1*)
      store "t0" (s d)
  | Intr (f, d, a) ->
      if md = Off then
        (load "a0" (s a);
        let name = match f with
          | Sqrt -> "__q16_sqrt" | Rsqrt -> "__q16_rsqrt" | Rcp -> "__q16_rcp" in
        Printf.bprintf buf "jal ra, %s\n" name;
        store "a0" (s d))
      else
        (load "t0" (s a);
        let cmd = match f with
          | Sqrt -> "qsqrt" | Rsqrt -> "qrsqrt" | Rcp -> "qrcp" in
        Printf.bprintf buf "%s t0, t0\n" cmd;
        store "t0" (s d))
  | Zbb_b (op, d, a, b) ->
      if mrc = Im_zbb then
        (load "t0" (s a);
         load "t1" (s b);
        (match op with
          | Min  -> Printf.bprintf buf "min t0, t0, t1\n"
          | Max  -> Printf.bprintf buf "max t0, t0, t1\n"
          | Minu -> Printf.bprintf buf "minu t0, t0, t1\n"
          | Maxu -> Printf.bprintf buf "maxu t0, t0, t1\n"
          | Andn -> Printf.bprintf buf "andn t0, t0, t1\n"
          | Orn  -> Printf.bprintf buf "orn t0, t0, t1\n"
          | Xnor -> Printf.bprintf buf "xnor t0, t0, t1\n");
        store "t0" (s d))
      else
        (load "a0" (s a);
         load "a1" (s b);
        let name = match op with
          | Min  -> "__min"
          | Max  -> "__max"
          | Minu -> "__minu"
          | Maxu -> "__maxu"
          | Andn -> "__andn"
          | Orn  -> "__orn"
          | Xnor -> "__xnor" in
        Printf.bprintf buf "jal ra, %s\n" name;
        store "a0" (s d))
  | Zbb_u (op, d, a) ->
      if mrc = Im_zbb then
        (load "t0" (s a);
        (match op with
          | Clz -> Printf.bprintf buf "clz t0, t0\n"
          | Sext_b -> Printf.bprintf buf "sext.b t0, t0\n"
          | Sext_h -> Printf.bprintf buf "sext.h t0, t0\n");
        store "t0" (s d))
      else
        (load "a0" (s a);
        let name = match op with
          | Clz -> "__clz"
          | Sext_b -> "__sext_b"
          | Sext_h -> "__sext_h" in
        Printf.bprintf buf "jal ra, %s\n" name;
       store "a0" (s d))
  | AddrLocal (d, id) ->
      add_sp "t0" (List.assoc id fr.arrays);
      store "t0" (s d)
  | AddrGlobal (d, name) ->
      Printf.bprintf buf "la t0, %s\n" name;       
      store "t0" (s d)
  | Load (d, _, a, ofs) ->
      load "t0" (s a); (*アドレス*)
      load_from "t0" "t0" ofs;
      store "t0" (s d)
  | Store (_, a, ofs, src) ->
      load "t0" (s a); (*アドレス*)
      load "t1" (s src); (*書く値*)
      store_to "t1" "t0" ofs
  | Call (rs, name, args) ->
      (* 引数: 先頭8ワードはa0〜a7、残りはsp+0, sp+4,... *)
      List.iteri (fun k v ->
        if k < 8 then
          load (Printf.sprintf "a%d" k) (s v)
        else begin
          load "t0" (s v);
          store "t0" (4 * (k - 8))
        end
      ) args;
      Printf.bprintf buf "jal ra, %s\n" name;
      (* 戻り値: 先頭8ワードはa0〜a7、残りはスタックから取得 *)
      List.iteri (fun k r ->
        if k < 8 then
          store (Printf.sprintf "a%d" k) (s r)
        else begin
          load "t0" (4 * (k - 8));
          store "t0" (s r)
        end
      ) rs
  | Bprint a ->
      load "t0" (s a);
      Printf.bprintf buf "li t1, 0x10000000\n"; (*UART*)
      Printf.bprintf buf "sb t0, 0(t1)\n" (*下位 8 ビットを送る*)
  | Cycles d ->
      Printf.bprintf buf "li t1, 0x20000000\n"; (* cycle_lo *)
      Printf.bprintf buf "lw t0, 0(t1)\n";
      store "t0" (s d)    
(*| CyclesH d ->
      Printf.bprintf buf "li t1, 0x20000004\n"; (* cycle_hi *)
      Printf.bprintf buf "lw t0, 0(t1)\n";
      store "t0" (s d)
  | Instret d ->
      Printf.bprintf buf "li t1, 0x20000008\n"; (* instret_lo *)
      Printf.bprintf buf "lw t0, 0(t1)\n";
      store "t0" (s d)
  | InstretH d ->
      Printf.bprintf buf "li t1, 0x2000000C\n"; (* instret_hi *)
      Printf.bprintf buf "lw t0, 0(t1)\n";
      store "t0" (s d) *)
  | Qabs (d, a) ->
      if mrc = Im_zbb then
        (load "t0" (s a);
        Printf.bprintf buf "neg t1, t0\n";
        Printf.bprintf buf "max t0, t1, t0\n";
        store "t0" (s d))
      else
        (load "a0" (s a);
        Printf.bprintf buf "neg a1, a0\n";
        Printf.bprintf buf "jal ra, __max\n";
        store "a0" (s d))
  | Qclamp (d, a, b, c) ->
      if mrc = Im_zbb then
        (load "t0" (s a);
        load "t1" (s b);
        load "t2" (s c);
        Printf.bprintf buf "max t0, t0, t1\n";
        Printf.bprintf buf "min t0, t0, t2\n";
        store "t0" (s d))
      else
        (load "a0" (s a);
        load "a1" (s b);
        Printf.bprintf buf "jal ra, __max\n";
        load "a1" (s c);
        Printf.bprintf buf "jal ra, __min\n";
        store "a0" (s d))
        Printf.bprintf buf "sw a0, %d(sp)\n" (s d))
  | AccelSetSphere (i, x, y, z, r, r2, m) ->
        Printf.bprintf buf "lw t0, %d(sp)\n" (s i);
        Printf.bprintf buf "slli t0, t0, 5\n";
        Printf.bprintf buf "li t1, 0x30000000\n";
        Printf.bprintf buf "add t1, t1, t0\n";
        Printf.bprintf buf "lw t0, %d(sp)\n" (s x);
        Printf.bprintf buf "sw t0, 256(t1)\n";
        Printf.bprintf buf "lw t0, %d(sp)\n" (s y);
        Printf.bprintf buf "sw t0, 260(t1)\n";
        Printf.bprintf buf "lw t0, %d(sp)\n" (s z);
        Printf.bprintf buf "sw t0, 264(t1)\n";
        Printf.bprintf buf "lw t0, %d(sp)\n" (s r);
        Printf.bprintf buf "sw t0, 268(t1)\n";
        Printf.bprintf buf "lw t0, %d(sp)\n" (s r2);
        Printf.bprintf buf "sw t0, 272(t1)\n";
        Printf.bprintf buf "lw t0, %d(sp)\n" (s m);
        Printf.bprintf buf "sw t0, 276(t1)\n"
  | AccelHit (d, ox, oy, oz, dx, dy, dz, tmin, tmax) ->
        Printf.bprintf buf "li t1, 0x30000000\n";
        Printf.bprintf buf "lw t0, %d(sp)\n" (s ox);
        Printf.bprintf buf "lw t2, %d(sp)\n" (s oy);
        Printf.bprintf buf "lw t3, %d(sp)\n" (s oz);
        Printf.bprintf buf "lw t4, %d(sp)\n" (s dx);
        Printf.bprintf buf "sw t0, 0(t1)\n";
        Printf.bprintf buf "sw t2, 4(t1)\n";
        Printf.bprintf buf "sw t3, 8(t1)\n";
        Printf.bprintf buf "sw t4, 12(t1)\n";
        Printf.bprintf buf "lw t0, %d(sp)\n" (s dy);
        Printf.bprintf buf "lw t2, %d(sp)\n" (s dz);
        Printf.bprintf buf "lw t3, %d(sp)\n" (s tmin);
        Printf.bprintf buf "lw t4, %d(sp)\n" (s tmax);
        Printf.bprintf buf "sw t0, 16(t1)\n";
        Printf.bprintf buf "sw t2, 20(t1)\n";
        Printf.bprintf buf "sw t3, 24(t1)\n";
        Printf.bprintf buf "sw t4, 28(t1)\n";
        Printf.bprintf buf "lw t0, 32(t1)\n";
        Printf.bprintf buf "sw t0, %d(sp)\n" (s d)
  | AccelT d ->
        Printf.bprintf buf "li t1, 0x30000000\n";
        Printf.bprintf buf "lw t0, 36(t1)\n";
        Printf.bprintf buf "sw t0, %d(sp)\n" (s d)
  | RngSeed a ->
        Printf.bprintf buf "lw t0, %d(sp)\n" (s a);
        Printf.bprintf buf "qseed x0, t0\n"
  | RandQ16 d ->
        Printf.bprintf buf "qrand t0, x0\n";
        Printf.bprintf buf "sw t0, %d(sp)\n" (s d)
  | RandQ16S d ->
        Printf.bprintf buf "qrands t0, x0\n";
        Printf.bprintf buf "sw t0, %d(sp)\n" (s d)
  | AccelSetSphere (i, x, y, z, r, r2, m) ->
        Printf.bprintf buf "lw t0, %d(sp)\n" (s i);
        Printf.bprintf buf "slli t0, t0, 5\n";
        Printf.bprintf buf "li t1, 0x30000000\n";
        Printf.bprintf buf "add t1, t1, t0\n";
        Printf.bprintf buf "lw t0, %d(sp)\n" (s x);
        Printf.bprintf buf "sw t0, 256(t1)\n";
        Printf.bprintf buf "lw t0, %d(sp)\n" (s y);
        Printf.bprintf buf "sw t0, 260(t1)\n";
        Printf.bprintf buf "lw t0, %d(sp)\n" (s z);
        Printf.bprintf buf "sw t0, 264(t1)\n";
        Printf.bprintf buf "lw t0, %d(sp)\n" (s r);
        Printf.bprintf buf "sw t0, 268(t1)\n";
        Printf.bprintf buf "lw t0, %d(sp)\n" (s r2);
        Printf.bprintf buf "sw t0, 272(t1)\n";
        Printf.bprintf buf "lw t0, %d(sp)\n" (s m);
        Printf.bprintf buf "sw t0, 276(t1)\n"
  | AccelHit (d, ox, oy, oz, dx, dy, dz, tmin, tmax) ->
        Printf.bprintf buf "li t1, 0x30000000\n";
        Printf.bprintf buf "lw t0, %d(sp)\n" (s ox);
        Printf.bprintf buf "lw t2, %d(sp)\n" (s oy);
        Printf.bprintf buf "lw t3, %d(sp)\n" (s oz);
        Printf.bprintf buf "lw t4, %d(sp)\n" (s dx);
        Printf.bprintf buf "sw t0, 0(t1)\n";
        Printf.bprintf buf "sw t2, 4(t1)\n";
        Printf.bprintf buf "sw t3, 8(t1)\n";
        Printf.bprintf buf "sw t4, 12(t1)\n";
        Printf.bprintf buf "lw t0, %d(sp)\n" (s dy);
        Printf.bprintf buf "lw t2, %d(sp)\n" (s dz);
        Printf.bprintf buf "lw t3, %d(sp)\n" (s tmin);
        Printf.bprintf buf "lw t4, %d(sp)\n" (s tmax);
        Printf.bprintf buf "sw t0, 16(t1)\n";
        Printf.bprintf buf "sw t2, 20(t1)\n";
        Printf.bprintf buf "sw t3, 24(t1)\n";
        Printf.bprintf buf "sw t4, 28(t1)\n";
        Printf.bprintf buf "lw t0, 32(t1)\n";
        Printf.bprintf buf "sw t0, %d(sp)\n" (s d)
  | AccelT d ->
        Printf.bprintf buf "li t1, 0x30000000\n";
        Printf.bprintf buf "lw t0, 36(t1)\n";
        Printf.bprintf buf "sw t0, %d(sp)\n" (s d)
  | RngSeed a ->
        Printf.bprintf buf "lw t0, %d(sp)\n" (s a);
        Printf.bprintf buf "qseed x0, t0\n"
  | RandQ16 d ->
        Printf.bprintf buf "qrand t0, x0\n";
        Printf.bprintf buf "sw t0, %d(sp)\n" (s d)
  | RandQ16S d ->
        Printf.bprintf buf "qrands t0, x0\n";
        Printf.bprintf buf "sw t0, %d(sp)\n" (s d)

(*終端*)
(*ブロックのラベルは .L_関数名_番号*)
let emit_term (f : func) fr (t : terminator) =
  let s v = fr.slot_base + 4 * v in
  match t with
  | Jump l ->
      Printf.bprintf buf "j .L_%s_%d\n" f.name l
  | Branch (c, lt, lf) ->
      load "t0" (s c);
      Printf.bprintf buf "bnez t0, .L_%s_%d\n" f.name lt;   (*真(0以外)ならlt*)
      Printf.bprintf buf "j .L_%s_%d\n" f.name lf        (*偽ならlf*)
  | Ret vs ->
      (* 戻り値: 先頭8ワードはa0〜a7、残りは呼び出し側のスタックへ *)
      List.iteri (fun k v ->
        if k < 8 then
          load (Printf.sprintf "a%d" k) (s v)
        else begin
          load "t0" (s v);
          store "t0" (fr.size + 4 * (k - 8))
        end
      ) vs;
      load "ra" fr.ra_off;
      (* ベースレジスタを、呼び出し元の値にもどす *)
      for k = 1 to fr.nbases do
        Printf.bprintf buf "lw s%d, %d(sp)\n" k (fr.out_bytes + 4 * (k - 1))
      done;
      move_sp fr.size;
      Printf.bprintf buf "jalr x0, ra, 0\n"

(*関数*)
let emit_func (md : mode) (mrc : march) (f : func) =
  let fr = make_frame f in
  let s v = fr.slot_base + 4 * v in (*vreg vのspからの距離*)
  Printf.bprintf buf "\n.globl %s\n" f.name;
  Printf.bprintf buf "%s:\n" f.name;
  (*入口:フレームを取って、raと引数をしまう*)
  move_sp (- fr.size);
  (* フレームが大きいとき:s1..sN をしまってから、s<k> = sp + 4096k を作る *)
  for k = 1 to fr.nbases do
    Printf.bprintf buf "sw s%d, %d(sp)\n" k (fr.out_bytes + 4 * (k - 1))
  done;
  for k = 1 to fr.nbases do
    Printf.bprintf buf "li t6, %d\nadd s%d, sp, t6\n" (4096 * k) k
  done;
  nbases := fr.nbases;
  store "ra" fr.ra_off;
  List.iteri (fun k p ->
    if k < 8 then                                       (*先頭の8つはa0〜a7*)
      store (Printf.sprintf "a%d" k) (s p) (*スロットにしまう*)
    else begin                                          (* 残りは呼び出し側のフレームのsp+F+4k*)
      load "t0" (fr.size + 4 * (k - 8));
      store "t0" (s p) (*スロットにしまう*)
    end) f.params;
  (*ブロック*)
  List.iter (fun b ->
    Printf.bprintf buf ".L_%s_%d:\n" f.name b.label;
    List.iter (emit_instr md mrc fr) b.body;
    emit_term f fr b.term) f.blocks

(*c-7*)
let runtime_math = {|
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

let runtime_m = {|
|}

let runtime_zbb = {|
.globl __min
__min:
    blt a0, a1, .L_min_ret
    mv  a0, a1
.L_min_ret:
    jalr x0, ra, 0

.globl __max
__max:
    bge a0, a1, .L_max_ret
    mv  a0, a1
.L_max_ret:
    jalr x0, ra, 0

.globl __minu
__minu:
    bltu a0, a1, .L_minu_ret
    mv   a0, a1
.L_minu_ret:
    jalr x0, ra, 0

.globl __maxu
__maxu:
    bgeu a0, a1, .L_maxu_ret
    mv   a0, a1
.L_maxu_ret:
    jalr x0, ra, 0

.globl __andn
__andn:
    not  a1, a1
    and  a0, a0, a1
    jalr x0, ra, 0

.globl __orn
__orn:
    not  a1, a1
    or   a0, a0, a1
    jalr x0, ra, 0

.globl __xnor
__xnor:
    xor  a0, a0, a1
    not  a0, a0
    jalr x0, ra, 0

.globl __sext_b
__sext_b:
    slli a0, a0, 24
    srai a0, a0, 24
    jalr x0, ra, 0

.globl __sext_h
__sext_h:
    slli a0, a0, 16
    srai a0, a0, 16
    jalr x0, ra, 0

.globl __clz
__clz:
    li      a1, 31
    li      t0, 1
    slli    t0, t0, 31
.L_highest_set_bit_loop:
    and     t1, a0, t0
    bnez    t1, .L_highest_set_bit_found
    srli    t0, t0, 1
    addi    a1, a1, -1
    bgez    a1, .L_highest_set_bit_loop
    li      a1, -1
.L_highest_set_bit_found:
    li      a0, 31
    sub     a0, a0, a1
    jalr x0, ra, 0
|}

let emit_program (md : mode) (mrc : march) (p : program) : string =
  Buffer.clear buf;
  Printf.bprintf buf ".section .text\n";

  List.iter (emit_func md mrc) p.funcs;
  (if md = Off then Buffer.add_string buf runtime_math);
  (match mrc with
    | I -> (Buffer.add_string buf runtime_m;
            Buffer.add_string buf runtime_zbb)
    | Im -> (Buffer.add_string buf runtime_zbb)
    | _ -> ());
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
