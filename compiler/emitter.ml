open Ir

(*出力をためておく*)
let buf = Buffer.create 4096

(*コンパイラのモード*)
type mode = Off | Math | Isect
(*アーキテクチャ指定*)
type march = I | Im | Im_zbb

(*スタックフレーム レコード
  [スタック引数 | ベースレジスタ s1..sN の保存 | 割り当てで使った s の保存 | スロット | 配列 | ra] *)
type frame = {
  out_bytes : int;               (* スタック引数の領域の大きさ *)
  arrays : (int * int) list;     (* 配列の番号 -> sp からのオフセット *)
  ra_off : int;                  (* ra を置く場所 *)
  size : int;                    (* フレーム全体の大きさ F(4の倍数) *)
  nbases : int;                  (* 遠いスロット用のベースレジスタ(s1, s2, ...)の数 *)
  saved : string list;           (* 割り当てで使ったので、入口でしまい出口でもどす s レジスタ *)
  slot_base : int;               (* スロットが始まる場所(sp からの距離) *)
  loc : vreg -> Regalloc.loc;    (* vreg の置き場所 *)
}

(* 呼び出し時に必要なスタック引数・戻り値領域の大きさ(バイト) *)
let outgoing_bytes (f : func) =
  4 * List.fold_left (fun m b ->
    List.fold_left (fun m i ->
      match i with
      | Call (rs, _, args) ->
          max m (max (max 0 (List.length args - 8)) (max 0 (List.length rs - 8)))
      | _ -> m) m b.body) 0 f.blocks

let array_bytes (f : func) = List.fold_left (fun acc (_, bytes) -> acc + bytes) 0 f.arrays

(* フレームの大きさが rough のとき、必要なベースレジスタの数 *)
let bases_for rough = if rough <= 2048 then 0 else min 11 ((rough - 1 + 2048) / 4096)

(* 置き場所が決まったあとの、残りの計算 *)
let layout (f : func) ~out_bytes ~nbases ~saved ~nslots ~loc =
  let slot_base = out_bytes + 4 * nbases + 4 * List.length saved in
  let arr_base = slot_base + 4 * nslots in
  let arrays, arr_end =
    List.fold_left
      (fun (acc, off) (id, bytes) -> ((id, off) :: acc, off + bytes))
      ([], arr_base) f.arrays
  in
  let size = arr_end + 4 in
  { out_bytes; arrays; ra_off = size - 4; size; nbases; saved; slot_base; loc }

(* 割り当てなし:vreg v はスロット v(今までどおり、全部スタック) *)
let make_frame (f : func) =
  let out_bytes = outgoing_bytes f in
  let rough = out_bytes + 4 * 11 + 4 * f.nvregs + array_bytes f + 4 in
  layout f ~out_bytes ~nbases:(bases_for rough) ~saved:[] ~nslots:f.nvregs
    ~loc:(fun v -> Regalloc.Slot v)

(* 割り当てあり:Regalloc の結果で置き場所を決める。
   フレームが大きくてベースレジスタが要るときは、その s を外して割り当てをやり直す *)
let make_frame_ra ~accel_off ~zbb (f : func) =
  let out_bytes = outgoing_bytes f in
  let rec go nb =
    let reserved = List.init nb (fun k -> Printf.sprintf "s%d" (k + 1)) in
    let (locs, nslots, used) = Regalloc.allocate ~reserved ~accel_off ~zbb f in
    let size = out_bytes + 4 * nb + 4 * List.length used + 4 * nslots + array_bytes f + 4 in
    let need = bases_for size in
    if need <= nb then (nb, locs, nslots, used) else go need
  in
  let (nbases, locs, nslots, saved) = go 0 in
  let loc v =
    match Hashtbl.find_opt locs v with
    | Some l -> l
    | None -> failwith (Printf.sprintf "regalloc: v%d has no location in %s" v f.name)
  in
  layout f ~out_bytes ~nbases ~saved ~nslots ~loc

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

(* sp からの読み書き(スロット、ra など) *)
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

