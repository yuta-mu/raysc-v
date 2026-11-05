(*Dead Code Elimination*)
open Ir

(*入口から辿れないブロックを消す*)
let remove_unreachable (f : func) : func = 
  match f.blocks with
  | [] -> f
  | entry :: _ -> 
    let reached = Hashtbl.create 16 in
    let rec visit l = 
      if not (Hashtbl.mem reached l) then begin
        Hashtbl.replace reached l ();
        match List.find_opt (fun b -> b.label = l) f.blocks with
        (*ラベルがlに一致するブロックの終端命令から続くブロックにvistiを再帰的に適用*)
        | Some b -> List.iter visit (successors b.term) 
        | None -> ()
      end
    in
    visit entry.label;
    {f with blocks = List.filter (fun b -> Hashtbl.mem reached b.label) f.blocks}

(*使われない命令を消す*)

(*関数の中で、どこかで読まれているvregの集合*)
let used_vregs (f : func) =
  let used = Hashtbl.create 64 in
  List.iter (fun b ->
    List.iter (fun i -> List.iter (fun v -> Hashtbl.replace used v ()) (uses i)) b.body;
    List.iter (fun v -> Hashtbl.replace used v ()) (term_uses b.term)) f.blocks;
  used

(*1つの命令を消していいか判定*)
(*副作用がなく、書くvregがどれもusedに入っていない*)
let is_dead used (i : instr) =
  (not (has_side_effect i)) && List.for_all (fun d -> not (Hashtbl.mem used d)) (defs i)

(*すべての命令をis_deadで調べて、trueのものを消す*)
let remove_dead_once (f : func) : func * bool = 
  let used = used_vregs f in (*読まれているvreg*)
  let changed = ref false in
  let blocks = 
    List.map (fun b -> 
      let body = List.filter (fun i -> 
        if is_dead used i then (changed := true; false)
        else true
        ) b.body in
        { b with body }
      ) f.blocks
    in
    ({ f with blocks }, !changed)

(*何も消えなくなるまで繰り返す*)
let rec remove_dead (f : func) : func = 
  let (f2, changed) = remove_dead_once f in
  if changed then remove_dead f2 else f2

let run (p : program) : program =
  { p with funcs = List.map (fun f -> remove_dead (remove_unreachable f)) p.funcs }