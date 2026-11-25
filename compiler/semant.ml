open Ast

exception Error of string

let fail ?(loc=None) msg =
  match loc with
  | Some p -> raise (Error (Printf.sprintf "%s:%d:%d: %s" p.Lexing.pos_fname p.Lexing.pos_lnum
      (p.Lexing.pos_cnum - p.Lexing.pos_bol + 1) msg))
  | None -> raise (Error msg)

type fn_info = {
  fn_name : string;
  params : param list;
  ret_type : typ;
  body : stmt;
  slots : (string, int) Hashtbl.t;       (* 変数名 -> 開始ワードオフセット *)
  slot_types : (string, typ) Hashtbl.t;  (* 変数名 -> 型 *)
  total_frame_words : int;
  param_words : int;
  is_stdlib : bool;
}

type context = {
  consts : (string, typ * const_value) Hashtbl.t;
  structs : (string, field_decl list) Hashtbl.t;
  functions : (string, fn_info) Hashtbl.t;
  global_names : (string, string) Hashtbl.t;
}

let builtins =
  ["print"; "vec3"; "__hw_binop"; "__hw_unop"; "__any"]
  @ List.map (fun b -> b.Builtins.name) Builtins.all_builtins

let is_scalar = function
  | I32 | Q16 | Bool | Any -> true
  | _ -> false

let type_compatible t1 t2 =
  match t1, t2 with
  | Any, t | t, Any -> is_scalar t
  | _ -> t1 = t2

(* Binary で Any が絡んだときの代表型を決める *)
let unify_scalar t1 t2 =
  match t1, t2 with
  | Any, Any -> Some I32
  | Any, t | t, Any when is_scalar t -> Some t
  | t1, t2 when t1 = t2 -> Some t1
  | _ -> None

let rec type_words structs = function
  | I32 | Q16 | Bool | Any -> 1
  | Vec3 -> 3
  | Struct n ->
      let fields = Hashtbl.find structs n in
      List.fold_left (fun acc f -> acc + type_words structs f.field_type) 0 fields
  | Array (t, n) -> n * type_words structs t
  | Void -> 0

let field_offset structs struct_name fld_name =
  let fields = Hashtbl.find structs struct_name in
  let rec loop off = function
    | [] -> failwith ("unknown field: " ^ fld_name)
    | f :: rest ->
        if f.field_name = fld_name then off
        else loop (off + type_words structs f.field_type) rest
  in
  loop 0 fields

let rec resolve_type structs t =
  match t with
  | Struct name -> if Hashtbl.mem structs name then t else fail ("unknown struct type '" ^ name ^ "'")
  | Array (ty, n) ->
      if n <= 0 then fail "array length must be positive";
      Array (resolve_type structs ty, n)
  | x -> x

let rec const_eval structs expected e =
  let error msg = fail ~loc:(Some e.loc) msg in
  match e.desc with
  | Literal (LI32 x) when expected = I32 -> CVI32 x
  | Literal (LChar x) when expected = I32 -> CVI32 x
  | Literal (LQ16 x) when expected = Q16 -> CVQ16 x
  | Literal (LBool b) when expected = Bool -> CVBool b
  | Call ("vec3", [x; y; z]) when expected = Vec3 ->
      let cx = match const_eval structs Q16 x with CVQ16 v -> v | _ -> assert false in
      let cy = match const_eval structs Q16 y with CVQ16 v -> v | _ -> assert false in
      let cz = match const_eval structs Q16 z with CVQ16 v -> v | _ -> assert false in
      CVVec3 (cx, cy, cz)
  | Call (name, args) when (match expected with Struct n -> n = name | _ -> false) ->
      let fields = Hashtbl.find structs name in
      if List.length args <> List.length fields then error ("struct constructor '" ^ name ^ "' parameter mismatch");
      CVStruct (name, List.map2 (fun f arg -> f.field_name, const_eval structs f.field_type arg) fields args)
  | Call ("__array__", xs) ->
      (match expected with
       | Array (elem_ty, count) ->
           if List.length xs <> count then error (Printf.sprintf "array constant expects %d elements, got %d" count (List.length xs));
           CVArray (List.map (const_eval structs elem_ty) xs)
       | _ -> error "array literal requires array type")
  | _ -> error "constant initializer must be composed of literals only"