(* ---------- vreg の読み書き(C-10) ----------
   src tmp v   : v を読むレジスタを返す。レジスタにいなければ tmp に持ってくる
   dst tmp v   : v に書くレジスタを返す。レジスタにいなければ tmp
   fin tmp v   : dst で tmp を返したとき、tmp をスロットへしまう
   src_into r v: v の値を、決まったレジスタ r に入れる(a0 など)
   to_vreg r v : 決まったレジスタ r の値を、v に入れる *)
let slot fr n = fr.slot_base + 4 * n

let src fr tmp v =
  match fr.loc v with
  | Regalloc.Reg r -> r
  | Regalloc.Slot n -> load tmp (slot fr n); tmp
  | Regalloc.Remat k -> Printf.bprintf buf "li %s, %ld\n" tmp k; tmp

let dst fr tmp v =
  match fr.loc v with
  | Regalloc.Reg r -> r
  | Regalloc.Slot _ | Regalloc.Remat _ -> tmp

let fin fr tmp v =
  match fr.loc v with
  | Regalloc.Slot n -> store tmp (slot fr n)
  | Regalloc.Reg _ | Regalloc.Remat _ -> ()   (* Remat は使うたびに作るので、しまわない *)

let src_into fr r v =
  match fr.loc v with
  | Regalloc.Reg r' -> if r' <> r then Printf.bprintf buf "mv %s, %s\n" r r'
  | Regalloc.Slot n -> load r (slot fr n)
  | Regalloc.Remat k -> Printf.bprintf buf "li %s, %ld\n" r k

let to_vreg fr r v =
  match fr.loc v with
  | Regalloc.Reg r' -> if r' <> r then Printf.bprintf buf "mv %s, %s\n" r' r
  | Regalloc.Slot n -> store r (slot fr n)
  | Regalloc.Remat _ -> ()

