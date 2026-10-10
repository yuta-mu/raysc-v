(* File lexer.mll *)
{
 open Parser  
 exception No_such_symbol
 let line_number = ref 1
 let curr_tok = ref ""

 let tok t lexbuf =
   curr_tok := Lexing.lexeme lexbuf;
   t

 let print_syntax_error () =
  let line = !line_number in
  Printf.eprintf "syntax error at line %d near '%s'\n" line !curr_tok
}

let digit = ['0'-'9']
let id = ['a'-'z' 'A'-'Z' '_'] ['a'-'z' 'A'-'Z' '0'-'9']*
let comment = "//"[^'\n']*

rule lexer = parse
| digit+ as num  { tok (NUM (int_of_string num)) lexbuf }
| "if"                    { tok IF lexbuf }
| "else"                  { tok ELSE lexbuf }
| "do"                    { tok DO lexbuf }
| "while"                 { tok WHILE lexbuf }
| "for"                   { tok FOR lexbuf}
| ".."                    { tok DOTDOT lexbuf}
| "?"                     { tok QUEST lexbuf}
| ":"                     { tok COLON lexbuf}
| "sprint"                { tok SPRINT lexbuf }
| "iprint"                { tok IPRINT lexbuf }
| "int"                   { tok INT lexbuf }
| "return"                { tok RETURN lexbuf }
| "type"                  { tok TYPE lexbuf }
| "void"                  { tok VOID lexbuf }
| id as text              { tok (ID text) lexbuf }
| '\"'[^'\"']*'\"' as str { tok (STR str) lexbuf }
| '='                     { tok ASSIGN lexbuf }
| "=="                    { tok EQ lexbuf }
| "!="                    { tok NEQ lexbuf }
| '>'                     { tok GT lexbuf }
| '<'                     { tok LT lexbuf }
| ">="                    { tok GE lexbuf }
| "<="                    { tok LE lexbuf }
| '+'                     { tok PLUS lexbuf }
| '-'                     { tok MINUS lexbuf }
| '*'                     { tok TIMES lexbuf }
| '/'                     { tok DIV lexbuf }
| '%'                     { tok MOD lexbuf }
| '^'                     { tok HAT lexbuf }
| "++"                    { tok INC lexbuf }
| "+="                    { tok PLUS_ASSIGN lexbuf }
| '{'                     { tok LB lexbuf  }
| '}'                     { tok RB lexbuf  }
| '['                     { tok LS lexbuf }
| ']'                     { tok RS lexbuf }
| '('                     { tok LP lexbuf  }
| ')'                     { tok RP lexbuf  }
| ','                     { tok COMMA lexbuf }
| ';'                     { tok SEMI lexbuf }
| '\n'                    { incr line_number; lexer lexbuf}
| [' ' '\t']              { lexer lexbuf }(* eat up whitespace *) 
| comment                 { lexer lexbuf }
| eof                     { raise End_of_file }
| _                       { raise No_such_symbol }
