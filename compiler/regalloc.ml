open Ir

module IS = Set.Make (Int) (*vregの集合*)

(*1:生存解析*)
(*ブロックbのuse(書く前に読むvreg)とdef(書くvreg)*)
let block_use_def (b : block) =
  let use = ref IS.empty and def = ref IS.empty in
  let read v = if not (IS.mem v !def) then use := IS.add v !use in
  List.iter (fun i ->
    List.iter read (uses i);                                 (* 先に読む *)
    List.iter (fun d -> def := IS.add d !def) (defs i))      (* それから書く *)
    b.body;
  List.iter read (term_uses b.term);
  (!use, !def)

(*各ブロックの、入口と出口で生きているvreg*)
let liveness (f : func) =
  let ud = Hashtbl.create 64 in
  List.iter (fun b -> Hashtbl.replace ud b.label (block_use_def b)) f.blocks;
  let live_in = Hashtbl.create 64 and live_out = Hashtbl.create 64 in
  List.iter (fun b ->
    Hashtbl.replace live_in b.label IS.empty;
    Hashtbl.replace live_out b.label IS.empty) f.blocks;
  let changed = ref true in
  while !changed do (*変わらなくなるまでくり返す*)
    changed := false;
    List.iter (fun b ->        (*後ろのブロックから回すと早く決まる*)
      let out = List.fold_left (fun acc l ->
        IS.union acc (Hashtbl.find live_in l)) IS.empty (successors b.term) in
      let (u, d) = Hashtbl.find ud b.label in
      let inn = IS.union u (IS.diff out d) in
      if not (IS.equal out (Hashtbl.find live_out b.label))
      || not (IS.equal inn (Hashtbl.find live_in b.label)) then begin
        changed := true;
        Hashtbl.replace live_out b.label out;
        Hashtbl.replace live_in b.label inn
      end) (List.rev f.blocks)
  done;
  (live_in, live_out)

(*vregごとに、そのvregを書いている命令を集める*)
let def_sites (f : func) =
  let h = Hashtbl.create 256 in
  List.iter (fun b -> List.iter (fun i ->
    List.iter (fun d ->
      Hashtbl.replace h d (i :: Option.value ~default:[] (Hashtbl.find_opt h d))) (defs i))
    b.body) f.blocks;
  h

(*2:生存区間*)
(*命令に通し番号をつける。ブロックの命令は bs,bs+1, …、終端はbe*)
let number (f : func) =
  let pos = ref 0 in
  let ranges = Hashtbl.create 64 in              (* label -> (bs, be) *)
  List.iter (fun b ->
    let bs = !pos in
    let be = bs + List.length b.body in          (* 終端の番号 *)
    Hashtbl.replace ranges b.label (bs, be);
    pos := be + 1) f.blocks;
  ranges

(* 番号pが、いくつのループの中にあるか。うしろから前のブロックへ戻る矢印(戻り辺)を見つけたら、そこまでをループとみなす*)
let loop_depth (f : func) ranges =
  let loops = List.concat_map (fun b ->
    let (bs, be) = Hashtbl.find ranges b.label in
    List.filter_map (fun l ->
      let (ls, _) = Hashtbl.find ranges l in
      if ls <= bs then Some (ls, be) else None)     (* 前に戻る矢印 = ループ *)
      (successors b.term)) f.blocks in
  fun p -> List.length (List.filter (fun (s, e) -> s <= p && p <= e) loops)

type interval = {
  iv : vreg;
  mutable start : int;
  mutable stop : int;
  mutable weight : float;   (* 使われた回数。ループ 1 段の中なら 1 回を 10 回分と数える *)
}

(*1命令あたりの使われ方。小さいほどspillしても損が小さい*)
let density it = it.weight /. float_of_int (it.stop - it.start + 1)

let build_intervals (f : func) =
  let (live_in, live_out) = liveness f in
  let ranges = number f in
  let depth = loop_depth f ranges in
  let w p = 10. ** float_of_int (min 8 (depth p)) in   (* ループ 1 段で 10 倍(8 段まで) *)
  let tbl = Hashtbl.create 256 in
  (* v が番号 p で生きている。w は重みに足す量(使うとき w p、生きているだけなら 0) *)
  let touch v p w =
    match Hashtbl.find_opt tbl v with
    | None -> Hashtbl.replace tbl v { iv = v; start = p; stop = p; weight = w }
    | Some it ->
        it.start <- min it.start p;
        it.stop <- max it.stop p;
        it.weight <- it.weight +. w in
  List.iter (fun v -> touch v 0 0.) f.params;          (* 引数は入口から生きている *)
  List.iter (fun b ->
    let (bs, be) = Hashtbl.find ranges b.label in
    IS.iter (fun v -> touch v bs 0.) (Hashtbl.find live_in b.label);
    IS.iter (fun v -> touch v be 0.) (Hashtbl.find live_out b.label);
    List.iteri (fun k i ->
      let p = bs + k in
      List.iter (fun v -> touch v p (w p)) (uses i);
      List.iter (fun v -> touch v p (w p)) (defs i)) b.body;
    List.iter (fun v -> touch v be (w be)) (term_uses b.term)) f.blocks;
  (tbl, ranges)

