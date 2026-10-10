%{
open Ast
let expr loc desc = { desc; loc }
%}

%token <int32> INT QLIT CHAR
%token <string> IDENT STRING
%token TRUE FALSE
%token FN LET CONST STRUCT IF ELSE WHILE FOR IN BREAK CONTINUE RETURN
%token I32_T Q16_T BOOL_T VEC3_T VOID_T
%token LPAREN RPAREN LBRACE RBRACE LBRACKET RBRACKET
%token COMMA SEMI COLON DOT ARROW DOTDOT
%token ASSIGN PLUS MINUS STAR SLASH PERCENT
%token SHL SHR BAND BOR BXOR
%token EQ NE LT LE GT GE LAND LOR NOT DOTPROD
%token EOF

%right ASSIGN
%left LOR
%left LAND
%left BOR
%left BXOR
%left BAND
%left EQ NE
%left LT LE GT GE
%left SHL SHR
%left PLUS MINUS
%left STAR SLASH PERCENT DOTPROD
%right NOT UMINUS
%left DOT LBRACKET LPAREN

%start program
%type <Ast.program> program

%%

program:
  decls EOF { $1 }
;

decls:
  /* empty */ { [] }
| decls decl  { $1 @ [$2] }
;

decl:
  CONST IDENT COLON typ ASSIGN const_init SEMI { Const ($2, $4, $6) }
| STRUCT IDENT LBRACE fields RBRACE            { StructDecl ($2, $4) }
| FN IDENT LPAREN params_opt RPAREN ARROW typ_or_void block { Function ($2, $4, $7, $8) }
;

fields:
  IDENT COLON typ COMMA        { [{ field_name = $1; field_type = $3 }] }
| fields IDENT COLON typ COMMA { $1 @ [{ field_name = $2; field_type = $4 }] }
;

params_opt:
  /* empty */ { [] }
| params      { $1 }
;

params:
  IDENT COLON typ              { [{ param_name = $1; param_type = $3 }] }
| params COMMA IDENT COLON typ { $1 @ [{ param_name = $3; param_type = $5 }] }
;

typ_or_void:
  typ    { $1 }
| VOID_T { Void }
;

typ:
  I32_T  { I32 }
| Q16_T  { Q16 }
| BOOL_T { Bool }
| VEC3_T { Vec3 }
| IDENT  { Struct $1 }
| LBRACKET typ SEMI INT RBRACKET { Array ($2, Int32.to_int $4) }
;

block:
  LBRACE var_decls stmts RBRACE { Block ($2 @ $3) }
;

var_decls:
  /* empty */ { [] }
| var_decls var_decl { $1 @ [$2] }
;

var_decl:
  LET IDENT COLON typ SEMI             { Let ($2, $4, None) }
| LET IDENT COLON typ ASSIGN expr SEMI { Let ($2, $4, Some $6) }
;

stmts:
  /* empty */ { [] }
| stmts stmt  { $1 @ [$2] }
;

stmt:
  expr ASSIGN expr SEMI                  { Assign ($1, $3) }
| IF LPAREN expr RPAREN block            { If ($3, $5, None) }
| IF LPAREN expr RPAREN block ELSE block { If ($3, $5, Some $7) }
| WHILE LPAREN expr RPAREN block         { While ($3, $5) }
| FOR IDENT IN expr DOTDOT expr block    { For ($2, $4, $6, $7) }
| BREAK SEMI                             { Break }
| CONTINUE SEMI                          { Continue }
| RETURN SEMI                            { Return None }
| RETURN expr SEMI                       { Return (Some $2) }
| expr SEMI                              { Expr $1 }
;

const_init:
  INT                      { expr (Parsing.symbol_start_pos ()) (Literal (LI32 $1)) }
| MINUS INT                { expr (Parsing.symbol_start_pos ()) (Literal (LI32 (Int32.neg $2))) }
| QLIT                     { expr (Parsing.symbol_start_pos ()) (Literal (LQ16 $1)) }
| MINUS QLIT               { expr (Parsing.symbol_start_pos ()) (Literal (LQ16 (Int32.neg $2))) }
| CHAR                     { expr (Parsing.symbol_start_pos ()) (Literal (LChar $1)) }
| TRUE                     { expr (Parsing.symbol_start_pos ()) (Literal (LBool true)) }
| FALSE                    { expr (Parsing.symbol_start_pos ()) (Literal (LBool false)) }
| VEC3_T LPAREN const_init COMMA const_init COMMA const_init RPAREN
    { expr (Parsing.symbol_start_pos ()) (Call ("vec3", [$3; $5; $7])) }
| IDENT LPAREN const_init_list RPAREN { expr (Parsing.symbol_start_pos ()) (Call ($1, $3)) }
| LBRACKET const_init_list RBRACKET   { expr (Parsing.symbol_start_pos ()) (Call ("__array__", $2)) }
;

const_init_list:
  const_init { [$1] }