(*命令*)
let emit_instr (md : mode) (mrc : march) fr (i : instr) =
  let src = src fr and dst = dst fr and fin = fin fr
  and src_into = src_into fr and to_vreg = to_vreg fr in
  match i with
  | Const (d, n) ->
      (match fr.loc d with
       | Regalloc.Remat _ -> ()                    (* 使う場所で li する *)
       | _ ->
           let rd = dst "t0" d in
           Printf.bprintf buf "li %s, %ld\n" rd n;
           fin "t0" d)
  | Move (d, a) ->
      (match fr.loc d with
       | Regalloc.Reg rd -> src_into rd a          (* mv / lw / li を 1 つ *)
       | _ ->
           let ra = src "t0" a in
           to_vreg ra d)
  | Bin (op, d, a, b) ->
      let ra = src "t0" a in
      let rb = src "t1" b in
      let rd = dst "t0" d in
      let p fmt = Printf.bprintf buf fmt in
      (match op with
       | Add -> p "add %s, %s, %s\n" rd ra rb
       | Sub -> p "sub %s, %s, %s\n" rd ra rb
       | Mul -> p "mul %s, %s, %s\n" rd ra rb
       | QMul ->
          if md = Off then
            (p "mul t2, %s, %s\n" ra rb;          (*積の下位 32 ビット*)
             p "mulh t3, %s, %s\n" ra rb;         (*積の上位 32 ビット*)
             p "srli t2, t2, 16\n";
             p "slli t3, t3, 16\n";
             p "or %s, t2, t3\n" rd)
          else
            p "qmul %s, %s, %s\n" rd ra rb
       | Div -> p "div %s, %s, %s\n" rd ra rb
       | Rem -> p "rem %s, %s, %s\n" rd ra rb
       | Shl -> p "sll %s, %s, %s\n" rd ra rb
       | Sra -> p "sra %s, %s, %s\n" rd ra rb
       | And -> p "and %s, %s, %s\n" rd ra rb
       | Or  -> p "or %s, %s, %s\n" rd ra rb
       | Xor -> p "xor %s, %s, %s\n" rd ra rb
       | Eq  -> p "sub %s, %s, %s\nsltiu %s, %s, 1\n" rd ra rb rd rd   (*差が0なら1*)
       | Ne  -> p "sub %s, %s, %s\nsltu %s, x0, %s\n" rd ra rb rd rd   (*差が0でなければ1*)
       | Lt  -> p "slt %s, %s, %s\n" rd ra rb
       | Gt  -> p "slt %s, %s, %s\n" rd rb ra
       | Le  -> p "slt %s, %s, %s\nxori %s, %s, 1\n" rd rb ra rd rd   (*a <= b は !(b < a)*)
       | Ge  -> p "slt %s, %s, %s\nxori %s, %s, 1\n" rd ra rb rd rd); (*a >= b は !(a < b)*)
      fin "t0" d
  | Un (Neg, d, a) ->
      let ra = src "t0" a in
      let rd = dst "t0" d in
      Printf.bprintf buf "sub %s, x0, %s\n" rd ra;
      fin "t0" d
  | Un (Not, d, a) ->
      let ra = src "t0" a in
      let rd = dst "t0" d in
      Printf.bprintf buf "xori %s, %s, 1\n" rd ra; (*boolは0か1*)
      fin "t0" d
  | Intr (f, d, a) ->
      if md = Off then
        (src_into "a0" a;
         let name = match f with
           | Sqrt -> "__q16_sqrt" | Rsqrt -> "__q16_rsqrt" | Rcp -> "__q16_rcp" in
         Printf.bprintf buf "jal ra, %s\n" name;
         to_vreg "a0" d)
      else
        (let ra = src "t0" a in
         let rd = dst "t0" d in
         let cmd = match f with
           | Sqrt -> "qsqrt" | Rsqrt -> "qrsqrt" | Rcp -> "qrcp" in
         Printf.bprintf buf "%s %s, %s\n" cmd rd ra;
         fin "t0" d)
  | Zbb_b (op, d, a, b) ->
      if mrc = Im_zbb then
        (let ra = src "t0" a in
         let rb = src "t1" b in
         let rd = dst "t0" d in
         let cmd = match op with
           | Min -> "min" | Max -> "max" | Minu -> "minu" | Maxu -> "maxu"
           | Andn -> "andn" | Orn -> "orn" | Xnor -> "xnor" in
         Printf.bprintf buf "%s %s, %s, %s\n" cmd rd ra rb;
         fin "t0" d)
      else
        (src_into "a0" a;
         src_into "a1" b;
         let name = match op with
           | Min  -> "__min"
           | Max  -> "__max"
           | Minu -> "__minu"
           | Maxu -> "__maxu"
           | Andn -> "__andn"
           | Orn  -> "__orn"
           | Xnor -> "__xnor" in
         Printf.bprintf buf "jal ra, %s\n" name;
         to_vreg "a0" d)
  | Zbb_u (op, d, a) ->
      if mrc = Im_zbb then
        (let ra = src "t0" a in
         let rd = dst "t0" d in
         let cmd = match op with
           | Clz -> "clz" | Sext_b -> "sext.b" | Sext_h -> "sext.h" in
         Printf.bprintf buf "%s %s, %s\n" cmd rd ra;
         fin "t0" d)
      else
        (src_into "a0" a;
         let name = match op with
           | Clz -> "__clz"
           | Sext_b -> "__sext_b"
           | Sext_h -> "__sext_h" in
         Printf.bprintf buf "jal ra, %s\n" name;
         to_vreg "a0" d)
  | AddrLocal (d, id) ->
      let rd = dst "t0" d in
      add_sp rd (List.assoc id fr.arrays);
      fin "t0" d
  | AddrGlobal (d, name) ->
      let rd = dst "t0" d in
      Printf.bprintf buf "la %s, %s\n" rd name;
      fin "t0" d
  | Load (d, _, a, ofs) ->
      let ra = src "t0" a in (*アドレス*)
      let rd = dst "t0" d in
      load_from rd ra ofs;
      fin "t0" d
  | Store (_, a, ofs, v) ->
      let ra = src "t0" a in (*アドレス*)
      let rv = src "t1" v in (*書く値*)
      store_to rv ra ofs
  | Call (rs, name, args) ->
      (* 引数: 先頭8ワードはa0〜a7、残りはsp+0, sp+4,...
         (Call がある関数では a2〜a7 を割り当てないので、順に入れてよい) *)
      List.iteri (fun k v ->
        if k < 8 then src_into (Printf.sprintf "a%d" k) v
        else store (src "t0" v) (4 * (k - 8))) args;
      Printf.bprintf buf "jal ra, %s\n" name;
      (* 戻り値: 先頭8ワードはa0〜a7、残りはスタックから取得 *)
      List.iteri (fun k r ->
        if k < 8 then to_vreg (Printf.sprintf "a%d" k) r
        else begin
          let rd = dst "t0" r in
          load rd (4 * (k - 8));
          fin "t0" r
        end) rs
  | Bprint a ->
      let ra = src "t0" a in
      Printf.bprintf buf "li t1, 0x10000000\n"; (*UART*)
      Printf.bprintf buf "sb %s, 0(t1)\n" ra    (*下位 8 ビットを送る*)
  | Cycles d ->
      Printf.bprintf buf "li t1, 0x20000000\n"; (* cycle_lo *)
      let rd = dst "t0" d in
      Printf.bprintf buf "lw %s, 0(t1)\n" rd;
      fin "t0" d
  | Qabs (d, a) ->
      if mrc = Im_zbb then
        (let ra = src "t0" a in
         Printf.bprintf buf "neg t1, %s\n" ra;
         let rd = dst "t0" d in
         Printf.bprintf buf "max %s, t1, %s\n" rd ra;
         fin "t0" d)
      else
        (src_into "a0" a;
         Printf.bprintf buf "neg a1, a0\n";
         Printf.bprintf buf "jal ra, __max\n";
         to_vreg "a0" d)
