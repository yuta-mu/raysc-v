open Ir

(* ターゲット定義 (旧 Emitter から移設) *)
type accel = Off | Math | Rand | Isect
type march = I | Im | Im_zbb

type target = {
  accel : accel;
  march : march;
}

(* 1 命令 -> 複数命令 への変換パスをプログラム全体に適用する *)
let apply_pass (f : instr -> instr list) (p : program) : program =
  let map_block b =
    let body = List.concat (List.map f b.body) in
    { b with body }
  in
  let map_func fn =
    { fn with blocks = List.map map_block fn.blocks }
  in
  { p with funcs = List.map map_func p.funcs }

(* ------------------------------------------------
 * Pass 1: Math / アクセラレータ拡張の lower
 * ------------------------------------------------ *)
let lower_math_instr (t : target) (i : instr) : instr list =
  match i with
  (* --accel=off のとき、QMul を標準ライブラリの __qmul 呼び出しに変換 *)
  | Bin (QMul, d, a, b) when t.accel = Off ->
      [Call ([d], "__qmul", [a; b])]

  (* 将来的に sqrt/rsqrt/rcp を組み込み命令に戻す場合はここで変換する:
  | Un (QSqrt, d, a) when t.accel = Off -> [Call ([d], "__q16_sqrt", [a])]
  *)

  (* ターゲット非対応のアクセラレータ命令を検出 *)
  | AccelSetSphere _ when t.accel <> Isect ->
      failwith "accel_set_sphere requires --accel=isect"
  | AccelHit _ when t.accel <> Isect ->
      failwith "accel_hit requires --accel=isect"
  | Supplier (AccelT, _) when t.accel <> Isect ->
      failwith "accel_t requires --accel=isect"
  | Consumer (Qseed, _) | Supplier ((Qrand | Qrands), _) when t.accel = Off ->
      failwith "qseed/qrand/qrands require --accel=math or --accel=isect"

  | _ -> [i]

(* ------------------------------------------------
 * Pass 2: Zbb 拡張の lower (rv32im_zbb 以外向け・将来拡張用)
 * ------------------------------------------------ *)
let lower_zbb_instr (t : target) (i : instr) : instr list =
  if t.march = Im_zbb then [i]
  else
    match i with
    (* 将来的に Zbb 命令を IR 経由で lower する場合はここに追加:
    | Bin (Min, d, a, b) -> [Call ([d], "min", [a; b])]
    | Bin (Max, d, a, b) -> [Call ([d], "max", [a; b])]
    | Un (Clz, d, a)     -> [Call ([d], "clz", [a])]
    *)
    | _ -> [i]

(* ------------------------------------------------
 * Pass 3: M 拡張の lower (rv32i 向け・将来拡張用)
 * ------------------------------------------------ *)
let lower_m_instr (t : target) (i : instr) : instr list =
  if t.march <> I then [i]
  else
    match i with
    (* 将来的に rv32i を有効にする場合はここを有効化:
    | Bin (Mul, d, a, b)   -> [Call ([d], "__mul", [a; b])]
    | Bin (Mulh, d, a, b)  -> [Call ([d], "__mulh", [a; b])]
    | Bin (Mulhu, d, a, b) -> [Call ([d], "__mulhu", [a; b])]
    | Bin (Div, d, a, b)   -> [Call ([d], "__div", [a; b])]
    | Bin (Rem, d, a, b)   -> [Call ([d], "__rem", [a; b])]
    *)
    | _ -> [i]

(* 上位拡張から下位拡張へ向かって順に lower を実行 *)
let run (t : target) (p : program) : program =
  let p1 = apply_pass (lower_math_instr t) p in
  let p2 = apply_pass (lower_zbb_instr t) p1 in
  let p3 = apply_pass (lower_m_instr t) p2 in
  p3

