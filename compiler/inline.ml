open Ir

(*vreg番号をずらす*)
(* 命令iのvregにdv、局所配列の番号にdaを足す *)
let map_instr vm am (i : instr) : instr =
  let v = vm and a = am in
  let r = function Local id -> Local (a id) | g -> g in   (* region:Local だけずらす *)
  match i with
  | Const (d, n) -> Const (v d, n)
  | Move (d, s) -> Move (v d, v s)
  | Bin (op, d, x, y) -> Bin (op, v d, v x, v y)
  | Un (op, d, x) -> Un (op, v d, v x)
  | Intr (f, d, x) -> Intr (f, v d, v x)
  | Zbb_b (op, d, x, y) -> Zbb_b (op, v d, v x, v y)      
  | Zbb_u (op, d, x) -> Zbb_u (op, v d, v x)             
  | Qabs (d, x) -> Qabs (v d, v x)                       
  | Qclamp (d, x, y, z) -> Qclamp (v d, v x, v y, v z)    
  | AddrLocal (d, id) -> AddrLocal (v d, a id)
  | AddrGlobal (d, s) -> AddrGlobal (v d, s)          (* 名前はずらさない *)
  | Load (d, rg, x, o) -> Load (v d, r rg, v x, o)
  | Store (id, x, o, s) -> Store (a id, v x, o, v s)
  | Call (rs, f, args) -> Call (List.map v rs, f, List.map v args)
  | Bprint x -> Bprint (v x)
  | Cycles d -> Cycles (v d)

(* 終わりの命令:vreg に dv、ラベルに dl を足す *)
let map_term vm dl (t : terminator) : terminator =
  match t with
  | Jump l -> Jump (l + dl)
  | Branch (c, lt, lf) -> Branch (vm c, lt + dl, lf + dl)
  | Ret vs -> Ret (List.map vm vs)

(* 関数 g の全部(引数、配列、ブロック)をずらしたコピー *)
let map_func vm dl da (g : func) : func =
  { g with
    params = List.map vm g.params;
    arrays = List.map (fun (id, bytes) -> (id + da, bytes)) g.arrays;
    blocks = List.map (fun b ->
      { label = b.label + dl;
        body = List.map (map_instr vm (fun id -> id + da)) b.body;
        term = map_term vm dl b.term }) g.blocks }

let defined_vregs (g : func) =
  let h = Hashtbl.create 64 in
  List.iter (fun b -> List.iter (fun i ->
    List.iter (fun d -> Hashtbl.replace h d ()) (defs i)) b.body) g.blocks;
  h

let max_label (f : func) = List.fold_left (fun m b -> max m b.label) 0 f.blocks
let next_array (f : func) = List.fold_left (fun m (id, _) -> max m (id + 1)) 0 f.arrays

(*callを1つ展開する*)
(* body を「call の前」「call」「call の後」に分ける。call がなければ None *)
let split_at_call body =
  let rec go acc = function
    | [] -> None
    | Call (rs, name, args) :: rest -> Some (List.rev acc, rs, name, args, rest)
    | i :: rest -> go (i :: acc) rest
  in
  go [] body

(* f の中で最初に見つかった call を 1 つ展開する。call がなければ None *)
let inline_one funcs (f : func) : func option =
  let rec go seen = function
    | [] -> None
    | b :: rest ->
        (match split_at_call b.body with
         | None -> go (b :: seen) rest
         | Some (pre, rs, name, args, post) ->
             let g = Hashtbl.find funcs name in
             (* f で使っていない番号からずらす *)
             let dv = f.nvregs and dl = max_label f + 1 and da = next_array f in
             let written = defined_vregs g in
             let subst = Hashtbl.create 8 in
             List.iter2 (fun p a ->
               if not (Hashtbl.mem written p) then Hashtbl.replace subst p a) g.params args;
             let vm x = match Hashtbl.find_opt subst x with Some a -> a | None -> x + dv in
             let g' = map_func vm dl da g in
             let l_after = dl + max_label g + 1 in          (* call の後ろ用の新しいラベル *)
             let entry = (List.hd g'.blocks).label in      (* g の入口 *)
             (* call の前:引数をコピーして、g の入口へ *)
              let b_pre =
               { b with body = pre @ List.filter_map (fun (p, a) ->
                                   if p = a then None else Some (Move (p, a)))   (* 置きかえた引数は Move なし *)
                                   (List.combine g'.params args);
                        term = Jump entry } in
             (* g の中身:ret を「戻り値をコピーして、call の後ろへ」に置きかえる *)
             let body_blocks = List.map (fun cb ->
               match cb.term with
               | Ret vs -> { cb with body = cb.body @ List.map2 (fun r v -> Move (r, v)) rs vs;
                                     term = Jump l_after }
               | _ -> cb) g'.blocks in
             (* call の後ろ:元のブロックの残りと、元の終わりの命令 *)
             let b_post = { label = l_after; body = post; term = b.term } in
             Some { f with nvregs = f.nvregs + g.nvregs;
                           arrays = f.arrays @ g'.arrays;
                           blocks = List.rev_append seen (b_pre :: body_blocks @ (b_post :: rest)) })
  in
  go [] f.blocks

(*callがなくなるまでくり返*)
let rec inline_all funcs f =
  match inline_one funcs f with
  | Some f' -> inline_all funcs f'
  | None -> f

(*ブロックをつなげる*)
let merge_blocks (f : func) : func =
  let entry = (List.hd f.blocks).label in
  let rec loop blocks =
    (* それぞれのラベルに、何本の道が来ているか *)
    let preds = Hashtbl.create 16 in
    List.iter (fun b -> List.iter (fun l ->
      Hashtbl.replace preds l (1 + Option.value ~default:0 (Hashtbl.find_opt preds l)))
      (successors b.term)) blocks;
    let npred l = Option.value ~default:0 (Hashtbl.find_opt preds l) in
    let can a = match a.term with
      | Jump l -> l <> a.label && l <> entry && npred l = 1
      | _ -> false in
    match List.find_opt can blocks with
    | None -> blocks
    | Some a ->
        let l = match a.term with Jump l -> l | _ -> assert false in
        let b = List.find (fun x -> x.label = l) blocks in
        let a' = { a with body = a.body @ b.body; term = b.term } in
        loop (List.filter_map (fun x ->
          if x.label = l then None else if x.label = a.label then Some a' else Some x) blocks)
  in
  { f with blocks = loop f.blocks }

(*run*)
let run (p : program) : program =
  let funcs = Hashtbl.create 16 in
  List.iter (fun f -> Hashtbl.replace funcs f.name f) p.funcs;
  let main = merge_blocks (inline_all funcs (Hashtbl.find funcs "main")) in
  { p with funcs = [ main ] }