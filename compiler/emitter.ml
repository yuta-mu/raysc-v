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
  imm : bool;                    (* 定数のシフト量をslli/srai の即値にする *)
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
let layout ?(imm = false) (f : func) ~out_bytes ~nbases ~saved ~nslots ~loc =
  let slot_base = out_bytes + 4 * nbases + 4 * List.length saved in
  let arr_base = slot_base + 4 * nslots in
  let arrays, arr_end =
    List.fold_left
      (fun (acc, off) (id, bytes) -> ((id, off) :: acc, off + bytes))
      ([], arr_base) f.arrays
  in
  let size = arr_end + 4 in
  { out_bytes; arrays; ra_off = size - 4; size; nbases; saved; slot_base; loc; imm }

(*割り当てなし:関数の中に出てくる vreg に、出てきた順に 0, 1, 2, ... のスロットを割り当てる*)
let make_frame (f : func) =
  let out_bytes = outgoing_bytes f in
  let slot_of = Hashtbl.create 256 in
  let add v = if not (Hashtbl.mem slot_of v) then Hashtbl.replace slot_of v (Hashtbl.length slot_of) in
  List.iter add f.params;
  List.iter (fun b ->
    List.iter (fun i -> List.iter add (defs i); List.iter add (uses i)) b.body;
    List.iter add (term_uses b.term)) f.blocks;
  let nslots = Hashtbl.length slot_of in
  let rough = out_bytes + 4 * 11 + 4 * nslots + array_bytes f + 4 in
  layout f ~out_bytes ~nbases:(bases_for rough) ~saved:[] ~nslots
    ~loc:(fun v ->
      match Hashtbl.find_opt slot_of v with
      | Some n -> Regalloc.Slot n
      | None -> failwith (Printf.sprintf "make_frame: v%d has no slot in %s" v f.name))

(* 割り当てあり:Regalloc の結果で置き場所を決める。
   フレームが大きくてベースレジスタが要るときは、その s を外して割り当てをやり直す *)
let make_frame_ra ?(imm = false) ~accel_off ~zbb (f : func) =
  let out_bytes = outgoing_bytes f in
  let rec go nb =
    let reserved = List.init nb (fun k -> Printf.sprintf "s%d" (k + 1)) in
    let (locs, nslots, used) = Regalloc.allocate ~reserved ~imm_shift:imm ~accel_off ~zbb f in
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
  layout ~imm f ~out_bytes ~nbases ~saved ~nslots ~loc

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

