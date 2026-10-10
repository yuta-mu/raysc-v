{
open Parser

exception Error of string

let fail lexbuf msg =
  let p = Lexing.lexeme_start_p lexbuf in
  raise (Error (Printf.sprintf "%s:%d:%d: %s" p.Lexing.pos_fname p.Lexing.pos_lnum
    (p.Lexing.pos_cnum - p.Lexing.pos_bol + 1) msg))

let unescape_string s =
  let b = Buffer.create (String.length s) in
  let rec loop i =
    if i >= String.length s - 1 then Buffer.contents b
    else if s.[i] = '\\' then begin
      if i + 1 >= String.length s - 1 then failwith "bad string escape";
      let c = match s.[i + 1] with
        | 'n' -> '\n' | 'r' -> '\r' | 't' -> '\t' | '0' -> '\000'
        | '\\' -> '\\' | '"' -> '"' | '\'' -> '\''
        | c -> c
      in Buffer.add_char b c; loop (i + 2)
    end else (Buffer.add_char b s.[i]; loop (i + 1))
  in loop 1

let parse_char s =
  let body = String.sub s 1 (String.length s - 2) in
  let c = match body with
    | "\\n" -> '\n' | "\\r" -> '\r' | "\\t" -> '\t' | "\\0" -> '\000'
    | "\\\\" -> '\\' | "\\'" -> '\''
    | x when String.length x = 1 -> x.[0]
    | _ -> failwith "char literal must contain one ASCII character"
  in
  Int32.of_int (Char.code c)
}

let digit = ['0'-'9']
let hex = ['0'-'9' 'a'-'f' 'A'-'F']
let ident_start = ['a'-'z' 'A'-'Z' '_']
let ident_char = ['a'-'z' 'A'-'Z' '0'-'9' '_']
let qlit = digit+ '.' digit+
let intlit = "0x" hex+ | "0X" hex+ | digit+
let string_char = [^ '"' '\\' '\n']
let char_simple = [^ '\'' '\\' '\n']

rule token = parse
  | [' ' '\t' '\r'] { token lexbuf }
  | '\n' { Lexing.new_line lexbuf; token lexbuf }
  | "//" [^ '\n']* { token lexbuf }
  | "/*" { comment lexbuf; token lexbuf }
  | "fn" { FN }
  | "let" { LET }
  | "const" { CONST }
  | "struct" { STRUCT }
  | "if" { IF }
  | "else" { ELSE }
  | "while" { WHILE }
  | "for" { FOR }
  | "in" { IN }
  | "break" { BREAK }
  | "continue" { CONTINUE }
  | "return" { RETURN }
  | "true" { TRUE }
  | "false" { FALSE }
  | "i32" { I32_T }
  | "q16" { Q16_T }
  | "bool" { BOOL_T }
  | "vec3" { VEC3_T }
  | "void" { VOID_T }
  | "<.>" { DOTPROD }
  | "->" { ARROW }
  | ".." { DOTDOT }
  | "==" { EQ }
  | "!=" { NE }
  | "<=" { LE }
  | ">=" { GE }
  | "<<" { SHL }
  | ">>" { SHR }
  | "&&" { LAND }
  | "||" { LOR }
  | "=" { ASSIGN }
  | "+" { PLUS }
  | "-" { MINUS }
  | "*" { STAR }
  | "/" { SLASH }
  | "%" { PERCENT }
  | "&" { BAND }
  | "|" { BOR }
  | "^" { BXOR }
  | "!" { NOT }
  | "<" { LT }
  | ">" { GT }
  | "(" { LPAREN }
  | ")" { RPAREN }
  | "{" { LBRACE }
  | "}" { RBRACE }
  | "[" { LBRACKET }
  | "]" { RBRACKET }
  | "," { COMMA }
  | ";" { SEMI }
  | ":" { COLON }
  | "." { DOT }
  | qlit as s { try QLIT (Numeric.parse_q16 s) with _ -> fail lexbuf ("invalid q16 literal: " ^ s) }
  | intlit as s { try INT (Numeric.parse_i32 s) with _ -> fail lexbuf ("invalid integer literal: " ^ s) }
  | '"' (string_char | '\\' ['n' 'r' 't' '0' '\\' '"' '\''])* '"' as s
      { try STRING (unescape_string s) with _ -> fail lexbuf "invalid string escape" }
  | '\'' (char_simple | '\\' ['n' 'r' 't' '0' '\\' '\''] ) '\'' as s
      { try CHAR (parse_char s) with _ -> fail lexbuf "invalid character literal" }
  | ident_start ident_char* as s { IDENT s }
  | eof { EOF }
  | _ as c { fail lexbuf (Printf.sprintf "unexpected character %C" c) }

and comment = parse
  | "*/" { () }
  | '\n' { Lexing.new_line lexbuf; comment lexbuf }
  | eof { fail lexbuf "unterminated block comment" }
  | _ { comment lexbuf }

