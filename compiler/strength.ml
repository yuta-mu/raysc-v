open Ir

(*nが2のべき乗(正)ならその指数*)
let log2 (n : int32) =
  if Int32.compare n 0l > 0 && Int32.logand n (Int32.sub n 1l) = 0l then begin
    let k = ref 0 and x = ref n in
    while !x <> 1l do x := Int32.shift_right_logical !x 1; incr k done;
    Some !k
  end else None

(*定数を1回だけ入れるvreg->その値(引数はのぞく)*)
let single_consts (f : func) =
  let count = Hashtbl.create 256 and value = Hashtbl.create 256 in
  List.iter (fun b -> List.iter (fun i ->
    List.iter (fun d ->
      Hashtbl.replace count d (1 + Option.value ~default:0 (Hashtbl.find_opt count d))) (defs i);
    (match i with Const (d, n) -> Hashtbl.replace value d n | _ -> ())) b.body) f.blocks;
  let h = Hashtbl.create 64 in
  Hashtbl.iter (fun v n ->
    if Hashtbl.find_opt count v = Some 1 && not (List.mem v f.params) then Hashtbl.replace h v n)
    value;
  h

let run_func (f : func) : func =
  let consts = single_consts f in
  let next = ref f.nvregs in
  (* シフト量を入れる新しい vreg と、その Const 命令 *)
  let amount k =
    let v = !next in
    incr next;
    (v, Const (v, Int32.of_int k)) in
  let exp_of v = Option.bind (Hashtbl.find_opt consts v) log2 in
  (* x と y のどちらかが 2 のべき乗の定数なら Some (もう片方, 指数) *)
  let pick x y =
    match exp_of y, exp_of x with
    | Some k, _ -> Some (x, k)
    | None, Some k -> Some (y, k)
    | None, None -> None in
  let shift op d a k =
    if k = 0 then [Move (d, a)]
    else let (kv, c) = amount k in [c; Bin (op, d, a, kv)] in
  let rewrite (i : instr) : instr list =
    match i with
    | Bin (Mul, d, x, y) ->
        (match pick x y with
         | Some (a, k) -> shift Shl d a k
         | None -> [i])
    | Bin (QMul, d, x, y) ->
        (match pick x y with
         | Some (a, m) when m >= 16 -> shift Shl d a (m - 16)
         | Some (a, m) -> shift Sra d a (16 - m)
         | None -> [i])
    | _ -> [i] in
  let blocks = List.map (fun b -> { b with body = List.concat_map rewrite b.body }) f.blocks in
  { f with blocks; nvregs = !next }

let run (p : program) : program = { p with funcs = List.map run_func p.funcs }