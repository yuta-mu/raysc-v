type vreg = int          (*仮想レジスタ番号*)
type label = int         (*基本ブロック番号*)

(*二項演算*)
type binop =
  | Add | Sub
  | Mul                  
  | QMul                 
  | Div | Rem           
  | Shl | Sra            
  | And | Or | Xor
  | Eq | Ne | Lt | Le | Gt | Ge   (* 符号付き比較。結果は 0 か 1(bool) *)

(*単項演算*)
type unop =
  | Neg                  (*反転*)
  | Not                  (*boolの否定*)

(*平方根,平方根の逆数,逆数*)
type intrinsic = Sqrt | Rsqrt | Rcp

(*どの配列かを表す型*)
type region = 
  | Local of int   (*局所配列*)
  | Global of string   (*const*)

(*基本ブロック内の命令*)
type instr =
  | Const of vreg * int32                     (*d=定数*)
  | Move   of vreg * vreg                       (*d=a(コピー)*)
  | Bin   of binop * vreg * vreg * vreg        (*二項演算*)
  | Un    of unop * vreg * vreg                (*単項*)
  | Intr  of intrinsic * vreg * vreg           (*d=sqrt(a)など*)
  (*メモリの命令 配列を読み書き*)
  | AddrLocal  of vreg * int   (*d = 局所配列の先頭アドレス*)
  | AddrGlobal of vreg * string  (*d = constの先頭アドレス*)
  | Load  of vreg * region * vreg * int                 (*d = mem[addr + ofs]*)
  | Store of int * vreg * int * vreg                    (*mem[addr + ofs] = src(書けるのは局所配列だけ。int は局所配列の番号)*)
  (*関数呼び出し*)
  | Call  of vreg list * string * vreg list    (*戻り値を入れる仮想レジスタのリスト,関数名,引数の仮想レジスタ*)
  (*MMIO呼び出し(仕様 §11):消去・並べ替え禁止。他の命令もこの前後を越えて動かさない
    print("...") は translate で const(1文字1ワード、末尾 0)と Load / Bprint のループに分解する*)
  | Bprint of vreg                             (*下位8ビットをUARTに送る*)
  | Cycles of vreg                             (*d = cycles()*)

(*基本ブロックの終端*)
type terminator =
  | Jump   of label                            (*無条件ジャンプ*)
  | Branch of vreg * label * label             (*分岐*)
  | Ret    of vreg list                        (*戻り値*)

type block = {
  label : label;                               (*ブロックの番号*)
  body  : instr list;                          (*命令の並び*)
  term  : terminator;                          (*最後の1命令*)
}

type func = {
  name   : string;                   (*関数名*)
  params : vreg list;                (*引数を受け取る仮想レジスタ*)
  ret_words : int;                   (*戻り値のワード数*)
  nvregs : int;                      (*使っている仮想レジスタの数*)
  arrays : (int * int) list;         (*局所配列:(番号, バイト数)*)
  blocks : block list;               (*基本ブロックの並び*)
}

type program = {
  consts : (string * int32 list) list;   (* const:名前とワード列*)
  funcs  : func list;
}



(* ダンプ(--dump-ir) *)
let string_of_binop = function
  | Add -> "add" | Sub -> "sub" | Mul -> "mul" | QMul -> "qmul"
  | Div -> "div" | Rem -> "rem" | Shl -> "shl" | Sra -> "sra"
  | And -> "and" | Or -> "or" | Xor -> "xor"
  | Eq -> "eq" | Ne -> "ne" | Lt -> "lt" | Le -> "le" | Gt -> "gt" | Ge -> "ge"

let string_of_unop = function Neg -> "neg" | Not -> "not"

let string_of_intrinsic = function Sqrt -> "sqrt" | Rsqrt -> "rsqrt" | Rcp -> "rcp"

let v n = "v" ^ string_of_int n
let l n = "L" ^ string_of_int n
let vs xs = String.concat ", " (List.map v xs)

let string_of_region = function
  | Local id -> "array" ^ string_of_int id
  | Global s -> s

let string_of_instr = function
  | Const (d, n)        -> Printf.sprintf "%s = const %ld" (v d) n
  | Move (d, a)         -> Printf.sprintf "%s = %s" (v d) (v a)
  | Bin (op, d, a, b)   -> Printf.sprintf "%s = %s %s, %s" (v d) (string_of_binop op) (v a) (v b)
  | Un (op, d, a)       -> Printf.sprintf "%s = %s %s" (v d) (string_of_unop op) (v a)
  | Intr (f, d, a)      -> Printf.sprintf "%s = %s %s" (v d) (string_of_intrinsic f) (v a)
  | AddrLocal (d, id)   -> Printf.sprintf "%s = &array%d" (v d) id
  | AddrGlobal (d, s)   -> Printf.sprintf "%s = &%s" (v d) s
  | Load (d, r, a, ofs) -> Printf.sprintf "%s = load %s[%s + %d]" (v d) (string_of_region r) (v a) ofs
  | Store (id, a, ofs, s)-> Printf.sprintf "store array%d[%s + %d] = %s" id (v a) ofs (v s)
  | Call ([], f, args)  -> Printf.sprintf "call %s(%s)" f (vs args)
  | Call (rs, f, args)  -> Printf.sprintf "%s = call %s(%s)" (vs rs) f (vs args)
  | Bprint a            -> Printf.sprintf "bprint %s" (v a)
  | Cycles d            -> Printf.sprintf "%s = cycles" (v d)