(* emit_instr 内の Qclamp 以降を以下のように変更 *)
  | Qclamp (d, a, b, c) ->
      if mrc = Im_zbb then
        (let ra = src "t0" a in
         let rb = src "t1" b in
         let rc = src "t2" c in
         Printf.bprintf buf "max t0, %s, %s\n" ra rb;   (* 途中の値は t0 に置く(rd = rc でもこわれない) *)
         let rd = dst "t0" d in
         Printf.bprintf buf "min %s, t0, %s\n" rd rc;
         fin "t0" d)
      else
        (src_into "a0" a;
         src_into "a1" b;
         Printf.bprintf buf "jal ra, __max\n";
         src_into "a1" c;      (* __max は a0 しかこわさないので、c がレジスタにいても大丈夫 *)
         Printf.bprintf buf "jal ra, __min\n";
         to_vreg "a0" d)
  | AccelSetSphere (i, x, y, z, r, r2, m) ->
      if md <> Isect then failwith "accel_set_sphere requires --accel=isect";
      let ri = src "t0" i in
      Printf.bprintf buf "slli t0, %s, 5\n" ri;
      Printf.bprintf buf "li t1, 0x30000000\n";
      Printf.bprintf buf "add t1, t1, t0\n";
      Printf.bprintf buf "sw %s, 256(t1)\n" (src "t0" x);
      Printf.bprintf buf "sw %s, 260(t1)\n" (src "t0" y);
      Printf.bprintf buf "sw %s, 264(t1)\n" (src "t0" z);
      Printf.bprintf buf "sw %s, 268(t1)\n" (src "t0" r);
      Printf.bprintf buf "sw %s, 272(t1)\n" (src "t0" r2);
      Printf.bprintf buf "sw %s, 276(t1)\n" (src "t0" m)
  | AccelHit (d, ox, oy, oz, dx, dy, dz, tmin, tmax) ->
      if md <> Isect then failwith "accel_hit requires --accel=isect";
      Printf.bprintf buf "li t1, 0x30000000\n";
      Printf.bprintf buf "sw %s, 0(t1)\n"  (src "t0" ox);
      Printf.bprintf buf "sw %s, 4(t1)\n"  (src "t0" oy);
      Printf.bprintf buf "sw %s, 8(t1)\n"  (src "t0" oz);
      Printf.bprintf buf "sw %s, 12(t1)\n" (src "t0" dx);
      Printf.bprintf buf "sw %s, 16(t1)\n" (src "t0" dy);
      Printf.bprintf buf "sw %s, 20(t1)\n" (src "t0" dz);
      Printf.bprintf buf "sw %s, 24(t1)\n" (src "t0" tmin);
      Printf.bprintf buf "sw %s, 28(t1)\n" (src "t0" tmax);
      let rd = dst "t0" d in
      Printf.bprintf buf "lw %s, 32(t1)\n" rd;
      fin "t0" d
  | AccelT d ->
      if md <> Isect then failwith "accel_t requires --accel=isect";
      Printf.bprintf buf "li t1, 0x30000000\n";
      let rd = dst "t0" d in
      Printf.bprintf buf "lw %s, 36(t1)\n" rd;
      fin "t0" d
  | RngSeed a ->
      if md = Off then failwith "rng_seed requires --accel=math or --accel=isect";
      let ra = src "t0" a in
      Printf.bprintf buf "qseed x0, %s\n" ra
  | RandQ16 d ->
      if md = Off then failwith "rand_q16 requires --accel=math or --accel=isect";
      let rd = dst "t0" d in
      Printf.bprintf buf "qrand %s, x0\n" rd;
      fin "t0" d
  | RandQ16S d ->
      if md = Off then failwith "rand_q16_s requires --accel=math or --accel=isect";
      let rd = dst "t0" d in
      Printf.bprintf buf "qrands %s, x0\n" rd;
      fin "t0" d

