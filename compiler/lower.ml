open Ir

(* ターゲット定義 *)
type accel = Off | Math | Rand | Isect
type march = I | Im | Im_zbb

type target = {
  accel : accel;
  march : march;
}

(* 1 命令 -> 複数命令 への変換をプログラム全体に適用する *)
let apply_pass (f : instr -> instr list) (p : program) : program =
  let map_block b =
    let body = List.concat (List.map f b.body) in
    { b with body }
  in
  let map_func fn =
    { fn with blocks = List.map map_block fn.blocks }
  in
  { p with funcs = List.map map_func p.funcs }

(* Math / 乱数 / アクセラレータ命令 の変換 *)
let lower_math_instr (t : target) (i : instr) : instr list =
  match i with
  (* 変換できない命令のチェック *)
  | AccelSetSphere _ when t.accel <> Isect ->
      failwith "accel_set_sphere requires --accel=isect"
  | AccelHit _ when t.accel <> Isect ->
      failwith "accel_hit requires --accel=isect"
  | Supplier (AccelT, _) when t.accel <> Isect ->
      failwith "accel_t requires --accel=isect"
  | Consumer (Qseed, _) | Supplier ((Qrand | Qrands), _) when t.accel <> Isect && t.accel <> Rand ->
      failwith "qseed/qrand/qrands require --accel=rand or --accel=isect"

  (* Off : ハードウェア命令を標準ライブラリの関数呼び出しに変換 *)
  | Bin (QMul, d, a, b) when t.accel = Off ->
      [Call ([d], "__qmul", [a; b])]
  | Un (QSqrt, d, a) when t.accel = Off ->
      [Call ([d], "sqrt", [a])]
  | Un (QRsqrt, d, a) when t.accel = Off ->
      [Call ([d], "rsqrt", [a])]
  | Un (QRcp, d, a) when t.accel = Off ->
      [Call ([d], "rcp", [a])]

  (* Math / Rand / Isect : 標準ライブラリの関数呼び出しをハードウェア命令に変換 *)
  | Call ([d], "sqrt", [a]) when t.accel <> Off ->
      [Un (QSqrt, d, a)]
  | Call ([d], "rsqrt", [a]) when t.accel <> Off ->
      [Un (QRsqrt, d, a)]
  | Call ([d], "rcp", [a]) when t.accel <> Off ->
      [Un (QRcp, d, a)]

  | _ -> [i]

(* Zbb 拡張命令の変換 *)
let lower_zbb_instr (t : target) (i : instr) : instr list =
  if t.march = Im_zbb then
    (* 標準ライブラリの関数呼び出しをハードウェア命令に変換 *)
    match i with
    | Call ([d], ("min" | "qmin"), [a; b]) -> [Bin (Min, d, a, b)]
    | Call ([d], ("max" | "qmax"), [a; b]) -> [Bin (Max, d, a, b)]
    | Call ([d], "andn", [a; b])           -> [Bin (Andn, d, a, b)]
    | Call ([d], "orn", [a; b])            -> [Bin (Orn, d, a, b)]
    | Call ([d], "xnor", [a; b])           -> [Bin (Xnor, d, a, b)]
    | Call ([d], ("clz" | "qclz"), [a])    -> [Un (Clz, d, a)]
    | _ -> [i]
  else
    (* ハードウェア命令を標準ライブラリの関数呼び出しに変換 *)
    match i with
    | Bin (Min, d, a, b)  -> [Call ([d], "min", [a; b])]
    | Bin (Max, d, a, b)  -> [Call ([d], "max", [a; b])]
    | Bin (Andn, d, a, b) -> [Call ([d], "andn", [a; b])]
    | Bin (Orn, d, a, b)  -> [Call ([d], "orn", [a; b])]
    | Bin (Xnor, d, a, b) -> [Call ([d], "xnor", [a; b])]
    | Un (Clz, d, a)      -> [Call ([d], "clz", [a])]
    | Bin ((Minu | Maxu), _, _, _) | Un ((Sext_b | Sext_h), _, _) ->
        failwith "minu/maxu/sext_b/sext_h require --march=rv32im_zbb"
    | _ -> [i]

(* M 拡張命令の変換 *)
let lower_m_instr (t : target) (i : instr) : instr list =
  if t.march <> I then [i]
  else
    match i with
    | Bin (Mul, d, a, b)   -> [Call ([d], "__mul", [a; b])]
    | Bin (Mulh, d, a, b)  -> [Call ([d], "__mulh", [a; b])]
    | Bin (Mulhu, d, a, b) -> [Call ([d], "__mulhu", [a; b])]
    | Bin (Div, d, a, b)   -> [Call ([d], "__div", [a; b])]
    | Bin (Rem, d, a, b)   -> [Call ([d], "__rem", [a; b])]
    | Bin ((Mulhsu | Divu | Remu), _, _, _) ->
        failwith "mulhsu/divu/remu require --march=rv32im or rv32im_zbb"
    | _ -> [i]

(* プログラム全体の変換 *)
let run (t : target) (p : program) : program =
  let p1 = apply_pass (lower_math_instr t) p in
  let p2 = apply_pass (lower_zbb_instr t) p1 in
  let p3 = apply_pass (lower_m_instr t) p2 in
  p3

