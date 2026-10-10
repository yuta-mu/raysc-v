open Ast

let compile ctx =
  let constants = Hashtbl.fold (fun n (t, v) acc -> (n, t, v) :: acc) ctx.Semant.consts [] in
  let compile_function (info : Semant.fn_info) =
    let code = ref [] in
    let next_slot = ref info.Semant.total_frame_words in
    let next_label = ref 0 in
    let breaks = ref [] and continues = ref [] in
    let emit i = code := i :: !code in
    let fresh_slot words =
      let x = !next_slot in
      next_slot := !next_slot + words;
      x
    in
    let fresh_label () = let x = !next_label in incr next_label; x in

    let rec expr e =
      match e.desc with
      | Literal l ->
          let d = fresh_slot 1 in
          emit (Ir.Move (d, Ir.Imm l));
          d
      | Variable n ->
          (match Hashtbl.find_opt info.Semant.slots n with
           | Some s -> s
           | None ->
               (match Hashtbl.find_opt ctx.Semant.consts n with
                | Some (I32, CVI32 v) ->
                    let d = fresh_slot 1 in
                    emit (Ir.Move (d, Ir.Imm (LI32 v)));
                    d
                | Some (Q16, CVQ16 v) ->
                    let d = fresh_slot 1 in
                    emit (Ir.Move (d, Ir.Imm (LQ16 v)));
                    d
                | Some (Bool, CVBool b) ->
                    let d = fresh_slot 1 in
                    emit (Ir.Move (d, Ir.Imm (LBool b)));
                    d
                | Some _ ->
                    let d = fresh_slot 1 in
                    emit (Ir.Move (d, Ir.Static n));
                    d
                | None -> failwith ("unknown variable: " ^ n)))
      | Unary (op, x) ->
          let sa = expr x in
          let d = fresh_slot 1 in
          emit (Ir.Un (d, Semant.infer_expr ctx info x, op, sa));
          d
      | Binary (((And | Or) as op), a, b) ->
          let d = fresh_slot 1 in
          let short_l = fresh_label () and done_l = fresh_label () in
          let sa = expr a in
          (match op with
           | And ->
               emit (Ir.BranchFalse (sa, short_l));
               let sb = expr b in
               emit (Ir.Move (d, Ir.Slot sb));
               emit (Ir.Jump done_l);
               emit (Ir.Label short_l);
               emit (Ir.Move (d, Ir.Imm (LBool false)));
               emit (Ir.Label done_l)
           | Or ->
               emit (Ir.BranchFalse (sa, done_l));
               emit (Ir.Move (d, Ir.Imm (LBool true)));
               emit (Ir.Jump short_l);
               emit (Ir.Label done_l);
               let sb = expr b in
               emit (Ir.Move (d, Ir.Slot sb));
               emit (Ir.Label short_l)
           | _ -> ());
          d
      | Binary (Dot, a, b) ->
          let sa = expr a and sb = expr b in
          let d = fresh_slot 1 in
          emit (Ir.Bin (d, Q16, Dot, sa, sb));
          d
      | Binary (Mul, a, b) ->
          let ta = Semant.infer_expr ctx info a and tb = Semant.infer_expr ctx info b in
          let sa = expr a and sb = expr b in
          if ta = Vec3 && tb = Q16 then begin
            let d = fresh_slot 3 in
            emit (Ir.Bin (d, Vec3, Mul, sa, sb));
            d
          end else if ta = Q16 && tb = Q16 then begin
            let d = fresh_slot 1 in
            emit (Ir.Bin (d, Q16, Mul, sa, sb));
            d
          end else begin
            let d = fresh_slot 1 in
            emit (Ir.Bin (d, I32, Mul, sa, sb));
            d
          end
      | Binary (op, a, b) ->
          let ta = Semant.infer_expr ctx info a in
          let sa = expr a and sb = expr b in
          let words = Semant.type_words ctx.Semant.structs ta in
          let d = fresh_slot words in
          emit (Ir.Bin (d, ta, op, sa, sb));
          d
      | Call ("vec3", [x; y; z]) ->
          let sx = expr x and sy = expr y and sz = expr z in
          let d = fresh_slot 3 in
          emit (Ir.Move (d, Ir.Slot sx));
          emit (Ir.Move (d + 1, Ir.Slot sy));
          emit (Ir.Move (d + 2, Ir.Slot sz));
          d
      | Call ("print", [{ desc = Literal (LString s); _ }]) ->
          let str_id = fresh_label () in
          emit (Ir.PrintStr (s, str_id));
          fresh_slot 0
      | Call ("bprint", [arg]) ->
          let sa = expr arg in
          emit (Ir.Call (None, "bprint", [sa]));
          fresh_slot 0
      | Call (("cycles" | "q16" | "i32" | "sqrt" | "rsqrt" | "rcp") as m, args) ->
          let sargs = List.map expr args in
          let d = fresh_slot 1 in
          emit (Ir.Call (Some d, m, sargs));
          d
      | Call (n, args) when Hashtbl.mem ctx.Semant.structs n ->
          let sargs = List.map expr args in
          let words = Semant.type_words ctx.Semant.structs (Struct n) in
          let d = fresh_slot words in
          let curr = ref 0 in
          List.iter2 (fun fld sa ->
            let fw = Semant.type_words ctx.Semant.structs fld.field_type in
            for i = 0 to fw - 1 do
              emit (Ir.Move (d + !curr + i, Ir.Slot (sa + i)))
            done;
            curr := !curr + fw
          ) (Hashtbl.find ctx.Semant.structs n) sargs;
          d
      | Call (n, args) ->
          let callee = Hashtbl.find ctx.Semant.functions n in
          let flat_args = ref [] in
          List.iter2 (fun p arg ->
            let s = expr arg in
            let w = Semant.type_words ctx.Semant.structs p.param_type in
            for i = 0 to w - 1 do
              flat_args := !flat_args @ [s + i]
            done
          ) callee.params args;
          if callee.ret_type = Void then begin
            emit (Ir.Call (None, n, !flat_args));
            fresh_slot 0
          end else begin
            let words = Semant.type_words ctx.Semant.structs callee.ret_type in
            let d = fresh_slot words in
            emit (Ir.Call (Some d, n, !flat_args));
            d
          end
      | Field (base, fld) ->
          let base_ty = Semant.infer_expr ctx info base in
          let off = match base_ty with
            | Vec3 -> (match fld with "x" -> 0 | "y" -> 1 | "z" -> 2 | _ -> assert false)
            | Struct sn -> Semant.field_offset ctx.Semant.structs sn fld
            | _ -> assert false
          in
          let sbase = expr base in
          sbase + off
      | Index (base, index) ->
          let sidx = expr index in
          let d = fresh_slot 1 in
          (match base.desc with
           | Variable n when Hashtbl.mem ctx.Semant.consts n ->
               emit (Ir.IndexGet (d, Ir.Static n, sidx))
           | _ ->
               let sbase = expr base in
               emit (Ir.IndexGet (d, Ir.Slot sbase, sidx)));
          d
    in

    let rec stmt = function
      | Block xs -> List.iter stmt xs
      | Let (n, ty, init) ->
          Option.iter (fun e ->
            let src = expr e in
            let dst = Hashtbl.find info.Semant.slots n in
            let words = Semant.type_words ctx.Semant.structs ty in
            for i = 0 to words - 1 do
              emit (Ir.Move (dst + i, Ir.Slot (src + i)))
            done
          ) init
      | Assign (lhs, rhs) ->
          let src = expr rhs in
          let words = Semant.type_words ctx.Semant.structs (Semant.infer_expr ctx info lhs) in
          let dst = expr lhs in
          for i = 0 to words - 1 do
            emit (Ir.Move (dst + i, Ir.Slot (src + i)))
          done
      | Expr e -> ignore (expr e)
      | If (c, yes, no) ->
          let sc = expr c in
          let otherwise = fresh_label () and done_ = fresh_label () in
          emit (Ir.BranchFalse (sc, otherwise));
          stmt yes;
          (match no with
           | None -> emit (Ir.Label otherwise)
           | Some s ->
               emit (Ir.Jump done_);
               emit (Ir.Label otherwise);
               stmt s;
               emit (Ir.Label done_))
      | While (c, body) ->
          let start = fresh_label () and done_ = fresh_label () in
          emit (Ir.Label start);
          let sc = expr c in
          emit (Ir.BranchFalse (sc, done_));
          breaks := done_ :: !breaks; continues := start :: !continues;
          stmt body;
          breaks := List.tl !breaks; continues := List.tl !continues;
          emit (Ir.Jump start);
          emit (Ir.Label done_)
      | For (id, a, b, body) ->
          let sa = expr a in
          let sb = expr b in
          let loop_var = Hashtbl.find info.Semant.slots id in
          emit (Ir.Move (loop_var, Ir.Slot sa));
          let start = fresh_label () and step_lbl = fresh_label () and done_ = fresh_label () in
          emit (Ir.Label start);
          let cond_slot = fresh_slot 1 in
          emit (Ir.Bin (cond_slot, I32, Lt, loop_var, sb));
          emit (Ir.BranchFalse (cond_slot, done_));
          breaks := done_ :: !breaks; continues := step_lbl :: !continues;
          stmt body;
          breaks := List.tl !breaks; continues := List.tl !continues;
          emit (Ir.Label step_lbl);
          let inc_slot = fresh_slot 1 in
          let one_slot = fresh_slot 1 in
          emit (Ir.Move (one_slot, Ir.Imm (LI32 1l)));
          emit (Ir.Bin (inc_slot, I32, Add, loop_var, one_slot));
          emit (Ir.Move (loop_var, Ir.Slot inc_slot));
          emit (Ir.Jump start);
          emit (Ir.Label done_)
      | Break -> emit (Ir.Jump (List.hd !breaks))
      | Continue -> emit (Ir.Jump (List.hd !continues))
      | Return None -> emit (Ir.Return None)
      | Return (Some x) -> emit (Ir.Return (Some (expr x)))
    in
    stmt info.Semant.body;
    if info.Semant.ret_type = Void then emit (Ir.Return None);
    {
      Ir.name = info.Semant.fn_name;
      param_words = info.Semant.param_words;
      ret_type = info.Semant.ret_type;
      frame_size = !next_slot;
      code = List.rev !code;
    }
  in
  { Ir.constants; functions = List.map compile_function (Hashtbl.fold (fun _ f acc -> f :: acc) ctx.Semant.functions []) }

