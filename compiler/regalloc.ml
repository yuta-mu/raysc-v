open Ir

module IS = Set.Make (Int)    (* vreg の集合 *)

(*生存解析*)
(* ブロック b の use(書く前に読む vreg) と def(書く vreg) *)
let block_use_def (b : block) =
  let use = ref IS.empty and def = ref IS.empty in
  let read v = if not (IS.mem v !def) then use := IS.add v !use in
  List.iter (fun i ->
    List.iter read (uses i);                                 (* 先に読む *)
    List.iter (fun d -> def := IS.add d !def) (defs i))      (* それから書く *)
    b.body;
  List.iter read (term_uses b.term);
  (!use, !def)

(* 各ブロックの、入口と出口で生きている vreg *)
let liveness (f : func) =
  let ud = Hashtbl.create 64 in
  List.iter (fun b -> Hashtbl.replace ud b.label (block_use_def b)) f.blocks;
  let live_in = Hashtbl.create 64 and live_out = Hashtbl.create 64 in
  List.iter (fun b ->
    Hashtbl.replace live_in b.label IS.empty;
    Hashtbl.replace live_out b.label IS.empty) f.blocks;
  let changed = ref true in
  while !changed do                                          (* 変わらなくなるまでくり返す *)
    changed := false;
    List.iter (fun b ->                                      (* 後ろのブロックから回すと早く決まる *)
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

(* vreg ごとに、その vreg を書いている命令を集める *)
let def_sites (f : func) =
  let h = Hashtbl.create 256 in
  List.iter (fun b -> List.iter (fun i ->
    List.iter (fun d ->
      Hashtbl.replace h d (i :: Option.value ~default:[] (Hashtbl.find_opt h d))) (defs i))
    b.body) f.blocks;
  h

(*生存区間*)
(* 命令に通し番号をつける。ブロックの命令は bs, bs+1, …、終端はbe*)
let number (f : func) =
  let pos = ref 0 in
  let ranges = Hashtbl.create 64 in              (* label -> (bs, be) *)
  List.iter (fun b ->
    let bs = !pos in
    let be = bs + List.length b.body in          (* 終端の番号 *)
    Hashtbl.replace ranges b.label (bs, be);
    pos := be + 1) f.blocks;
  ranges

type interval = {
  iv : vreg;
  mutable start : int;
  mutable stop : int;
}

let build_intervals (f : func) =
  let (live_in, live_out) = liveness f in
  let ranges = number f in
  let tbl = Hashtbl.create 256 in
  let touch v p =
    match Hashtbl.find_opt tbl v with
    | None -> Hashtbl.replace tbl v { iv = v; start = p; stop = p }
    | Some it ->
        it.start <- min it.start p;
        it.stop <- max it.stop p in
  List.iter (fun v -> touch v 0) f.params;          (* 引数は入口から生きている *)
  List.iter (fun b ->
    let (bs, be) = Hashtbl.find ranges b.label in
    IS.iter (fun v -> touch v bs) (Hashtbl.find live_in b.label);
    IS.iter (fun v -> touch v be) (Hashtbl.find live_out b.label);
    List.iteri (fun k i ->
      List.iter (fun v -> touch v (bs + k)) (uses i);
      List.iter (fun v -> touch v (bs + k)) (defs i)) b.body;
    List.iter (fun v -> touch v be) (term_uses b.term)) f.blocks;
  (tbl, ranges)

(*tやaをこわす命令か。accel_off:--accel=off か、zbb:--march=rv32im_zbb か*)
let clobbers ~accel_off ~zbb = function
  | Call _ -> true
  | Intr _ -> accel_off                                 (* off なら __q16_sqrt などを呼ぶ(runtime)*)
  | Zbb_b _ | Zbb_u _ | Qabs _ | Qclamp _ -> not zbb     (* Zbb がなければ __min などを呼ぶ *)
  | _ -> false

(*tやaをこわす命令の通し番号*)
let call_points ~accel_off ~zbb (f : func) ranges =
  List.concat_map (fun b ->
    let (bs, _) = Hashtbl.find ranges b.label in
    List.concat (List.mapi (fun k i ->
      if clobbers ~accel_off ~zbb i then [bs + k] else []) b.body)) f.blocks

(*区間itが、呼び出しをまたぐか(呼び出しの前から後ろまで生きているか)*)
let crosses calls it = List.exists (fun p -> it.start < p && p < it.stop) calls

(*線形スキャン*)
type loc =
  | Reg of string        (* レジスタ *)
  | Slot of int          (* スタックの何番目のスロットか *)
  | Remat of int32       (* 定数:使うたびに li で作り直す *)

let callee_regs = ["s0"; "s1"; "s2"; "s3"; "s4"; "s5"; "s6"; "s7"; "s8"; "s9"; "s10"; "s11"]
let caller_regs = ["t4"; "t5"; "a2"; "a3"; "a4"; "a5"; "a6"; "a7"]

(* reserved:べpスレジスタに使うので割り当てないsレジスタ*)
let allocate ?(reserved = []) ~accel_off ~zbb (f : func) =
  let (tbl, ranges) = build_intervals f in
  let calls = call_points ~accel_off ~zbb f ranges in
  let sites = def_sites f in
  let has_call = List.exists (fun b ->
    List.exists (function Call _ -> true | _ -> false) b.body) f.blocks in
  let callee = List.filter (fun r -> not (List.mem r reserved)) callee_regs in
  let caller = if has_call then ["t4"; "t5"] else caller_regs in   (* Call があれば a は引数に使うので外す *)
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
        (* cur と同じレジスタを使える区間の中で、いちばん長く残るものを選ぶ *)
        let cands = List.filter (fun (_, r) -> usable cur r) !active in
        let victim = List.fold_left (fun acc ((a, _) as c) ->
          match acc with
          | Some (b, _) when b.stop >= a.stop -> acc
          | _ -> Some c) None cands in
        (match victim with
         | Some (a, r) when a.stop > cur.stop ->  (* 相手のほうが長く残るなら、相手を spill *)
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
    | Some [Const (_, n)] -> Hashtbl.replace locs it.iv (Remat n)   (* 定数は作り直す *)
    | _ -> Hashtbl.replace locs it.iv (Slot !nslots); incr nslots) (List.rev !spilled);
  let used_callee = List.filter (fun r ->
    Hashtbl.fold (fun _ r' b -> b || r = r') assign false) callee in
  (locs, !nslots, used_callee)

(* 区間の数、呼び出しをまたぐ区間の数、割り当ての結果を表示する *)
let report ~accel_off ~zbb (f : func) =
  let (tbl, ranges) = build_intervals f in
  let calls = call_points ~accel_off ~zbb f ranges in
  let ivs = Hashtbl.fold (fun _ it acc -> it :: acc) tbl [] in
  let ncross = List.length (List.filter (crosses calls) ivs) in
  let (locs, nslots, used) = allocate ~accel_off ~zbb f in
  let nreg = ref 0 and nremat = ref 0 in
  Hashtbl.iter (fun _ l -> match l with
    | Reg _ -> incr nreg | Remat _ -> incr nremat | Slot _ -> ()) locs;
  Printf.eprintf "%s: 区間=%d 呼び出し=%d またぐ区間=%d | レジスタ=%d スロット=%d 作り直し=%d 使ったs=%d\n"
    f.name (List.length ivs) (List.length calls) ncross !nreg nslots !nremat (List.length used)