let analyze ~stdlib user =
  let program = stdlib @ user in
  let global_names = Hashtbl.create 32 in
  let add_global n what =
    if Hashtbl.mem global_names n then fail ("duplicate global name '" ^ n ^ "'");
    Hashtbl.add global_names n what
  in
  List.iter (fun n -> add_global n "builtin") builtins;

  let structs = Hashtbl.create 16 in
  let consts = Hashtbl.create 16 in
  let functions = Hashtbl.create 16 in

  List.iter (function
    | StructDecl (name, fields) ->
        add_global name "struct";
        List.iter (fun f ->
          match f.field_type with
          | Array _ -> fail ("struct field cannot be an array: " ^ f.field_name)
          | Void -> fail "struct field cannot be void"
          | _ -> ()
        ) fields;
        Hashtbl.add structs name fields
    | _ -> ()
  ) program;

  List.iter (function
    | Const (name, ty, expr) ->
        add_global name "const";
        let rty = resolve_type structs ty in
        let cv = const_eval structs rty expr in
        Hashtbl.add consts name (rty, cv)
    | _ -> ()
  ) program;

  let register_func ~is_stdlib = function
    | Function (name, ps, ret, body) ->
        add_global name "function";
        (match ret with Array _ -> fail "functions cannot return arrays" | _ -> ());
        List.iter (fun p -> match p.param_type with Array _ -> fail "function parameters cannot be arrays" | _ -> ()) ps;
        let slots = Hashtbl.create 32 in
        let slot_types = Hashtbl.create 32 in
        let curr_word = ref 0 in

        let add_var n ty =
          let rty = resolve_type structs ty in
          if Hashtbl.mem slots n then fail ("duplicate variable '" ^ n ^ "'");
          if Hashtbl.mem global_names n then fail ("local '" ^ n ^ "' shadows global");
          let off = !curr_word in
          curr_word := !curr_word + type_words structs rty;
          Hashtbl.add slots n off;
          Hashtbl.add slot_types n rty;
        in

        List.iter (fun p -> add_var p.param_name p.param_type) ps;
        let param_words = !curr_word in

        let rec collect_vars = function
          | Block xs -> List.iter collect_vars xs
          | Let (n, t, _) -> add_var n t
          | If (_, a, b) -> collect_vars a; Option.iter collect_vars b
          | While (_, b) -> collect_vars b
          | For (id, _, _, b) -> add_var id I32; collect_vars b
          | _ -> ()
        in
        collect_vars body;

        let info = {
          fn_name = name; params = ps; ret_type = ret; body;
          slots; slot_types; total_frame_words = !curr_word;
          param_words;
          is_stdlib;
        } in
        Hashtbl.add functions name info
    | _ -> ()
  in
  List.iter (register_func ~is_stdlib:true) stdlib;
  List.iter (register_func ~is_stdlib:false) user;

  if not (Hashtbl.mem functions "main") then fail "missing function 'main'";
  let main_fn = Hashtbl.find functions "main" in
  if main_fn.params <> [] || main_fn.ret_type <> Void then fail "main must have signature 'fn main() -> void'";

  let ctx = { consts; structs; functions; global_names } in

  Hashtbl.iter (fun _ info ->
    let rec infer e =
      let error msg = fail ~loc:(Some e.loc) msg in
      match e.desc with
      | Literal (LI32 _) | Literal (LChar _) -> I32
      | Literal (LQ16 _) -> Q16
      | Literal (LBool _) -> Bool
      | Literal (LString _) -> Void
      | Variable n ->
          (match Hashtbl.find_opt info.slot_types n with
           | Some t -> t
           | None -> (match Hashtbl.find_opt consts n with Some (t, _) -> t | None -> error ("unknown variable '" ^ n ^ "'")))
      | Unary (Neg, x) ->
          let t = infer x in if t = I32 || t = Q16 || t = Vec3 then t else error "unary minus requires i32, q16 or vec3"
      | Unary (Not, x) ->
          let t = infer x in
          if type_compatible t Bool then Bool else error "not requires bool"
      | Binary (Mul, a, b) ->
          let ta = infer a and tb = infer b in
          (match ta, tb with
           | I32, I32 -> I32
           | Q16, Q16 -> Q16
           | Q16, I32 -> Q16
           | I32, Q16 -> Q16
           | Vec3, Q16 -> Vec3
           | Q16, Vec3 -> Vec3
           | _ -> error (Printf.sprintf "multiplication not supported for %s and %s" (typ_to_string ta) (typ_to_string tb)))
      | Binary (Dot, a, b) ->
          let ta = infer a and tb = infer b in
          if ta = Vec3 && tb = Vec3 then Q16 else error "dot product requires two vec3 operands"
      | Binary (Had, a, b) ->
          let ta = infer a and tb = infer b in
          if ta = Vec3 && tb = Vec3 then Vec3 else error "Hadamard product requires two vec3 operands"
      | Binary ((Shl | Shr), a, b) ->
          let ta = infer a and tb = infer b in
          (match ta, tb with
           | (I32 | Q16 | Vec3 | Any) as t, (I32 | Any) ->
               if t = Any then I32 else t
           | _, (I32 | Any) -> error "left operand of shift must be i32, q16, or vec3"
           | _, _ -> error "right operand of shift must be i32")
      | Binary (op, a, b) ->
          let ta = infer a and tb = infer b in
          let t =
            match unify_scalar ta tb with
            | Some t -> t
            | None -> error (Printf.sprintf "type mismatch: %s and %s" (typ_to_string ta) (typ_to_string tb))
          in
          (match op, t with
           | (Add | Sub), (I32 | Q16 | Vec3) -> t
           | (Div | Mod), I32 -> I32
           | (BitAnd | BitOr | BitXor), (I32 | Q16) -> t
           | (Eq | Ne), (I32 | Q16 | Bool) -> Bool
           | (Lt | Le | Gt | Ge), (I32 | Q16) -> Bool
           | (And | Or), Bool -> Bool
           | (Div | Mod), Q16 -> error "division/modulo not defined for q16"
           | _ -> error "operator not supported for type")
      | Call ("print", [x]) ->
          (match x.desc with Literal (LString _) -> Void | _ -> error "print takes a string literal directly")
      | Call ("vec3", [x; y; z]) ->
          if infer x = Q16 && infer y = Q16 && infer z = Q16 then Vec3 else error "vec3 expects three q16 components"
      | Call ("__hw_binop", args) ->
          if not info.is_stdlib then
            error "'__hw_binop' is only allowed in stdlib";
          (match args with
           | [{ desc = Literal (LString op_name); _ }; a; b] ->
               if Builtins.lookup_hw_binop op_name = None then
                 error ("unknown hw_binop '" ^ op_name ^ "'");
               ignore (infer a);
               ignore (infer b);
               Any
           | _ -> error "__hw_binop expects (string_literal, a, b)")
      | Call ("__hw_unop", args) ->
          if not info.is_stdlib then
            error "'__hw_unop' is only allowed in stdlib";
          (match args with
           | [{ desc = Literal (LString op_name); _ }; a] ->
               if Builtins.lookup_hw_unop op_name = None then
                 error ("unknown hw_unop '" ^ op_name ^ "'");
               ignore (infer a);
               Any
           | _ -> error "__hw_unop expects (string_literal, a)")
      | Call ("__any", args) ->
          if not info.is_stdlib then
            error "'__any' is only allowed in stdlib";
          (match args with
           | [a] ->
               let ta = infer a in
               if not (is_scalar ta) then
                 error "__any expects a scalar value";
               Any
           | _ -> error "__any expects 1 argument")
      | Call (n, args) ->
          (match Builtins.lookup n with
           | Some b ->
               let ats = List.map infer args in
               if List.length ats <> List.length b.Builtins.param_types then
                 error ("builtin '" ^ n ^ "' argument count mismatch");
               List.iter2
                 (fun got expected ->
                    if not (type_compatible got expected) then
                      error ("builtin '" ^ n ^ "' argument type mismatch"))
                 ats b.Builtins.param_types;
               b.Builtins.ret_type
           | None ->
               if (not info.is_stdlib) && String.length n >= 2 && String.sub n 0 2 = "__" then
                 error ("internal function '" ^ n ^ "' cannot be called from user code");
               (match Hashtbl.find_opt structs n with
                | Some fields ->
                    let ats = List.map infer args in
                    if List.length ats <> List.length fields then error "constructor parameter count mismatch";
                    List.iter2 (fun got f -> if not (type_compatible got f.field_type) then error "field type mismatch") ats fields;
                    Struct n
                | None ->
                    (match Hashtbl.find_opt functions n with
                     | Some f ->
                         let ats = List.map infer args in
                         if List.length ats <> List.length f.params then error "function argument count mismatch";
                         List.iter2 (fun got p -> if not (type_compatible got p.param_type) then error "argument type mismatch") ats f.params;
                         f.ret_type
                     | None -> error ("unknown function or constructor '" ^ n ^ "'"))))
      | Field (x, fld) ->
          (match infer x with
           | Vec3 when fld = "x" || fld = "y" || fld = "z" -> Q16
           | Struct n ->
               let fields = Hashtbl.find structs n in
               (match List.find_opt (fun f -> f.field_name = fld) fields with
                | Some f -> f.field_type
                | None -> error ("unknown field '" ^ fld ^ "' in struct " ^ n))
           | _ -> error "field access on non-struct/vec3")
      | Index (x, idx) ->
          if infer idx <> I32 then error "array index must be i32";
          (match infer x with Array (t, _) -> t | _ -> error "indexing on non-array")
    in
    let rec check_stmt = function
      | Block xs -> List.iter check_stmt xs
      | Let (n, _ty, init) ->
          Option.iter (fun e ->
            let te = infer e in
            let expected = Hashtbl.find info.slot_types n in
            if not (type_compatible te expected) then fail ~loc:(Some e.loc) "let initializer type mismatch"
          ) init
      | Assign (lhs, rhs) ->
          let lt = infer lhs and rt = infer rhs in
          if not (type_compatible lt rt) then fail ~loc:(Some rhs.loc) "assignment type mismatch";
          (match lhs.desc with
           | Variable n ->
               let is_param = List.exists (fun p -> p.param_name = n) info.params in
               if is_param then fail ~loc:(Some lhs.loc) "function parameters are read-only"
           | _ -> ())
      | Expr e -> ignore (infer e)
      | If (c, a, b) ->
          if not (type_compatible (infer c) Bool) then
            fail ~loc:(Some c.loc) "if condition must be bool";
          check_stmt a; Option.iter check_stmt b
      | While (c, b) ->
          if not (type_compatible (infer c) Bool) then
            fail ~loc:(Some c.loc) "while condition must be bool";
          check_stmt b
      | For (_, a, b, body) ->
          if infer a <> I32 || infer b <> I32 then fail "for bounds must be i32";
          check_stmt body
      | Break | Continue -> ()
      | Return None ->
          if info.ret_type <> Void then fail "non-void function must return a value"
      | Return (Some e) ->
          if not (type_compatible (infer e) info.ret_type) then fail ~loc:(Some e.loc) "return value type mismatch"
    in
    check_stmt info.body
  ) functions;
  ctx

