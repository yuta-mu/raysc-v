open Ast

(* 部品 *)

(* リテラルを int32 に変換する *)
let int32_of_literal = function
  | LI32 v | LQ16 v | LChar v -> v          (* LQ16 は numeric.ml で 65536 倍済み *)
  | LBool b -> if b then 1l else 0l
  | LString _ -> invalid_arg "int32_of_literal: string literal"

(* const をワード列に平坦化する (構造体は宣言順, 配列は要素順) *)
let rec words_of_const = function
  | CVI32 v | CVQ16 v -> [v]
  | CVBool b -> [if b then 1l else 0l]
  | CVVec3 (x, y, z) -> [x; y; z]
  | CVStruct (_, fields) ->
      List.concat (List.map (fun (_, cv) -> words_of_const cv) fields)
  | CVArray xs -> List.concat (List.map words_of_const xs)

(* Ast.binop を Ir2.binop にする *)
(* 型に依らず 1 対 1 で決まる二項演算のみ (Mul, And, Or, Dot は専用の処理) *)
let ir_binop : Ast.binop -> Ir2.binop = function
  | Add -> Ir2.Add | Sub -> Ir2.Sub | Div -> Ir2.Div | Mod -> Ir2.Rem
  | Shl -> Ir2.Shl | Shr -> Ir2.Sra
  | BitAnd -> Ir2.And | BitOr -> Ir2.Or | BitXor -> Ir2.Xor
  | Eq -> Ir2.Eq | Ne -> Ir2.Ne | Lt -> Ir2.Lt | Le -> Ir2.Le
  | Gt -> Ir2.Gt | Ge -> Ir2.Ge
  | Mul | And | Or | Dot -> invalid_arg "ir_binop: 専用の変換が必要"

(* n が 2 の冪なら Some (log_2 n) を返す *)
let log2_exact n =
  let rec go k p = if p = n then Some k else if p > n then None else go (k + 1) (p * 2) in
  if n <= 0 then None else go 0 1

(* 左から右の順に f を適用する List.map *)
let map_ltr f xs = List.rev (List.fold_left (fun acc x -> f x :: acc) [] xs)

(* 局所配列に (名前, (配列番号, バイト数)) を割り当てる *)
(* Hashtbl の走査順は不定なので, 名前でソートして番号を安定させる *)
let local_arrays (ctx : Semant.context) (info : Semant.fn_info) =
  let arrays =
    Hashtbl.fold
      (fun n ty acc -> match ty with Array _ -> (n, ty) :: acc | _ -> acc)
      info.Semant.slot_types []
  in
  let sorted_arrays =
    List.sort (fun (a, _) (b, _) -> compare a b) arrays
  in
  List.mapi
    (fun id (n, ty) ->
       (n, (id, 4 * Semant.type_words ctx.Semant.structs ty)))
    sorted_arrays

(* 値の置き場所: vreg 上か, メモリ(配列・const)上か *)
type place =
  | PReg of Ir2.vreg                           (* vreg 上(先頭) *)
  | PMem of Ir2.region * Ir2.vreg * int        (* 領域, 基準アドレス, バイトオフセット *)