| const_init_list COMMA const_init { $1 @ [$3] }
| const_init_list COMMA { $1 }
;

expr:
  logic_or { $1 }
;

logic_or:
  logic_and { $1 }
| logic_or LOR logic_and { expr (Parsing.symbol_start_pos ()) (Binary (Or, $1, $3)) }
;

logic_and:
  bit_or { $1 }
| logic_and LAND bit_or { expr (Parsing.symbol_start_pos ()) (Binary (And, $1, $3)) }
;

bit_or:
  bit_xor { $1 }
| bit_or BOR bit_xor { expr (Parsing.symbol_start_pos ()) (Binary (BitOr, $1, $3)) }
;

bit_xor:
  bit_and { $1 }
| bit_xor BXOR bit_and { expr (Parsing.symbol_start_pos ()) (Binary (BitXor, $1, $3)) }
;

bit_and:
  equality { $1 }
| bit_and BAND equality { expr (Parsing.symbol_start_pos ()) (Binary (BitAnd, $1, $3)) }
;

equality:
  relational { $1 }
| relational EQ relational { expr (Parsing.symbol_start_pos ()) (Binary (Eq, $1, $3)) }
| relational NE relational { expr (Parsing.symbol_start_pos ()) (Binary (Ne, $1, $3)) }
;

relational:
  shift { $1 }
| shift LT shift { expr (Parsing.symbol_start_pos ()) (Binary (Lt, $1, $3)) }
| shift LE shift { expr (Parsing.symbol_start_pos ()) (Binary (Le, $1, $3)) }
| shift GT shift { expr (Parsing.symbol_start_pos ()) (Binary (Gt, $1, $3)) }
| shift GE shift { expr (Parsing.symbol_start_pos ()) (Binary (Ge, $1, $3)) }
;

shift:
  additive { $1 }
| shift SHL additive { expr (Parsing.symbol_start_pos ()) (Binary (Shl, $1, $3)) }
| shift SHR additive { expr (Parsing.symbol_start_pos ()) (Binary (Shr, $1, $3)) }
;

additive:
  mul { $1 }
| additive PLUS mul  { expr (Parsing.symbol_start_pos ()) (Binary (Add, $1, $3)) }
| additive MINUS mul { expr (Parsing.symbol_start_pos ()) (Binary (Sub, $1, $3)) }
;

mul:
  unary { $1 }
| mul STAR unary    { expr (Parsing.symbol_start_pos ()) (Binary (Mul, $1, $3)) }
| mul SLASH unary   { expr (Parsing.symbol_start_pos ()) (Binary (Div, $1, $3)) }
| mul PERCENT unary { expr (Parsing.symbol_start_pos ()) (Binary (Mod, $1, $3)) }
| mul DOTPROD unary { expr (Parsing.symbol_start_pos ()) (Binary (Dot, $1, $3)) }
;

unary:
  MINUS unary { expr (Parsing.symbol_start_pos ()) (Unary (Neg, $2)) }
| NOT unary   { expr (Parsing.symbol_start_pos ()) (Unary (Not, $2)) }
| postfix     { $1 }
;

postfix:
  primary { $1 }
| postfix DOT IDENT                 { expr (Parsing.symbol_start_pos ()) (Field ($1, $3)) }
| postfix LBRACKET expr RBRACKET    { expr (Parsing.symbol_start_pos ()) (Index ($1, $3)) }
| postfix LPAREN args_opt RPAREN    {
    match $1.desc with
    | Variable id -> expr (Parsing.symbol_start_pos ()) (Call (id, $3))
    | _ -> failwith "invalid function call"
  }
;

primary:
  IDENT  { expr (Parsing.symbol_start_pos ()) (Variable $1) }
| INT    { expr (Parsing.symbol_start_pos ()) (Literal (LI32 $1)) }
| QLIT   { expr (Parsing.symbol_start_pos ()) (Literal (LQ16 $1)) }
| CHAR   { expr (Parsing.symbol_start_pos ()) (Literal (LChar $1)) }
| STRING { expr (Parsing.symbol_start_pos ()) (Literal (LString $1)) }
| TRUE   { expr (Parsing.symbol_start_pos ()) (Literal (LBool true)) }
| FALSE  { expr (Parsing.symbol_start_pos ()) (Literal (LBool false)) }
| I32_T LPAREN expr RPAREN { expr (Parsing.symbol_start_pos ()) (Call ("i32", [$3])) }
| Q16_T LPAREN expr RPAREN { expr (Parsing.symbol_start_pos ()) (Call ("q16", [$3])) }
| VEC3_T LPAREN expr COMMA expr COMMA expr RPAREN { expr (Parsing.symbol_start_pos ()) (Call ("vec3", [$3; $5; $7])) }
| LPAREN expr RPAREN       { $2 }
;

args_opt:
  /* empty */ { [] }
| args        { $1 }
;

args:
  expr            { [$1] }
| args COMMA expr { $1 @ [$3] }
;

