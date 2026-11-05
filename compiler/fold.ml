(*定数畳み込み*)
open Ir

let b2i b = if b then 1l else 0l (*true → 1、false → 0*)

(* 二項演算の答え*)
let eval_bin op (a : int32) (b : int32) : int32 =
  match op with
  | Add -> Int32.add a b
  | Sub -> Int32.sub a b
  | Mul -> Int32.mul a b
  | QMul ->
      let p = Int64.mul (Int64.of_int32 a) (Int64.of_int32 b) in
      Int64.to_int32 (Int64.shift_right p 16)
  | Div ->
      if b = 0l then -1l
      else if a = Int32.min_int && b = -1l then Int32.min_int
      else Int32.div a b
  | Rem ->
      if b = 0l then a
      else if a = Int32.min_int && b = -1l then 0l
      else Int32.rem a b
  | Shl -> Int32.shift_left a (Int32.to_int b land 31)
  | Sra -> Int32.shift_right a (Int32.to_int b land 31)
  | And -> Int32.logand a b
  | Or  -> Int32.logor a b
  | Xor -> Int32.logxor a b
  | Eq  -> b2i (a = b)
  | Ne  -> b2i (a <> b)
  | Lt  -> b2i (Int32.compare a b < 0)
  | Le  -> b2i (Int32.compare a b <= 0)
  | Gt  -> b2i (Int32.compare a b > 0)
  | Ge  -> b2i (Int32.compare a b >= 0)

(* 単項演算の答え *)
let eval_un op (a : int32) : int32 =
  match op with
  | Neg -> Int32.neg a (*0-a*)
  | Not -> Int32.logxor a 1l (*boolの反転(0↔1)*)

(*命令iが読むvregをfで置きかえる(書くvregはそのまま)*)
let subst_uses f (i : instr) : instr =
  match i with
  | Const _ | AddrLocal _ | AddrGlobal _ | Cycles _ -> i
  | Move (d, a) -> Move (d, f a)
  | Bin (op, d, a, b) -> Bin (op, d, f a, f b)
  | Un (op, d, a) -> Un (op, d, f a)
  | Intr (k, d, a) -> Intr (k, d, f a)
  | Zbb_b (op, d, a, b) -> Zbb_b (op, d, f a, f b)          
  | Zbb_u (op, d, a) -> Zbb_u (op, d, f a)                  
  | Qabs (d, a) -> Qabs (d, f a)                            
  | Qclamp (d, a, b, c) -> Qclamp (d, f a, f b, f c)  
  | Load (d, r, a, o) -> Load (d, r, f a, o)
  | Store (id, a, o, s) -> Store (id, f a, o, f s)
  | Call (rs, n, args) -> Call (rs, n, List.map f args)
  | Bprint a -> Bprint (f a)

let fold_block (b : block) : block = 
  let known = Hashtbl.create 16 in (*vreg番号→値をメモ*)
  let value v = Hashtbl.find_opt known v in (*vの中身の値*)
  let forget i = List.iter (fun d -> Hashtbl.remove known d) (defs i) in (*命令がconstでなければ、その命令が書き込むvregをメモから消す*)
  let copies = Hashtbl.create 16 in                  (* vreg -> そのコピー元 *)
  let root v = Option.value ~default:v (Hashtbl.find_opt copies v) in
  let kill d =                                       (* d が書きかわったら、d に関係するコピーを忘れる *)
    Hashtbl.remove copies d;
    let ks = Hashtbl.fold (fun k s acc -> if s = d then k :: acc else acc) copies [] in
    List.iter (Hashtbl.remove copies) ks in

  let body = List.map (fun i -> 
    let i = subst_uses root i in
    let i' = match i with
    | Move (d, a) -> 
      (match value a with
      (*aの中身が定数nだとわかっているかで分岐*)
      | Some n -> Const (d, n) 
      | None -> i)
    | Bin (op, d, a, c) ->
      (match value a, value c with
      | Some x, Some y -> Const (d, eval_bin op x y)
      | _ -> i)
    | Un (op, d, a) -> 
      (match value a with
      | Some x -> Const (d, eval_un op x)
      | None -> i)
    | _ -> i
  in
  (match i' with
  | Const (d, n) -> Hashtbl.replace known d n (*メモを更新*)
  | _ -> forget i'); (*メモから消す*)
  List.iter kill (defs i');
  (match i' with
   | Move (d, s) when d <> s -> Hashtbl.replace copies d s
   | _ -> ());
  i'
) b.body in
  let term = match b.term with
    | Branch (c, t, f) -> 
      let c = root c in
        (match value c with
        | Some n -> Jump (if n <> 0l then t else f)
        | None -> b.term)
    | Ret vs -> Ret (List.map root vs)
    | other -> other
  in
{b with body; term}

let run (p : program) : program =
  { p with funcs = List.map (fun f -> { f with blocks = List.map fold_block f.blocks }) p.funcs }