(*tやaをこわす命令か。accel_off:--accel=off か、zbb:--march=rv32im_zbb か*)
let clobbers ~accel_off ~zbb = function
  | Call _ -> true
  | Intr _ -> accel_off                                 (* off なら __q16_sqrt などを呼ぶ *)
  | Zbb_b _ | Zbb_u _ | Qabs _ | Qclamp _ -> not zbb     (* Zbb がなければ __min などを呼ぶ *)
  | _ -> false

(*tやaをこわす命令の通し番号*)
let call_points ~accel_off ~zbb (f : func) ranges =
  List.concat_map (fun b ->
    let (bs, _) = Hashtbl.find ranges b.label in
    List.concat (List.mapi (fun k i ->
      if clobbers ~accel_off ~zbb i then [bs + k] else []) b.body)) f.blocks

(* 区間 it が、呼び出しをまたぐか(呼び出しの前から後ろまで生きているか) *)
let crosses calls it = List.exists (fun p -> it.start < p && p < it.stop) calls

(*3:線形スキャン*)
type loc =
  | Reg of string        (* レジスタ *)
  | Slot of int          (* スタックの何番目のスロットか *)
  | Remat of int32       (* 定数:使うたびに li で作り直す *)

let callee_regs = ["s0"; "s1"; "s2"; "s3"; "s4"; "s5"; "s6"; "s7"; "s8"; "s9"; "s10"; "s11"]
let caller_regs = ["t4"; "t5"; "a2"; "a3"; "a4"; "a5"; "a6"; "a7"]


(*reserved:旗に使うので割り当てないsレジスタ
   返り値:(vreg -> 置き場所, スロットの数, 使ったsレジスタ)*)
let allocate ?(reserved = []) ~accel_off ~zbb (f : func) =
  let (tbl, ranges) = build_intervals f in
  let calls = call_points ~accel_off ~zbb f ranges in
  let sites = def_sites f in
  let has_call = List.exists (fun b ->
    List.exists (function Call _ -> true | _ -> false) b.body) f.blocks in
  let big_ret = List.exists (fun b ->
    match b.term with Ret vs -> List.length vs > 2 | _ -> false) f.blocks in
  let callee = List.filter (fun r -> not (List.mem r reserved)) callee_regs in
  (* a2〜a7 は、引数・戻り値の受けわたしと重ならないときだけ使う *)
  let use_a = not has_call && f.params = [] && not big_ret in
  let caller = if use_a then caller_regs else ["t4"; "t5"] in
  let is_callee r = List.mem r callee in
  let cross it = crosses calls it in
  let usable it r = not (cross it) || is_callee r in
  let ivs = List.sort (fun a b -> compare (a.start, a.stop) (b.start, b.stop))
              (Hashtbl.fold (fun _ it acc -> it :: acc) tbl []) in
  let assign = Hashtbl.create 256 in              (* vreg -> レジスタ名 *)
  let spilled = ref [] in
  let active = ref [] in                          (* (区間, レジスタ) *)
  let free_callee = ref callee and free_caller = ref caller in
  let release r =
    if is_callee r then free_callee := r :: !free_callee else free_caller := r :: !free_caller in
  let take r =
    free_callee := List.filter ((<>) r) !free_callee;
    free_caller := List.filter ((<>) r) !free_caller in
  List.iter (fun cur ->
    (* cur が始まる前に終わった区間のレジスタを返してもらう *)
    let (ended, still) = List.partition (fun (a, _) -> a.stop < cur.start) !active in
    List.iter (fun (_, r) -> release r) ended;
    active := still;
    let pick =
      if cross cur then (match !free_callee with r :: _ -> Some r | [] -> None)
      else (match !free_caller, !free_callee with
            | r :: _, _ -> Some r                 (* またがない区間は t / a を優先 *)
            | [], r :: _ -> Some r
            | [], [] -> None) in
    match pick with
    | Some r ->
        take r; Hashtbl.replace assign cur.iv r; active := (cur, r) :: !active
    | None ->
        (* cur と同じレジスタを使える区間の中で、重み ÷ 長さがいちばん小さいものを選ぶ *)
        let cands = List.filter (fun (_, r) -> usable cur r) !active in
        let victim = List.fold_left (fun acc ((a, _) as c) ->
          match acc with
          | Some (b, _) when density b <= density a -> acc
          | _ -> Some c) None cands in
        (match victim with
         | Some (a, r) when density a < density cur ->  (* 相手のほうが spill に向くなら、相手を spill *)
             Hashtbl.remove assign a.iv;
             spilled := a :: !spilled;
             active := (cur, r) :: List.filter (fun (b, _) -> b != a) !active;
             Hashtbl.replace assign cur.iv r
         | _ -> spilled := cur :: !spilled)) ivs;
  (* 結果の表:レジスタ / スロット / 作り直し *)
  let locs = Hashtbl.create 256 in
  Hashtbl.iter (fun v r -> Hashtbl.replace locs v (Reg r)) assign;
  let nslots = ref 0 in
  List.iter (fun it ->
    match Hashtbl.find_opt sites it.iv with
    | Some [Const (_, n)] when not (List.mem it.iv f.params) ->
        Hashtbl.replace locs it.iv (Remat n)                        (* 定数は作り直す *)
    | _ -> Hashtbl.replace locs it.iv (Slot !nslots); incr nslots) (List.rev !spilled);
  let used_callee = List.filter (fun r ->
    Hashtbl.fold (fun _ r' b -> b || r = r') assign false) callee in
  (locs, !nslots, used_callee)