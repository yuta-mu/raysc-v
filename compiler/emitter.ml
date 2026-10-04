open Ast
open Printf
open Types
open Table
open Semant

let label = ref 0
let incLabel() = (label := !label+1; !label)

(* str を n 回コピーする *)
let rec nCopyStr n str =
    if n > 0 then str ^ (nCopyStr (pred n) str) else ""

(* 12bit即値に収まらない場合はt6経由で加算する *)
let addImmTo reg n =
  if n >= -2048 && n <= 2047 then
    sprintf "\taddi %s, %s, %d\n" reg reg n
  else
    sprintf "\tli t6, %d\n\tadd %s, %s, t6\n" n reg reg

(* 呼出し時にcalleeに渡す静的リンク *)
(* 64bit(8byte)->32bit(4byte) *)
let passLink src dst = 
  if src >= dst then 
    let deltaLevel = src-dst+1 in
      "\tmv t0, s0\n"
     ^ nCopyStr deltaLevel "\tlw t0, 8(t0)\n"
     ^ "\taddi sp, sp, -4\n"
     ^ "\tsw t0, 0(sp)\n"
  else
      "\taddi sp, sp, -4\n"
    ^ "\tsw s0, 0(sp)\n"

let output = ref ""

(* プロローグとエピローグ *)
let prologue = "\taddi sp, sp, -8\n"
             ^ "\tsw s0, 0(sp)\n"      (* フレームポインタの保存 *)
             ^ "\tsw ra, 4(sp)\n"
             ^ "\tmv s0, sp\n"         (* フレームポインタのスタックポインタ位置への移動 *)
let epilogue = "\tmv sp, s0\n"
             ^ "\tlw ra, 4(sp)\n"
             ^ "\tlw s0, 0(sp)\n"
             ^ "\taddi sp, sp, 8\n"
             ^ "\tret\n"               (* 呼出し位置の次のアドレスへ戻る *)
(* エントリーポイントの頭 *)
let header = ".section .text\n"
           ^ ".globl _start\n"
           ^ ".equ STACK_TOP, 0x80002000\n"
           ^ ".equ UART0_BASE, 0x10000000\n"
           ^ "_start:\n"
           ^ "\tli sp, STACK_TOP\n"
           ^ "\tmv s0, sp\n"
           ^ "\tmv ra, zero\n"
(* 無限ループ *)
let loop = "_loop:\n"
         ^ "\tj _loop\n"
(* iprintのフラグと文字出力コード *)
let iprint_flag = ref false
let iprint = "_iprint:\n"
           ^ "\tli t0, UART0_BASE\n"
           ^ "\tli t1, 10\n"
           ^ "\tbgez a0, _iprepare_stack\n"
           ^ "\tli t2, '-'\n"
           ^ "\tsb t2, 0(t0)\n"
           ^ "\tneg a0, a0\n"
           ^ "_iprepare_stack:\n"
           ^ "\taddi sp, sp, -1\n"
           ^ "\tsb zero, 0(sp)\n"
           ^ "_iconvert_loop:\n"
           ^ "\tremu t2, a0, t1\n"
           ^ "\tdivu a0, a0, t1\n"
           ^ "\taddi t2, t2, '0'\n"
           ^ "\taddi sp, sp, -1\n"
           ^ "\tsb t2, 0(sp)\n"
           ^ "\tbnez a0, _iconvert_loop\n"
           ^ "_iprint_loop:\n"
           ^ "\tlb t1, 0(sp)\n"
           ^ "\taddi sp, sp, 1\n"
           ^ "\tbeqz t1, _done\n"
           ^ "\tsb t1, 0(t0)\n"
           ^ "\tj _iprint_loop\n"
(* sprintのフラグと文字出力コード *)
let sprint_flag = ref false
let sprint = "_sprint:\n"
           ^ "\tli t0, UART0_BASE\n" 
           ^ "_sprint_loop:\n"
           ^ "\tlb t1, 0(a0)\n"
           ^ "\tbeqz t1, _done\n"
           ^ "\tsb t1, 0(t0)\n"
           ^ "\taddi a0, a0, 1\n"
           ^ "\tj _sprint_loop\n"
(* iprint, sprintの終了コード *)
let doneret = "_done:\n"
            ^ "\tret\n"