let string_of_term = function
  | Jump t              -> Printf.sprintf "jump %s" (l t)
  | Branch (c, t, f)    -> Printf.sprintf "branch %s ? %s : %s" (v c) (l t) (l f)
  | Ret []              -> "ret"
  | Ret xs              -> Printf.sprintf "ret %s" (vs xs)

let dump_func oc f =
  Printf.fprintf oc "fn %s(%s) -> %d words  [vregs=%d" f.name (vs f.params) f.ret_words f.nvregs;
  List.iter (fun (id, bytes) -> Printf.fprintf oc ", array%d=%dB" id bytes) f.arrays;
  Printf.fprintf oc "]\n";
  List.iter
    (fun b ->
       Printf.fprintf oc "%s:\n" (l b.label);
       List.iter (fun i -> Printf.fprintf oc "    %s\n" (string_of_instr i)) b.body;
       Printf.fprintf oc "    %s\n" (string_of_term b.term))
    f.blocks;
  Printf.fprintf oc "\n"

let dump_program oc p =
  List.iter
    (fun (name, words) ->
       Printf.fprintf oc "const %s = [%s]\n" name
         (String.concat ", " (List.map Int32.to_string words)))
    p.consts;
  if p.consts <> [] then Printf.fprintf oc "\n";
  List.iter (dump_func oc) p.funcs

(* 平らな列 → 基本ブロック(C-4 の translate 用) *)
(* translate はまず、命令・ラベル・終端を 1 本の列に並べる *)
type item =
  | I of instr          (* 普通の命令 *)
  | L of label          (* ラベル:ここから新しいブロックが始まる *)
  | T of terminator     (* 終端:ここでブロックが終わる *)

(* 列をラベルのところで切って、ブロックのリストにする。
   - 列の先頭は必ず L(入口のラベル)にすること
   - 終端なしで次の L に来たら、そのラベルへの Jump を補う(落ちてくる場合)
   - 終端のあと、次の L までの命令は実行されないので捨てる
   - 最後のブロックに終端がなければ Ret [] を補う *)
let blocks_of_items (items : item list) : block list =
  let rec go cur acc items =
    (* cur = Some (ラベル, 命令の逆順リスト):作りかけのブロック。None = 閉じている *)
    let close term =
      match cur with
      | Some (lab, body) -> { label = lab; body = List.rev body; term } :: acc
      | None -> acc
    in
    match items, cur with
    | [], _ -> List.rev (close (Ret []))
    | L lab :: rest, _ -> go (Some (lab, [])) (close (Jump lab)) rest
    | I i :: rest, Some (lab, body) -> go (Some (lab, i :: body)) acc rest
    | I _ :: rest, None -> go None acc rest
    | T t :: rest, Some _ -> go None (close t) rest
    | T _ :: rest, None -> go None acc rest
  in
  match items with
  | L _ :: _ -> go None [] items
  | _ -> invalid_arg "blocks_of_items: the item list must start with L"

(*命令が書き込む vreg*)
let defs = function
  | Const (d, _) | Move (d, _) | Bin (_, d, _, _) | Un (_, d, _) | Intr (_, d, _)
  | AddrLocal (d, _) | AddrGlobal (d, _) | Load (d, _, _, _) | Cycles d -> [d]
  | Call (rs, _, _) -> rs 
  | Store _ | Bprint _ -> []

(*命令が読み込む vreg*)
let uses = function
  | Const _ | AddrLocal _ | AddrGlobal _ | Cycles _ -> []
  | Move (_, a) | Un (_, _, a) | Intr (_, _, a) | Load (_, _, a, _) | Bprint a -> [a]
  | Bin (_, _, a, b) -> [a; b]
  | Store (_, a, _, s) -> [a; s]
  | Call (_, _, args) -> args

(*終端が読み込む vreg*)
let term_uses = function
  | Jump _ -> []
  | Branch (c, _, _) -> [c]
  | Ret vs -> vs

(*終端が指すラベル,次に進むかもしれないブロック*)
let successors = function
  | Jump l -> [l]
  | Branch (_, t, f) -> [t; f]
  | Ret _ -> []

(*副作用の判定*)
let has_side_effect = function
  | Bprint _ | Cycles _ | Call _ | Store _ -> true
  | _ -> false

(*Storeがどの配列に書き込んでいるか*)
let writes_mem = function
  | Store (id, _, _, _) -> Some (Local id)
  | _ -> None

(*Loadがどの配列から読んでいるか*)
let reads_mem = function
  | Load (_, r, _, _) -> Some r
  | _ -> None