(* -O3:MMIO(cycles / accel)の前後に「# mmio」の行を出して、並べかえ(schedule.ml)の壁にする *)
let mmio_marks = ref false
let mmio_mark () = if !mmio_marks then Printf.bprintf buf "# mmio\n"

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
  | Bin ((Shl | Sra) as op, d, a, b)
    when fr.imm && (match fr.loc b with Regalloc.Remat k -> 0l <= k && k <= 31l | _ -> false) ->
      (* シフト量が定数:slli / srai の即値にする(-O3) *)
      let k = match fr.loc b with Regalloc.Remat k -> k | _ -> assert false in
      let ra = src "t0" a in
      let rd = dst "t0" d in
      Printf.bprintf buf "%s %s, %s, %ld\n" (if op = Shl then "slli" else "srai") rd ra k;
      fin "t0" d
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
      mmio_mark ();
      Printf.bprintf buf "li t1, 0x20000000\n"; (* cycle_lo *)
      let rd = dst "t0" d in
      Printf.bprintf buf "lw %s, 0(t1)\n" rd;
      fin "t0" d;
      mmio_mark ()
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
      mmio_mark ();
      let ri = src "t0" i in
      Printf.bprintf buf "slli t0, %s, 5\n" ri;
      Printf.bprintf buf "li t1, 0x30000000\n";
      Printf.bprintf buf "add t1, t1, t0\n";
      Printf.bprintf buf "sw %s, 256(t1)\n" (src "t0" x);
      Printf.bprintf buf "sw %s, 260(t1)\n" (src "t0" y);
      Printf.bprintf buf "sw %s, 264(t1)\n" (src "t0" z);
      Printf.bprintf buf "sw %s, 268(t1)\n" (src "t0" r);
      Printf.bprintf buf "sw %s, 272(t1)\n" (src "t0" r2);
      Printf.bprintf buf "sw %s, 276(t1)\n" (src "t0" m);
      mmio_mark ()
  | AccelHit (d, ox, oy, oz, dx, dy, dz, tmin, tmax) ->
      if md <> Isect then failwith "accel_hit requires --accel=isect";
      mmio_mark ();
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
      fin "t0" d;
      mmio_mark ()
  | AccelT d ->
      if md <> Isect then failwith "accel_t requires --accel=isect";
      mmio_mark ();
      Printf.bprintf buf "li t1, 0x30000000\n";
      let rd = dst "t0" d in
      Printf.bprintf buf "lw %s, 36(t1)\n" rd;
      fin "t0" d;
      mmio_mark ()
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

let negate = function
  | "beqz" -> Some "bnez" | "bnez" -> Some "beqz"
  | "beq" -> Some "bne" | "bne" -> Some "beq"
  | "blt" -> Some "bge" | "bge" -> Some "blt"
  | "bltu" -> Some "bgeu" | "bgeu" -> Some "bltu"
  | "bgt" -> Some "ble" | "ble" -> Some "bgt"
  | "bgtu" -> Some "bleu" | "bleu" -> Some "bgtu"
  | "bltz" -> Some "bgez" | "bgez" -> Some "bltz"
  | "blez" -> Some "bgtz" | "bgtz" -> Some "blez"
  | _ -> None

(*終端*)
(*ブロックのラベルは .L_関数名_番号*)
(* 条件分岐を出す。tru は「真のとき飛ぶ」命令(飛び先の手前まで)、fls は「偽のとき飛ぶ」命令
   例:tru = "bnez a5"、fls = "beqz a5" / tru = "blt a5, a6"、fls = "bge a5, a6" *)
let emit_cond ~next (f : func) tru fls lt lf =
  let lbl l = Printf.sprintf ".L_%s_%d" f.name l in
  if next = Some lt then
    Printf.bprintf buf "%s, %s\n" fls (lbl lf)            (*真はすぐ下へ落ちる*)
  else if next = Some lf then
    Printf.bprintf buf "%s, %s\n" tru (lbl lt)            (*偽はすぐ下へ落ちる*)
  else begin
    Printf.bprintf buf "%s, %s\n" tru (lbl lt);           (*真なら lt*)
    Printf.bprintf buf "j %s\n" (lbl lf)                  (*偽なら lf*)
  end

let emit_term ~next (f : func) fr (t : terminator) =
  let lbl l = Printf.sprintf ".L_%s_%d" f.name l in
  match t with
  | Jump l ->
      if next <> Some l then Printf.bprintf buf "j %s\n" (lbl l)   (*すぐ下なら出さない*)
  | Branch (c, lt, lf) ->
      let rc = src fr "t0" c in
      emit_cond ~next f ("bnez " ^ rc) ("beqz " ^ rc) lt lf
  | Ret vs ->
      (* 戻り値: 先頭8ワードはa0〜a7、残りは呼び出し側のスタックへ
         (戻り値が 3 つ以上の関数では a2〜a7 を割り当てないので、順に入れてよい) *)
      List.iteri (fun k v ->
        if k < 8 then src_into fr (Printf.sprintf "a%d" k) v
        else store (src fr "t0" v) (fr.size + 4 * (k - 8))) vs;
      load "ra" fr.ra_off;
      (* s レジスタを、呼び出し元の値にもどす *)
      List.iteri (fun k r ->
        load_from r "sp" (fr.out_bytes + 4 * k)) (saved_regs fr);
      move_sp fr.size;
      Printf.bprintf buf "jalr x0, ra, 0\n"

(* -O3:比較と分岐をまとめる
   ブロックの最後が c = a < b などの比較で、終端が Branch (c, ...)、
   c がその分岐でしか使われないなら、比較の命令は出さずに blt a, b などで直接分岐する *)
let use_counts (f : func) =
  let h = Hashtbl.create 256 in
  let add v = Hashtbl.replace h v (1 + Option.value ~default:0 (Hashtbl.find_opt h v)) in
  List.iter (fun b ->
    List.iter (fun i -> List.iter add (uses i)) b.body;
    List.iter add (term_uses b.term)) f.blocks;
  h

(* 比較 op の a, b について、(真のとき飛ぶ命令, 1 つ目, 2 つ目) *)
let branch_of op a b =
  match op with
  | Lt -> Some ("blt", a, b)          (* a < b *)
  | Gt -> Some ("blt", b, a)          (* a > b は b < a *)
  | Le -> Some ("bge", b, a)          (* a <= b は b >= a *)
  | Ge -> Some ("bge", a, b)          (* a >= b *)
  | Eq -> Some ("beq", a, b)
  | Ne -> Some ("bne", a, b)
  | _ -> None

(* まとめられるなら Some (比較をのぞいた本体, 真の命令名, a, b) *)
let fusable counts (b : block) =
  match b.term, List.rev b.body with
  | Branch (c, _, _), Bin (op, d, x, y) :: rest_rev
    when d = c && Hashtbl.find_opt counts c = Some 1 ->
      (match branch_of op x y with
       | Some (bop, r1, r2) -> Some (List.rev rest_rev, bop, r1, r2)
       | None -> None)
  | _ -> None

(*関数*)
let emit_func ~regalloc ~opt3 (md : mode) (mrc : march) (f : func) =
  let fr =
    if regalloc then make_frame_ra ~imm:opt3 ~accel_off:(md = Off) ~zbb:(mrc = Im_zbb) f
    else make_frame f in
  Printf.bprintf buf "\n.globl %s\n" f.name;
  Printf.bprintf buf "%s:\n" f.name;
  (*入口:フレームを取って、raと引数をしまう*)
  move_sp (- fr.size);
  (* s レジスタをしまう。それから s<k> = sp + 4096k を作る *)
  List.iteri (fun k r ->
    store_to r "sp" (fr.out_bytes + 4 * k)) (saved_regs fr);
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
  let counts = use_counts f in
  let rec go = function
    | [] -> ()
    | b :: rest ->
        Printf.bprintf buf ".L_%s_%d:\n" f.name b.label;
        (* -O3:すぐ下のブロックのラベル(フォールスルー化に使う) *)
        let next = match rest with nb :: _ when opt3 -> Some nb.label | _ -> None in
        (match (if opt3 then fusable counts b else None), b.term with
         | Some (body, bop, x, y), Branch (_, lt, lf) ->
             (* 比較と分岐をまとめる:比較の命令は出さない *)
             List.iter (emit_instr md mrc fr) body;
             let rx = src fr "t0" x in
             let ry = src fr "t1" y in
             let neg = Option.get (negate bop) in
             emit_cond ~next f (Printf.sprintf "%s %s, %s" bop rx ry)
               (Printf.sprintf "%s %s, %s" neg rx ry) lt lf
         | _ ->
             List.iter (emit_instr md mrc fr) b.body;
             emit_term ~next f fr b.term);
        go rest in
  go f.blocks

(*c-7*)
let runtime_math_to_i = {|
|}

let runtime_math_to_m = {|
.globl __q16_sqrt
__q16_sqrt:
blez a0, .L_sqrt_zero
srai a1, a0, 16
slli t6, a0, 16
li t1, 0
beqz a1, .L_sqrt_small_init
srli t2, a1, 8
li t0, 0x00080000
beqz t2, .L_sqrt_loop
li t0, 0x00800000
.L_sqrt_loop:
or t3, t1, t0
mul t4, t3, t3
mulh t5, t3, t3
blt t5, a1, .L_sqrt_accept
bgt t5, a1, .L_sqrt_next
bltu t6, t4, .L_sqrt_next
.L_sqrt_accept:
mv t1, t3
.L_sqrt_next:
srli t0, t0, 1
bnez t0, .L_sqrt_loop
mv a0, t1
jalr x0, ra, 0
.L_sqrt_small_init:
li t0, 0x00008000
.L_sqrt_small_loop:
or t3, t1, t0
mul t4, t3, t3
bltu t6, t4, .L_sqrt_small_next
mv t1, t3
.L_sqrt_small_next:
srli t0, t0, 1
bnez t0, .L_sqrt_small_loop
mv a0, t1
jalr x0, ra, 0
.L_sqrt_zero:
li a0, 0
jalr x0, ra, 0

.globl __q16_rsqrt
__q16_rsqrt:
blez a0, .L_rsqrt_zero
srli t0, a0, 16
lui t1, 0x10
bnez t0, .L_rsqrt_init
srli t0, a0, 8
lui t1, 0x100
bnez t0, .L_rsqrt_init
lui t1, 0x1000
.L_rsqrt_init:
mv a1, a0
li a0, 0
lui t2, 0x10
.L_rsqrt_loop:
or t3, a0, t1
mul t4, t3, t3
mulhu t5, t3, t3
mulhu t6, t4, a1
mulhu a2, t5, a1
mul t5, t5, a1
add t5, t5, t6
sltu t6, t5, t6
add t6, a2, t6
bnez t6, .L_rsqrt_branch
bgeu t5, t2, .L_rsqrt_branch
.L_rsqrt_store:
mv a0, t3
.L_rsqrt_next:
srli t1, t1, 1
bnez t1, .L_rsqrt_loop
jalr x0, ra, 0
.L_rsqrt_branch:
bne t5, t2, .L_rsqrt_next
bnez t6, .L_rsqrt_next
mul t4, t4, a1
beqz t4, .L_rsqrt_store
j .L_rsqrt_next
.L_rsqrt_zero:
li a0, 0
jalr x0, ra, 0

.globl __q16_rcp
__q16_rcp:
beqz a0, .L_rcp_max
bltz a0, .L_rcp_neg
li t0, 2
bgeu t0, a0, .L_rcp_max
neg t1, a0
divu a0, t1, a0
addi a0, a0, 1
jalr x0, ra, 0
.L_rcp_neg:
neg t1, a0
li t0, 2
lui a0, 0x80000
bgeu t0, t1, .L_rcp_ret
li a0, -1
divu a0, a0, t1
not a0, a0
jalr x0, ra, 0
.L_rcp_max:
lui a0, 0x80000
addi a0, a0, -1
.L_rcp_ret:
jalr x0, ra, 0
|}

let runtime_math_to_zbb = {|
.globl __q16_sqrt
__q16_sqrt:
blez a0, .L_sqrt_zero
clz t0, a0
srli t0, t0, 1
li t2, 23
sub t2, t2, t0
li t0, 1
sll t0, t0, t2
srai a1, a0, 16
slli t6, a0, 16
li t1, 0
beqz a1, .L_sqrt_small
.L_sqrt_loop:
or t3, t1, t0
mul t4, t3, t3
mulh t5, t3, t3
blt t5, a1, .L_sqrt_accept
bgt t5, a1, .L_sqrt_next
bltu t6, t4, .L_sqrt_next
.L_sqrt_accept:
mv t1, t3
.L_sqrt_next:
srli t0, t0, 1
bnez t0, .L_sqrt_loop
mv a0, t1
jalr x0, ra, 0
.L_sqrt_small:
or t3, t1, t0
mul t4, t3, t3
bltu t6, t4, .L_sqrt_small_next
mv t1, t3
.L_sqrt_small_next:
srli t0, t0, 1
bnez t0, .L_sqrt_small
mv a0, t1
jalr x0, ra, 0
.L_sqrt_zero:
li a0, 0
jalr x0, ra, 0

.globl __q16_rsqrt
__q16_rsqrt:
blez a0, .L_rsqrt_zero
clz t0, a0
addi t0, t0, 17
srli t0, t0, 1
li t1, 1
sll t1, t1, t0
mv a1, a0
li a0, 0
lui t2, 0x10
.L_rsqrt_loop:
or t3, a0, t1
mul t4, t3, t3
mulhu t5, t3, t3
mulhu t6, t4, a1
mulhu a2, t5, a1
mul t5, t5, a1
add t5, t5, t6
sltu t6, t5, t6
add t6, a2, t6
bnez t6, .L_rsqrt_branch
bgeu t5, t2, .L_rsqrt_branch
.L_rsqrt_store:
mv a0, t3
.L_rsqrt_next:
srli t1, t1, 1
bnez t1, .L_rsqrt_loop
jalr x0, ra, 0
.L_rsqrt_branch:
bne t5, t2, .L_rsqrt_next
bnez t6, .L_rsqrt_next
mul t4, t4, a1
beqz t4, .L_rsqrt_store
j .L_rsqrt_next
.L_rsqrt_zero:
li a0, 0
jalr x0, ra, 0

.globl __q16_rcp
__q16_rcp:
beqz a0, .L_rcp_max
bltz a0, .L_rcp_neg
li t0, 2
bgeu t0, a0, .L_rcp_max
neg t1, a0
divu a0, t1, a0
addi a0, a0, 1
jalr x0, ra, 0
.L_rcp_neg:
neg t1, a0
li t0, 2
lui a0, 0x80000
bgeu t0, t1, .L_rcp_ret
li a0, -1
divu a0, a0, t1
not a0, a0
jalr x0, ra, 0
.L_rcp_max:
lui a0, 0x80000
addi a0, a0, -1
.L_rcp_ret:
jalr x0, ra, 0
|}

let runtime_m = {|
|}

let runtime_zbb = {|
.globl __min
__min:
blt a0, a1, .L_min_ret
mv a0, a1
.L_min_ret:
jalr x0, ra, 0

.globl __max
__max:
bge a0, a1, .L_max_ret
mv a0, a1
.L_max_ret:
jalr x0, ra, 0

.globl __minu
__minu:
bltu a0, a1, .L_minu_ret
mv a0, a1
.L_minu_ret:
jalr x0, ra, 0

.globl __maxu
__maxu:
bgeu a0, a1, .L_maxu_ret
mv a0, a1
.L_maxu_ret:
jalr x0, ra, 0

.globl __andn
__andn:
not a1, a1
and a0, a0, a1
jalr x0, ra, 0

.globl __orn
__orn:
not a1, a1
or a0, a0, a1
jalr x0, ra, 0

.globl __xnor
__xnor:
xor a0, a0, a1
not a0, a0
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
beqz a0, .L_clz_zero
li t0, 0
srli t1, a0, 16
bnez t1, .L_clz_8
addi t0, t0, 16
slli a0, a0, 16
.L_clz_8:
srli t1, a0, 24
bnez t1, .L_clz_4
addi t0, t0, 8
slli a0, a0, 8
.L_clz_4:
srli t1, a0, 28
bnez t1, .L_clz_2
addi t0, t0, 4
slli a0, a0, 4
.L_clz_2:
srli t1, a0, 30
bnez t1, .L_clz_1
addi t0, t0, 2
slli a0, a0, 2
.L_clz_1:
bltz a0, .L_clz_done
addi t0, t0, 1
.L_clz_done:
mv a0, t0
jalr x0, ra, 0
.L_clz_zero:
li a0, 32
jalr x0, ra, 0
|}

(*遠すぎる条件分岐を直す
   条件分岐(beqz など)は ±4KB までしか飛べない。フォールスルー化で j が消えると、
   遠いブロックへ条件分岐で飛ぶことがあるので、そういう分岐だけ
     beqz a5, .L_far   ->   bnez a5, .L_rx_N
                            j .L_far
                          .L_rx_N:
   に書きかえる(j は ±1MB まで届く)。*)

(* 1 行を (命令名, 飛び先より前のオペランド, 飛び先) に分ける。条件分岐でなければ None *)
let split_branch line =
  let s = String.trim line in
  match String.index_opt s ' ' with
  | None -> None
  | Some k ->
      let op = String.sub s 0 k in
      if negate op = None then None
      else
        let rest = String.sub s (k + 1) (String.length s - k - 1) in
        match String.rindex_opt rest ',' with
        | None -> None
        | Some c ->
            let regs = String.sub rest 0 c in
            let target = String.trim (String.sub rest (c + 1) (String.length rest - c - 1)) in
            Some (op, regs, target)

let size_of line =
  let s = String.trim line in
  if s = "" || s.[0] = '.' || s.[0] = '#' || s.[String.length s - 1] = ':' then 0
  else
    let op = match String.index_opt s ' ' with Some k -> String.sub s 0 k | None -> s in
    if op = "li" || op = "la" || op = "call" || op = "tail" then 8 else 4

let relax_count = ref 0

let relax (text : string) : string =
  let limit = 4000 in                                  (* ±4096 より少し内側 *)
  let rec pass lines =
    (* ラベルの位置(見積もり) *)
    let pos = Hashtbl.create 256 in
    let _ = List.fold_left (fun p l ->
      let s = String.trim l in
      if s <> "" && s.[String.length s - 1] = ':' then        (* ラベル *)
        Hashtbl.replace pos (String.sub s 0 (String.length s - 1)) p;
      p + size_of l) 0 lines in
    let changed = ref false in
    let _, out = List.fold_left (fun (p, acc) l ->
      let here = p in
      match split_branch l with
      | Some (op, regs, target) when
          (match Hashtbl.find_opt pos target with
           | Some t -> abs (t - here) > limit
           | None -> false) ->
          changed := true;
          incr relax_count;
          let skip = Printf.sprintf ".L_rx_%d" !relax_count in
          let neg = Option.get (negate op) in
          (p + 8, (skip ^ ":") :: ("j " ^ target) :: (Printf.sprintf "%s %s, %s" neg regs skip) :: acc)
      | _ -> (p + size_of l, l :: acc)) (0, []) lines in
    let out = List.rev out in
    if !changed then pass out else out in
  let lines = String.split_on_char '\n' text in
  String.concat "\n" (pass lines)

let emit_program ?(regalloc = false) ?(opt3 = false) (md : mode) (mrc : march) (p : program) : string =
  Buffer.clear buf;
  mmio_marks := opt3;
  relax_count := 0;
  Printf.bprintf buf ".section .text\n";

  List.iter (emit_func ~regalloc ~opt3 md mrc) p.funcs;
  (*ロード使用ハザードを避けるように並べかえる(runtime対象外)*)
  if opt3 then begin
    let s = Buffer.contents buf in
    Buffer.clear buf;
    Buffer.add_string buf (Schedule.run s)
  end;
  (*遠すぎる条件分岐を直す*)
  (let s = Buffer.contents buf in
   Buffer.clear buf;
   Buffer.add_string buf (relax s));                                                                                      
  ();
  (match mrc with
    | I -> (if md = Off then Buffer.add_string buf runtime_math_to_i;
            Buffer.add_string buf runtime_m;
            Buffer.add_string buf runtime_zbb)
    | Im -> (if md = Off then Buffer.add_string buf runtime_math_to_m;
            Buffer.add_string buf runtime_zbb)
    | Im_zbb -> if md = Off then Buffer.add_string buf runtime_math_to_zbb);
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
