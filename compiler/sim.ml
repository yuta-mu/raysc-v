open Lexer

let main () =
  (* ファイルを開く *)
  let cin =
    if Array.length Sys.argv > 1
    then open_in Sys.argv.(1)
    else stdin in
    let lexbuf = Lexing.from_channel cin in
       (* 生成コード用ファイルtmp.sをオープン *)
                                
          (* コード生成 *)
          let code = Emitter.trans_prog (Parser.prog Lexer.lexer lexbuf) in
             (* 生成コードの書出しとファイルのクローズ *)
             print_string code   
                            
let error msg = prerr_string (msg ^ "\n"); exit 1
let _ = try main () with 
         Parsing.Parse_error -> error "parser error"
       | Table.No_such_symbol x -> error ("no such symbol: \""^x^"\"\n")
       | Semant.TypeErr s -> error s
       | Semant.Err s -> error s
       | Table.SymErr s -> error s