let infer_expr ctx info e =
  let rec infer e = match e.desc with
    | Literal (LI32 _) | Literal (LChar _) -> I32
    | Literal (LQ16 _) -> Q16
    | Literal (LBool _) -> Bool
    | Literal (LString _) -> Void
    | Variable n ->
        (match Hashtbl.find_opt info.slot_types n with
         | Some t -> t
         | None -> fst (Hashtbl.find ctx.consts n))
    | Unary (Neg, x) -> infer x       (* 修正: e ではなく x を再帰呼び出し *)
    | Unary (Not, _) -> Bool
    | Binary (Mul, a, b) ->
        let ta = infer a and tb = infer b in
        (match ta, tb with
         | Vec3, Q16 | Q16, Vec3 -> Vec3
         | Q16, Q16 | Q16, I32 | I32, Q16 -> Q16
         | I32, I32 -> I32
         | _ -> assert false)
    | Binary (Dot, _, _) -> Q16       (* 内積の結果型は Q16 *)
    | Binary ((Eq | Ne | Lt | Le | Gt | Ge | And | Or), _, _) -> Bool
    | Binary (_, a, _) -> infer a
    | Call ("vec3", _) -> Vec3
    | Call ("print", _) -> Void
    | Call ("__hw_binop", _) | Call ("__hw_unop", _) | Call ("__any", _) -> Any
    | Call (n, _) ->
        (match Builtins.lookup n with
         | Some b -> b.Builtins.ret_type
         | None ->
             (match Hashtbl.find_opt ctx.structs n with
              | Some _ -> Struct n
              | None -> (Hashtbl.find ctx.functions n).ret_type))
    | Field (x, fld) ->
        (match infer x with
         | Vec3 -> Q16
         | Struct n ->
             (List.find (fun f -> f.field_name = fld) (Hashtbl.find ctx.structs n)).field_type
         | _ -> assert false)
    | Index (x, _) ->
        (match infer x with
         | Array (t, _) -> t
         | _ -> assert false)
  in
  infer e