(* s レジスタをしまう場所:[ベースレジスタ s1..sN | 割り当てで使った s] *)
let saved_regs fr =
  List.init fr.nbases (fun k -> Printf.sprintf "s%d" (k + 1)) @ fr.saved

(*終端*)
(*ブロックのラベルは .L_関数名_番号*)
let emit_term (f : func) fr (t : terminator) =
  match t with
  | Jump l ->
      Printf.bprintf buf "j .L_%s_%d\n" f.name l
  | Branch (c, lt, lf) ->
      let rc = src fr "t0" c in
      Printf.bprintf buf "bnez %s, .L_%s_%d\n" rc f.name lt;   (*真(0以外)ならlt*)
      Printf.bprintf buf "j .L_%s_%d\n" f.name lf              (*偽ならlf*)
  | Ret vs ->
      (* 戻り値: 先頭8ワードはa0〜a7、残りは呼び出し側のスタックへ
         (戻り値が 3 つ以上の関数では a2〜a7 を割り当てないので、順に入れてよい) *)
      List.iteri (fun k v ->
        if k < 8 then src_into fr (Printf.sprintf "a%d" k) v
        else store (src fr "t0" v) (fr.size + 4 * (k - 8))) vs;
      load "ra" fr.ra_off;
      (* s レジスタを、呼び出し元の値にもどす *)
      List.iteri (fun k r ->
        Printf.bprintf buf "lw %s, %d(sp)\n" r (fr.out_bytes + 4 * k)) (saved_regs fr);
      move_sp fr.size;
      Printf.bprintf buf "jalr x0, ra, 0\n"

(*関数*)
let emit_func ~regalloc (md : mode) (mrc : march) (f : func) =
  let fr =
    if regalloc then make_frame_ra ~accel_off:(md = Off) ~zbb:(mrc = Im_zbb) f
    else make_frame f in
  Printf.bprintf buf "\n.globl %s\n" f.name;
  Printf.bprintf buf "%s:\n" f.name;
  (*入口:フレームを取って、raと引数をしまう*)
  move_sp (- fr.size);
  (* s レジスタをしまう。それから s<k> = sp + 4096k を作る *)
  List.iteri (fun k r ->
    Printf.bprintf buf "sw %s, %d(sp)\n" r (fr.out_bytes + 4 * k)) (saved_regs fr);
  for k = 1 to fr.nbases do
    Printf.bprintf buf "li t6, %d\nadd s%d, sp, t6\n" (4096 * k) k
  done;
  nbases := fr.nbases;
  store "ra" fr.ra_off;
  List.iteri (fun k p ->
    if k < 8 then                                       (*先頭の8つはa0〜a7*)
      to_vreg fr (Printf.sprintf "a%d" k) p
    else begin                                          (* 残りは呼び出し側のフレームのsp+F+4k*)
      let rd = dst fr "t0" p in
      load rd (fr.size + 4 * (k - 8));
      fin fr "t0" p
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

let emit_program ?(regalloc = false) (md : mode) (mrc : march) (p : program) : string =
  Buffer.clear buf;
  Printf.bprintf buf ".section .text\n";

  List.iter (emit_func ~regalloc md mrc) p.funcs;
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
