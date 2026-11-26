open Ir

(*計算の中身*)
type key =
  | KBin of binop * vreg * vreg
  | KUn of unop * vreg
  | KIntr of intrinsic * vreg
  | KZbb_b of zbb_binop * vreg * vreg
  | KZbb_u of zbb_unop * vreg
  | KQabs of vreg
  | KQclamp of vreg * vreg * vreg
  | KAddrLocal of int
  | KAddrGlobal of string
  | KLoad of region * vreg * int

(*入力を入れかえても答えが同じ計算*)
let commutative_bin = function
  | Add | Mul | QMul | And | Or | Xor | Eq | Ne -> true
  | _ -> false

let commutative_zbb = function
  | Min | Max | Minu | Maxu | Xnor -> true
  | Andn | Orn -> false

(*入れかえてよいなら、小さい番号を先にそろえる*)
let order comm a b = if comm && b < a then (b, a) else (a, b)

(*命令iの計算の中身と、結果のvreg。表に入れない命令はNone*)
let key_of (i : instr) =
  match i with
  | Bin (op, d, a, b) -> let (a, b) = order (commutative_bin op) a b in Some (KBin (op, a, b), d)
  | Un (op, d, a) -> Some (KUn (op, a), d)
  | Intr (f, d, a) -> Some (KIntr (f, a), d)
  | Zbb_b (op, d, a, b) -> let (a, b) = order (commutative_zbb op) a b in Some (KZbb_b (op, a, b), d)
  | Zbb_u (op, d, a) -> Some (KZbb_u (op, a), d)
  | Qabs (d, a) -> Some (KQabs a, d)
  | Qclamp (d, a, b, c) -> Some (KQclamp (a, b, c), d)
  | AddrLocal (d, id) -> Some (KAddrLocal id, d)
  | AddrGlobal (d, s) -> Some (KAddrGlobal s, d)
  | Load (d, r, a, o) -> Some (KLoad (r, a, o), d)
  | _ -> None   (* Const は Remat があるので入れない。副作用のある命令も入れない *)

(*計算の中身が読むvreg*)
let operands = function
  | KBin (_, a, b) | KZbb_b (_, a, b) -> [a; b]
  | KUn (_, a) | KIntr (_, a) | KZbb_u (_, a) | KQabs a | KLoad (_, a, _) -> [a]
  | KQclamp (a, b, c) -> [a; b; c]
  | KAddrLocal _ | KAddrGlobal _ -> []

let is_local_load = function KLoad (Local _, _, _) -> true | _ -> false

let cse_block (b : block) : block =
  let table : (key, vreg) Hashtbl.t = Hashtbl.create 32 in
  let drop p =                                  (* 条件 p に合う行を表から消す *)
    let ks = Hashtbl.fold (fun k r acc -> if p k r then k :: acc else acc) table [] in
    List.iter (Hashtbl.remove table) ks in
  (* d が書きかわった:d を読む行と、結果が d の行を消す *)
  let killed d = drop (fun k r -> r = d || List.mem d (operands k)) in
  let body = List.map (fun i ->
    let i' =
      match key_of i with
      | Some (k, d) ->
          (match Hashtbl.find_opt table k with
           | Some r when r <> d -> Move (d, r)          (* 同じ計算がある:コピーにする *)
           | Some _ -> i
           | None -> i)
      | None -> i in
    (* 書いた vreg に関係する行を消す *)
    List.iter killed (defs i');
    (* 配列に書く命令のあとは、その配列の Load を忘れる *)
    (match i' with
     | Store (id, _, _, _) -> drop (fun k _ -> match k with KLoad (Local id', _, _) -> id' = id | _ -> false)
     | Call _ -> drop (fun k _ -> is_local_load k)
     | _ -> ());
    (* 新しく計算したものを表に書く(結果が入力を上書きする命令はのぞく) *)
    (match i', key_of i with
     | (Move _, _) -> ()
     | (_, Some (k, d)) when not (List.mem d (operands k)) && not (Hashtbl.mem table k) ->
         Hashtbl.replace table k d
     | _ -> ());
    i') b.body in
  { b with body }

let run (p : program) : program =
  { p with funcs = List.map (fun f -> { f with blocks = List.map cse_block f.blocks }) p.funcs }