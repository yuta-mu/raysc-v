(*定数畳み込み*)
open Ir
open Numeric

(* 二項演算の答え*)
let eval_bin op (a : int32) (b : int32) : int32 =
  match op with
  | Add  -> add a b
  | Sub  -> sub a b
  | Xor  -> logxor a b
  | Or   -> logor a b
  | And  -> logand a b
  | Sll  -> sll a b
  | Srl  -> srl a b
  | Sra  -> sra a b
  | Slt  -> slt a b
  | Sltu -> sltu a b
  | Eq   -> eq a b
  | Ne   -> ne a b
  | Lt   -> lt a b
  | Le   -> le a b
  | Gt   -> gt a b
  | Ge   -> ge a b
  | Ltu  -> ltu a b
  | Leu  -> leu a b
  | Gtu  -> gtu a b
  | Geu  -> geu a b
  | Mul  -> mul a b
  | Mulh -> mulh a b
  | Mulhsu -> mulhsu a b
  | Mulhu -> mulhu a b
  | Div  -> div a b
  | Divu -> divu a b
  | Rem  -> rem a b
  | Remu -> remu a b
  | Andn -> andn a b
  | Orn  -> orn a b
  | Xnor -> xnor a b
  | Max  -> max a b
  | Maxu -> maxu a b
  | Min  -> min a b
  | Minu -> minu a b
  | QMul -> qmul a b

(* 単項演算の答え *)
let eval_un op (a : int32) : int32 =
  match op with
  | Neg    -> neg a
  | Not    -> lognot a
  | Clz    -> clz a
  | Sext_b -> sext_b a
  | Sext_h -> sext_h a
  | QSqrt  -> qsqrt a
  | QRsqrt -> qrsqrt a
  | QRcp   -> qrcp a

(*命令iが読むvregをfで置きかえる(書くvregはそのまま)*)
let subst_uses f (i : instr) : instr =
  match i with
  | Const _ | AddrLocal _ | AddrGlobal _ | Supplier _ -> i
  | Move (d, a) -> Move (d, f a)
  | Bin (op, d, a, b) -> Bin (op, d, f a, f b)
  | Un (op, d, a) -> Un (op, d, f a)
  | Load (d, r, a, o) -> Load (d, r, f a, o)
  | Store (id, a, o, s) -> Store (id, f a, o, f s)
  | Call (rs, n, args) -> Call (rs, n, List.map f args)
  | Consumer (op, a) -> Consumer (op, f a)
  | AccelSetSphere (i, x, y, z, r, r2, m) ->
      AccelSetSphere (f i, f x, f y, f z, f r, f r2, f m)
  | AccelHit (d, ox, oy, oz, dx, dy, dz, tmin, tmax) ->
      AccelHit (d, f ox, f oy, f oz, f dx, f dy, f dz, f tmin, f tmax)

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