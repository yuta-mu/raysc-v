%{

open Printf
open Ast

let parse_error msg =
  Printf.eprintf "syntax error at line %d near '%s'\n" !Lexer.line_number !Lexer.curr_tok

%}

/* File parser.mly */
%token <int> NUM
%token <string> STR ID
%token INT IF DO WHILE FOR DOTDOT QUEST COLON SPRINT IPRINT EQ NEQ GT LT GE LE ELSE RETURN NEW
%token PLUS MINUS TIMES DIV MOD HAT INC PLUS_ASSIGN LB RB LS RS LP RP ASSIGN SEMI COMMA TYPE VOID
%type <Ast.stmt> prog


%nonassoc GT LT EQ NEQ GE LE
%left PLUS MINUS         /* lowest precedence */
%left TIMES DIV MOD        /* medium precedence */
%right HAT
%nonassoc UMINUS
%nonassoc INC            /* highest precedence */


%start prog           /* the entry point */

%%

prog : stmt  {  $1  }
     ;

ty   : INT { IntTyp }
     | INT LS NUM RS { ArrayTyp ($3, IntTyp) }
     | ID	     { NameTyp $1 }
     ;

decs : decs dec { $1@$2 }
     |          { [] }
     ;

dec  : ty ids SEMI   { List.map (fun x -> VarDec ($1,x)) $2 }
     | ty ID ASSIGN expr SEMI { [InitVarDec ($1, $2, $4)] }
     | TYPE ID ASSIGN ty SEMI { [TypeDec ($2,$4)] }
     | ty ID LP fargs_opt RP block  { [FuncDec($2, $4, $1, $6)] }
     | VOID ID LP fargs_opt RP block  { [FuncDec($2, $4, VoidTyp, $6)] }
     ; 

ids  : ids COMMA ID    { $1@[$3] }
     | ID              { [$1]  }
     ;

fargs_opt : /* empty */ { [] }
     | fargs            { $1 }
     ;
     
fargs: fargs COMMA ty ID     { $1@[($3,$4)] }
     | ty ID                 { [($1,$2)] }
     ;

stmts: stmts stmt  { $1@[$2] }
     | stmt        { [$1] }
     ;

stmt : ID ASSIGN expr SEMI    { Assign (Var $1, $3) }
     | ID INC SEMI { Assign (Var $1, CallFunc ("+", [VarExp (Var $1); IntExp 1]))}
     | ID PLUS_ASSIGN expr SEMI { Assign (Var $1, CallFunc ("+", [VarExp (Var $1); $3])) }
     | ID LS expr RS ASSIGN expr SEMI  { Assign (IndexedVar (Var $1, $3), $6) }
     | IF LP cond RP stmt     { If ($3, $5, None) }
     | IF LP cond RP stmt ELSE stmt 
                              { If ($3, $5, Some $7) }
     | WHILE LP cond RP stmt  { While ($3, $5) }
     | DO stmt WHILE LP cond RP SEMI { Block ([], [$2; While ($5, $2)]) }
     | FOR LP ID ASSIGN expr DOTDOT expr RP stmt {
        Block ([], [
           Assign (Var $3, $5);
           While (
              CallFunc ("!=", [VarExp (Var $3); $7]),
              Block ([], [
                 $9;
                 Assign (Var $3, CallFunc ("+", [VarExp (Var $3); IntExp 1]))
              ])
           )
        ])
     }
     | SPRINT LP STR RP SEMI  { CallProc ("sprint", [StrExp $3]) }
     | IPRINT LP expr RP SEMI { CallProc ("iprint", [$3]) }
     | NEW LP ID RP SEMI   { CallProc ("new", [ VarExp (Var $3)]) }
     | ID LP aargs_opt RP SEMI  { CallProc ($1, $3) }
     | RETURN expr SEMI    { CallProc ("return", [$2]) }
     | block { $1 }
     | SEMI { NilStmt }
     | error SEMI { 
          Printf.eprintf "syntax error: skipping to ';'\n";
          NilStmt 
          }
     ;

aargs_opt: /* empty */     { [] }
        | aargs            { $1 }
        ;

aargs : aargs COMMA expr  { $1@[$3] }
      | expr               { [$1] }
      ;

block: LB decs stmts RB  { Block ($2, $3) }
     ;

expr : NUM { IntExp $1  }
     | ID { VarExp (Var $1) }
     | ID LP aargs_opt RP { CallFunc ($1, $3) } 
     | ID LS expr RS  { VarExp (IndexedVar (Var $1, $3)) }
     | expr PLUS expr { CallFunc ("+", [$1; $3]) }
     | expr MINUS expr { CallFunc ("-", [$1; $3]) }
     | expr TIMES expr { CallFunc ("*", [$1; $3]) }
     | expr DIV expr { CallFunc ("/", [$1; $3]) }
     | expr MOD expr { CallFunc ("%", [$1; $3]) }
     | expr HAT expr { CallFunc ("^", [$1; $3]) }
     | ID INC { PostInc (Var $1) }
     | cond QUEST expr COLON expr { CondExp ($1, $3, $5) }
     | ID LS expr RS INC { PostInc (IndexedVar (Var $1, $3)) }
     | MINUS expr %prec UMINUS { CallFunc("!", [$2]) }
     | LP expr RP  { $2 }
     ;

cond : expr EQ expr  { CallFunc ("==", [$1; $3]) }
     | expr NEQ expr { CallFunc ("!=", [$1; $3]) }
     | expr GT expr  { CallFunc (">", [$1; $3]) }
     | expr LT expr  { CallFunc ("<", [$1; $3]) }
     | expr GE expr  { CallFunc (">=", [$1; $3]) }
     | expr LE expr  { CallFunc ("<=", [$1; $3]) }
     | LP cond RP    { $2 }
     ;
%%