(* 変換本体 *)
let compile (ctx : Semant.context) : Ir2.program =
  let str_consts = ref [] in                   (* print 用の文字列 const (逆順) *)
  let words_of ty = Semant.type_words ctx.Semant.structs ty in

  let compile_function (info : Semant.fn_info) : Ir2.func =
    let arrays = local_arrays ctx info in
    let items = ref [Ir2.L 0] in               (* Ir2.item の逆順リスト。0 は入口 *)
    let next_vreg = ref info.Semant.total_frame_words in  (* 変数の分は semant が割り当て済み *)
    let next_label = ref 1 in
    let breaks = ref [] and continues = ref [] in
    let type_of e = Semant.infer_expr ctx info e in

    (* 命令を出す部品 *)

    let emit it = items := it :: !items in
    let emit_i i = emit (Ir2.I i) in
    let emit_t t = emit (Ir2.T t) in
    let emit_l l = emit (Ir2.L l) in
    let fresh words = let x = !next_vreg in next_vreg := x + words; x in
    let fresh_label () = let x = !next_label in incr next_label; x in
    let const_i32 n =
      let d = fresh 1 in
      emit_i (Ir2.Const (d, n));
      d
    in
    (* n ワード分, 要素ごとに二項演算 (vec3 の加減) *)
    let bin_words op n a b =
      let d = fresh n in
      for i = 0 to n - 1 do emit_i (Ir2.Bin (op, d + i, a + i, b + i)) done;
      d
    in
    let bin op a b = bin_words op 1 a b in
    let un_words op n a =
      let d = fresh n in
      for i = 0 to n - 1 do emit_i (Ir2.Un (op, d + i, a + i)) done;
      d
    in
    let intr f a =
      let d = fresh 1 in
      emit_i (Ir2.Intr (f, d, a));
      d
    in
    (* vec3 * q16 : 各成分に同じスカラー k を QMul する *)
    let vec3_scale v k =
      let d = fresh 3 in
      for i = 0 to 2 do emit_i (Ir2.Bin (Ir2.QMul, d + i, v + i, k)) done;
      d
    in
    let move_words dst src n =
      for i = 0 to n - 1 do emit_i (Ir2.Move (dst + i, src + i)) done
    in
    (* (先頭 vreg, ワード数) の列を新しい連続領域に詰めて返す *)
    (* vec3(x, y, z) や構造体コンストラクタ用 *)
    let gather parts =
      let d = fresh (List.fold_left (fun acc (_, w) -> acc + w) 0 parts) in
      ignore (List.fold_left (fun off (src, w) -> move_words (d + off) src w; off + w) 0 parts);
      d
    in
    (* base + idx * elem_bytes *)
    let index_addr base idx elem_bytes =
      let off =
        match log2_exact elem_bytes with
        | Some k -> bin Ir2.Shl idx (const_i32 (Int32.of_int k))
        | None -> bin Ir2.Mul idx (const_i32 (Int32.of_int elem_bytes))
      in
      bin Ir2.Add base off
    in

    (* place の読み書き *)

    (* 読む: vreg 上ならコピーせずそのまま返す *)
    let load_place place words =
      match place with
      | PReg r -> r
      | PMem (rg, a, o) ->
          let d = fresh words in
          for k = 0 to words - 1 do emit_i (Ir2.Load (d + k, rg, a, o + 4 * k)) done;
          d
    in
    (* 書く: メモリに書けるのは局所配列だけ *)
    let store_place place src words =
      match place with
      | PReg r -> move_words r src words
      | PMem (Ir2.Local id, a, o) ->
          for k = 0 to words - 1 do emit_i (Ir2.Store (id, a, o + 4 * k, src + k)) done
      | PMem (Ir2.Global _, _, _) -> invalid_arg "store_place: const は読み取り専用"
    in

    (* print("...") : 文字列を const (1 文字 1 ワード, 末尾 0) に登録し、
       Load / Bprint のループで出力する *)
    let print_literal s =
      let name = Printf.sprintf "__str_%d" (List.length !str_consts) in
      let words =
        List.init (String.length s) (fun i -> Int32.of_int (Char.code s.[i])) @ [0l]
      in
      str_consts := (name, words) :: !str_consts;
      let p = fresh 1 in                       (* 現在位置のアドレス *)
      let c = fresh 1 in                       (* 現在の文字 *)
      let zero = const_i32 0l in
      let four = const_i32 4l in
      let l_head = fresh_label () in
      let l_body = fresh_label () in
      let l_end = fresh_label () in
      emit_i (Ir2.AddrGlobal (p, name));
      emit_l l_head;
      emit_i (Ir2.Load (c, Ir2.Global name, p, 0));
      let nz = bin Ir2.Ne c zero in            (* Branch が 0/1 前提でも安全なように明示 *)
      emit_t (Ir2.Branch (nz, l_body, l_end));
      emit_l l_body;
      emit_i (Ir2.Bprint c);
      emit_i (Ir2.Bin (Ir2.Add, p, p, four));
      emit_t (Ir2.Jump l_head);
      emit_l l_end;
      fresh 0                                  (* void: 値なし *)
    in

    (* ---- 式: 結果が入っている先頭 vreg を返す ---- *)
    let rec expr e =
      match e.desc with
      | Literal (LString _) ->
          Semant.fail ~loc:(Some e.loc) "string literal is only allowed as the argument of print"
      | Literal l -> const_i32 (int32_of_literal l)

      | Variable n when Hashtbl.mem info.Semant.slots n ->
          Hashtbl.find info.Semant.slots n
      | Variable n ->
          (match Hashtbl.find_opt ctx.Semant.consts n with
           | Some ((I32 | Q16 | Bool), cv) ->
               (match words_of_const cv with
                | [w] -> const_i32 w
                | _ -> invalid_arg "expr: scalar const")
           | Some (ty, _) -> load_place (place_of e) (words_of ty)
           | None -> invalid_arg ("unknown variable: " ^ n))

      | Unary (op, x) ->
          let sx = expr x in
          let irop = (match op with Neg -> Ir2.Neg | Not -> Ir2.Not) in
          un_words irop (words_of (type_of x)) sx

      | Binary (And, a, b) -> short_circuit true a b
      | Binary (Or, a, b) -> short_circuit false a b

      | Binary (Dot, a, b) ->
          let sa = expr a in
          let sb = expr b in
          let p0 = bin Ir2.QMul sa sb in
          let p1 = bin Ir2.QMul (sa + 1) (sb + 1) in
          let p2 = bin Ir2.QMul (sa + 2) (sb + 2) in
          bin Ir2.Add (bin Ir2.Add p0 p1) p2

      | Binary (Mul, a, b) ->
          let sa = expr a in
          let sb = expr b in
          (match type_of a, type_of b with
           | Q16, Q16 -> bin Ir2.QMul sa sb
           | Vec3, Q16 -> vec3_scale sa sb
           | Q16, Vec3 -> vec3_scale sb sa
           | _ -> bin Ir2.Mul sa sb)           (* i32*i32, q16*i32, i32*q16 は素の乗算 *)

      | Binary (op, a, b) ->
          let sa = expr a in
          let sb = expr b in
          bin_words (ir_binop op) (words_of (type_of e)) sa sb

      | Call ("vec3", [x; y; z]) ->
          let sx = expr x in
          let sy = expr y in
          let sz = expr z in
          gather [(sx, 1); (sy, 1); (sz, 1)]
      | Call ("print", [{ desc = Literal (LString s); _ }]) -> print_literal s
      | Call ("print", _) ->
          Semant.fail ~loc:(Some e.loc) "print takes a string literal directly"
      | Call ("bprint", [x]) ->
          let sx = expr x in
          emit_i (Ir2.Bprint sx);
          fresh 0
      | Call ("cycles", []) ->
          let d = fresh 1 in
          emit_i (Ir2.Cycles d);
          d
      | Call ("q16", [x]) -> let sx = expr x in bin Ir2.Shl sx (const_i32 16l)
      | Call ("i32", [x]) -> let sx = expr x in bin Ir2.Sra sx (const_i32 16l)
      | Call ("sqrt", [x]) -> intr Ir2.Sqrt (expr x)
      | Call ("rsqrt", [x]) -> intr Ir2.Rsqrt (expr x)
      | Call ("rcp", [x]) -> intr Ir2.Rcp (expr x)
      | Call (n, args) ->
          let srcs = map_ltr expr args in
          (match Hashtbl.find_opt ctx.Semant.structs n with
           | Some fields ->
               gather (List.map2 (fun f s -> (s, words_of f.field_type)) fields srcs)
           | None ->
               let callee = Hashtbl.find ctx.Semant.functions n in
               let flat =
                 List.concat
                   (List.map2
                      (fun p s -> List.init (words_of p.param_type) (fun i -> s + i))
                      callee.Semant.params srcs)
               in
               let w = words_of callee.Semant.ret_type in   (* void なら 0 *)
               let d = fresh w in
               emit_i (Ir2.Call (List.init w (fun i -> d + i), n, flat));
               d)

      | Field _ | Index _ -> load_place (place_of e) (words_of (type_of e))

    (* a && b (is_and = true) / a || b (is_and = false) : Branch で短絡評価。
       結果の vreg d には 2 つの経路から書く(IR は SSA ではないので問題ない) *)
    and short_circuit is_and a b =
      let d = fresh 1 in
      let sa = expr a in
      let l_rhs = fresh_label () in
      let l_short = fresh_label () in
      let l_end = fresh_label () in
      emit_t (if is_and then Ir2.Branch (sa, l_rhs, l_short)
              else Ir2.Branch (sa, l_short, l_rhs));
      emit_l l_rhs;
      let sb = expr b in
      emit_i (Ir2.Move (d, sb));
      emit_t (Ir2.Jump l_end);
      emit_l l_short;
      emit_i (Ir2.Const (d, if is_and then 0l else 1l));
      emit_l l_end;                            (* l_short -> l_end の Jump は自動で補われる *)
      d

    (* 式を「場所」として解釈する。左辺値・配列要素・const の参照をここで扱う *)
    and place_of e =
      match e.desc with
      | Variable n ->
          (match List.assoc_opt n arrays with
           | Some (id, _) ->
               let a = fresh 1 in
               emit_i (Ir2.AddrLocal (a, id));
               PMem (Ir2.Local id, a, 0)
           | None ->
               (match Hashtbl.find_opt info.Semant.slots n with
                | Some s -> PReg s
                | None ->
                    let a = fresh 1 in
                    emit_i (Ir2.AddrGlobal (a, n));
                    PMem (Ir2.Global n, a, 0)))
      | Field (b, f) ->
          let off =
            match type_of b with
            | Vec3 ->
                (match f with
                 | "x" -> 0 | "y" -> 1 | "z" -> 2
                 | _ -> invalid_arg "place_of: vec3 field")
            | Struct sn -> Semant.field_offset ctx.Semant.structs sn f
            | _ -> invalid_arg "place_of: field access"
          in
          (match place_of b with
           | PReg r -> PReg (r + off)
           | PMem (rg, a, o) -> PMem (rg, a, o + 4 * off))
      | Index (b, i) ->
          (match place_of b with
           | PMem (rg, a, o) ->
               let si = expr i in
               let elem_bytes = 4 * words_of (type_of e) in
               PMem (rg, index_addr a si elem_bytes, o)
           | PReg _ -> invalid_arg "place_of: indexing a non-memory value")
      | _ -> PReg (expr e)
    in

    (* ---- 文 ---- *)
    (* ループ本体を、break / continue の飛び先を積んだ状態で実行する *)
    let in_loop l_break l_continue body =
      breaks := l_break :: !breaks;
      continues := l_continue :: !continues;
      body ();
      breaks := List.tl !breaks;
      continues := List.tl !continues
    in
    let rec stmt = function
      | Block xs -> List.iter stmt xs

      | Let (n, ty, init) ->
          Option.iter
            (fun e ->
               let src = expr e in
               move_words (Hashtbl.find info.Semant.slots n) src (words_of ty))
            init

      | Assign (lhs, rhs) ->
          let ty = type_of lhs in
          (match ty with
           | Array _ ->
               Semant.fail ~loc:(Some lhs.loc) "whole-array assignment is not supported"
           | _ ->
               let src = expr rhs in
               let dst = place_of lhs in
               (match dst with
                | PMem (Ir2.Global _, _, _) ->
                    Semant.fail ~loc:(Some lhs.loc) "cannot assign to a const"
                | _ -> store_place dst src (words_of ty)))

      | Expr e -> ignore (expr e)

      | If (c, yes, None) ->
          let sc = expr c in
          let l_then = fresh_label () in
          let l_end = fresh_label () in
          emit_t (Ir2.Branch (sc, l_then, l_end));
          emit_l l_then;
          stmt yes;
          emit_l l_end

      | If (c, yes, Some no) ->
          let sc = expr c in
          let l_then = fresh_label () in
          let l_else = fresh_label () in
          let l_end = fresh_label () in
          emit_t (Ir2.Branch (sc, l_then, l_else));
          emit_l l_then;
          stmt yes;
          emit_t (Ir2.Jump l_end);
          emit_l l_else;
          stmt no;
          emit_l l_end

      | While (c, body) ->
          let l_head = fresh_label () in
          let l_body = fresh_label () in
          let l_end = fresh_label () in
          emit_l l_head;
          let sc = expr c in
          emit_t (Ir2.Branch (sc, l_body, l_end));
          emit_l l_body;
          in_loop l_end l_head (fun () -> stmt body);
          emit_t (Ir2.Jump l_head);
          emit_l l_end

      | For (v, a, b, body) ->
          let vi = Hashtbl.find info.Semant.slots v in
          let sa = expr a in
          let sb = expr b in
          let limit = fresh 1 in               (* 上限は一度だけ評価し、コピーして固定する *)
          emit_i (Ir2.Move (vi, sa));
          emit_i (Ir2.Move (limit, sb));
          let l_head = fresh_label () in
          let l_body = fresh_label () in
          let l_step = fresh_label () in
          let l_end = fresh_label () in
          emit_l l_head;
          let c = bin Ir2.Lt vi limit in
          emit_t (Ir2.Branch (c, l_body, l_end));
          emit_l l_body;
          in_loop l_end l_step (fun () -> stmt body);
          emit_l l_step;
          emit_i (Ir2.Bin (Ir2.Add, vi, vi, const_i32 1l));
          emit_t (Ir2.Jump l_head);
          emit_l l_end

      | Break ->
          (match !breaks with
           | l :: _ -> emit_t (Ir2.Jump l)
           | [] -> Semant.fail "break outside of a loop")
      | Continue ->
          (match !continues with
           | l :: _ -> emit_t (Ir2.Jump l)
           | [] -> Semant.fail "continue outside of a loop")

      | Return None -> emit_t (Ir2.Ret [])
      | Return (Some x) ->
          let s = expr x in
          let w = words_of info.Semant.ret_type in
          emit_t (Ir2.Ret (List.init w (fun i -> s + i)))
    in

    stmt info.Semant.body;
    (* 末尾に終端がなければ blocks_of_items が Ret [] を補う *)
    { Ir2.name = info.Semant.fn_name;
      params = List.init info.Semant.param_words (fun i -> i);   (* 引数は vreg 0, 1, ... *)
      ret_words = words_of info.Semant.ret_type;
      nvregs = !next_vreg;
      arrays = List.map (fun (_, (id, bytes)) -> (id, bytes)) arrays;
      blocks = Ir2.blocks_of_items (List.rev !items) }
  in

  (* 関数を先に全部変換してから str_consts を読む(評価順に注意) *)
  let funcs =
    Hashtbl.fold (fun _ f acc -> f :: acc) ctx.Semant.functions []
    |> List.sort (fun a b -> compare a.Semant.fn_name b.Semant.fn_name)
    |> List.map compile_function
  in
  let consts =
    Hashtbl.fold (fun n (_, cv) acc -> (n, words_of_const cv) :: acc) ctx.Semant.consts []
    |> List.sort (fun (a, _) (b, _) -> compare a b)
  in
  { Ir2.consts = consts @ List.rev !str_consts; funcs }