(* 宣言部の処理：変数宣言->記号表への格納，関数定義->局所宣言の処理とコード生成 *)
let rec trans_dec ast nest tenv env = match ast with
   (* 関数定義の処理 *)
   FuncDec (s, l, _, block) -> 
       (* 仮引数の記号表への登録 *)
       let env' =  type_param_dec l (nest+1) tenv env in 
         (* 関数本体（ブロック）の処理 *)
         let code = trans_stmt block (nest+1) tenv env' in
             (* 関数コードの合成 *)
             output := !output ^
                 s ^ ":\n"               (* 関数ラベル *)
                 ^ prologue              (* プロローグ *)
                 ^ code                  (* 本体コード *)
                 ^ epilogue              (* エピローグ *)
   (* 変数宣言の処理 *)
 | VarDec (t,s) -> ()
   (* 変数宣言と同時に初期化をする処理 *)
 | InitVarDec(t, s, e) -> ()
   (* 型宣言の処理 *)
 | TypeDec (s,t) -> 
      let entry = tenv s in
         match entry with
             (NAME (_, ty_opt)) -> ty_opt := Some (create_ty t tenv)
           | _ -> raise (Err s)
(* 文の処理 *)
and trans_stmt ast nest tenv env = 
                 type_stmt ast env;
                 match ast with
                  (* 代入のコード：代入先フレームをsetVarで求める．*)
                     Assign (v, e) -> trans_exp e nest env
                                    ^ trans_var v nest env
                                    ^ "\tlw t1, 0(sp)\n"
                                    ^ "\taddi sp, sp, 4\n"
                                    ^ "\tsw t1, 0(t0)\n"
                   (* iprintのコード *)
                   | CallProc ("iprint", [arg]) -> 
                           (iprint_flag := true;
                            trans_exp arg nest env
                        ^  "\tlw a0, 0(sp)\n"
                        ^  "\taddi sp, sp, 4\n"
                        ^  "\tcall _iprint\n")
                   (* sprintのコード *)
                   | CallProc ("sprint", [StrExp s]) -> 
                       (sprint_flag := true;
                        let l = incLabel() in
                              (".section .rodata\n"
                            ^ sprintf "L%d:\t.string %s\n" l s
                            ^ ".section .text\n"
                            ^ sprintf "\tla a0, L%d\n" l     
                            ^ "\tcall _sprint\n"))
                  (* returnのコード *)
                  | CallProc ("return", [arg]) ->
                              trans_exp arg nest env
                            ^ "\tlw a0, 0(sp)\n"
                            ^ "\taddi sp, sp, 4\n"
                  (* 手続き呼出しのコード *)
                  | CallProc (s, el) -> 
                      let entry = env s in 
                         (match entry with
                             (FunEntry {formals=_; result=_; level=level}) -> 
                                 (* 実引数のコード *)
                                 (* 16バイト境界に調整 *)
                                 (* 64bit(8byte)->32bit(4byte) *)
                                 (match (List.length el) mod 4 with
                                      1 -> ""
                                    | 2 -> "\taddi sp, sp, -12\n"
                                    | 3 -> "\taddi sp, sp, -8\n"
                                    | _ -> "\taddi sp, sp, -4\n")
                               ^ List.fold_right  (fun  ast code -> code ^ (trans_exp ast nest env)) el "" 
                                 (* 静的リンクを渡すコード *)
                               ^  passLink nest level
                                 (* 関数の呼出しコード *)
                               ^  "\tcall " ^ s ^ "\n"
                                 (* 積んだ引数+静的リンクを降ろす *)
                               ^  sprintf "\taddi sp, sp, %d\n" ((List.length el + 3 + 3) / 4 * 16) 
                            | _ -> raise (No_such_symbol s)) 
                  (* ブロックのコード：文を表すブロックは，関数定義を無視する．*)
                  | Block (dl, sl) -> 
                       (* ブロック内宣言の処理 *)
                       let (tenv',env',addr') = type_decs dl nest tenv env in
                             List.iter (fun d -> trans_dec d nest tenv' env') dl;
                                 let inits = List.fold_right (fun d acc ->
                                    match d with
                                    | InitVarDec (_, s, e) -> Assign (Var s, e) :: acc
                                    | _ -> acc
                                ) dl [] in
                             (* フレームの拡張 *)
                             let ex_frame_size = (-addr'+16)/16*16 in
                                  (* 本体（文列）のコード生成 *)
                                  let code = List.fold_left 
                                       (fun code ast -> (code ^ trans_stmt ast nest tenv' env')) "" (inits @ sl)
                                  (* 局所変数分のフレーム拡張の付加 *)
                                  in addImmTo "sp" (-ex_frame_size)
                                   ^ code
                                   ^ addImmTo "sp" ex_frame_size
                  (* elseなしif文のコード *)
                  | If (e,s,None) -> let (condCode,l) = trans_cond e nest env in
                                                  condCode
                                                ^ trans_stmt s nest tenv env
                                                ^ sprintf "L%d:\n" l
                  (* elseありif文のコード *)
                  | If (e,s1,Some s2) -> let (condCode,l1) = trans_cond e nest env in
                                            let l2 = incLabel() in 
                                                  condCode
                                                ^ trans_stmt s1 nest tenv env
                                                ^ sprintf "\tj L%d\n" l2
                                                ^ sprintf "L%d:\n" l1
                                                ^ trans_stmt s2 nest tenv env 
                                                ^ sprintf "L%d:\n" l2
                  (* while文のコード *)
                  | While (e,s) -> let (condCode, l1) = trans_cond e nest env in
                                     let l2 = incLabel() in
                                         sprintf "L%d:\n" l2 
                                       ^ condCode
                                       ^ trans_stmt s nest tenv env
                                       ^ sprintf "\tj L%d\n" l2
                                       ^ sprintf "L%d:\n" l1
                  (* 空文 *)
                  | NilStmt -> ""
(* 参照アドレスの処理 *)
and trans_var ast nest env = match ast with
                   Var s -> let entry = env s in 
                        (match entry with
                            VarEntry {offset=offset; level=level; ty=_} -> 
                                  "\tmv t0, s0\n" 
                                ^ nCopyStr (nest-level) "\tlw t0, 8(t0)\n"
                                ^ addImmTo "t0" offset (* offsetが12bit即値を超える場合も *)
                           | _ -> raise (No_such_symbol s))
                 | IndexedVar (v, size) -> 
                            trans_exp (CallFunc("*", [IntExp 4; size])) nest env
                          ^ trans_var v nest env
                          ^ "\tlw t0, 0(t0)\n"
                          ^ "\tlw t1, 0(sp)\n"
                          ^ "\taddi sp, sp, 4\n"
                          ^ "\tadd t0, t0, t1\n"
(* 式の処理 *)
and trans_exp ast nest env = match ast with
                  (* 整数定数のコード *)
                    IntExp i -> 
                             sprintf "\tli t0, %d\n" i
                           ^ "\taddi sp, sp, -4\n"
                           ^ "\tsw t0, 0(sp)\n"
                  (* 変数参照のコード：reVarで参照フレームを求める *)
                  | VarExp v -> 
                             trans_var v nest env
                           ^ "\tlw t0, 0(t0)\n"
                           ^ "\taddi sp, sp, -4\n"
                           ^ "\tsw t0, 0(sp)\n"
                  (* +のコード *)
                  | CallFunc ("+", [left; right]) -> 
                                             trans_exp left nest env
                                           ^ trans_exp right nest env
                                           ^ "\tlw t0, 0(sp)\n"
                                           ^ "\taddi sp, sp, 4\n"
                                           ^ "\tlw t1, 0(sp)\n"
                                           ^ "\tadd t0, t1, t0\n" (* のぞき穴的最適化 *)
                                           ^ "\tsw t0, 0(sp)\n"
                  (* -のコード *)
                  | CallFunc ("-", [left; right]) ->
                                             trans_exp left nest env
                                           ^ trans_exp right nest env
                                           ^ "\tlw t0, 0(sp)\n"
                                           ^ "\taddi sp, sp, 4\n"
                                           ^ "\tlw t1, 0(sp)\n"
                                           ^ "\tsub t0, t1, t0\n" (* のぞき穴的最適化 *)
                                           ^ "\tsw t0, 0(sp)\n"
                  (* *のコード *)
                  | CallFunc ("*", [left; right]) -> 
                                             trans_exp left nest env
                                           ^ trans_exp right nest env
                                           ^ "\tlw t0, 0(sp)\n"
                                           ^ "\taddi sp, sp, 4\n"
                                           ^ "\tlw t1, 0(sp)\n"
                                           ^ "\tmul t0, t1, t0\n" (* のぞき穴的最適化 *)
                                           ^ "\tsw t0, 0(sp)\n"
                  (* /のコード *)
                  | CallFunc ("/", [left; right]) -> 
                                             trans_exp left nest env
                                           ^ trans_exp right nest env
                                           ^ "\tlw t0, 0(sp)\n"
                                           ^ "\taddi sp, sp, 4\n"
                                           ^ "\tlw t1, 0(sp)\n"
                                           ^ "\tdiv t0, t1, t0\n" (* のぞき穴的最適化 *)
                                           ^ "\tsw t0, 0(sp)\n"
                  (* %のコード *)
                  | CallFunc ("%", [left; right]) -> 
                                             trans_exp left nest env
                                           ^ trans_exp right nest env
                                           ^ "\tlw t0, 0(sp)\n"
                                           ^ "\taddi sp, sp, 4\n"
                                           ^ "\tlw t1, 0(sp)\n"
                                           ^ "\trem t0, t1, t0\n" (* のぞき穴的最適化 *)
                                           ^ "\tsw t0, 0(sp)\n"
                  (* ^のコード *)
                  | CallFunc ("^", [left; right]) ->
                                           let l_loop = incLabel () in
                                           let l_end  = incLabel () in
                                             trans_exp left nest env
                                           ^ trans_exp right nest env
                                           ^ "\tlw t0, 0(sp)\n" (* 指数 *)
                                           ^ "\taddi sp, sp, 4\n"
                                           ^ "\tlw t1, 0(sp)\n" (* 底 *)
                                           ^ "\tli t2, 1\n"
                                           ^ sprintf "L%d:\n" l_loop
                                           ^ sprintf "\tblez t0, L%d\n" l_end
                                           ^ "\tmul t2, t1, t2\n"
                                           ^ "\taddi t0, t0, -1\n" (* 指数を1減らす *)
                                           ^ sprintf "\tj L%d\n" l_loop
                                           ^ sprintf "L%d:\n" l_end
                                           ^ "\tsw t2, 0(sp)\n"
                  (* 後置インクリメント (v++) のコード生成 *)
                  | PostInc v ->
                                             trans_var v nest env
                                           ^ "\tlw t1, 0(t0)\n"
                                           ^ "\taddi sp, sp, -4\n"
                                           ^ "\tsw t1, 0(sp)\n" (* のぞき穴的最適化 *)
                                           ^ "\taddi t1, t1, 1\n"
                                           ^ "\tsw t1, 0(t0)\n" (* 1増やす *)
                  (* 三項演算子のコード *)
                  | CondExp (cond, e1, e2) ->
                                           let (condCode, l_else) = trans_cond cond nest env in
                                           let l_end = incLabel () in
                                               condCode 
                                             ^ trans_exp e1 nest env 
                                             ^ sprintf "\tj L%d\n" l_end 
                                             ^ sprintf "L%d:\n" l_else 
                                             ^ trans_exp e2 nest env 
                                             ^ sprintf "L%d:\n" l_end 
                  (* 反転のコード *)
                  | CallFunc("!",  arg::_) -> 
                                            trans_exp arg nest env
                                          ^ "\tlw t0, 0(sp)\n"
                                          ^ "\tneg t0, t0\n"
                                          ^ "\tsw t0, 0(sp)\n"
                  (* 関数呼出しのコード *)
                  | CallFunc (s, el) -> 
                                trans_stmt (CallProc(s, el)) nest initTable env 
                                (* 返戻値はa0に入れて返す *)
                              ^ "\taddi sp, sp, -4\n"
                              ^ "\tsw a0, 0(sp)\n"
                  | _ -> raise (Err "internal error")
(* 関係演算の処理 *)
and trans_cond ast nest env = match ast with
                  | CallFunc (op, left::right::_) -> 
                      (let code = 
                       (* オペランドのコード *)
                          trans_exp left nest env
                        ^ trans_exp right nest env
                       (* オペランドの値を t1，t0へ *)
                        ^ "\tlw t1, 0(sp)\n"
                        ^ "\taddi sp, sp, 4\n"
                        ^ "\tlw t0, 0(sp)\n"
                        ^ "\taddi sp, sp, 4\n" in
                          let l = incLabel () in
                             match op with
                               (* 条件と分岐の関係は，逆 *)
                                "==" -> (code ^ sprintf "\tbne t0, t1, L%d\n" l, l)
                              | "!=" -> (code ^ sprintf "\tbeq t0, t1, L%d\n" l, l)
                              | ">"  -> (code ^ sprintf "\tble t0, t1, L%d\n" l, l)
                              | "<"  -> (code ^ sprintf "\tbge t0, t1, L%d\n" l, l)
                              | ">=" -> (code ^ sprintf "\tblt t0, t1, L%d\n" l, l)
                              | "<=" -> (code ^ sprintf "\tbgt t0, t1, L%d\n" l, l)
                              | _ -> raise (Err ("unknown comparison operator: " ^ op)))
                 | _ -> raise (Err "internal error")
(* プログラム全体の生成 *)
let trans_prog ast = let code = trans_stmt ast 0 initTable initTable in
                                if !iprint_flag then output := (!output) ^ iprint else ();
                                if !sprint_flag then output := (!output) ^ sprint else ();
                                if !iprint_flag || !sprint_flag then output := (!output) ^ doneret else ();
                                header ^ code ^ loop ^ (!output)
