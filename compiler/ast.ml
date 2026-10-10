type typ =
  | I32
  | Q16
  | Bool
  | Vec3
  | Void
  | Struct of string
  | Array of typ * int

type literal =
  | LI32 of int32
  | LQ16 of int32
  | LBool of bool
  | LChar of int32
  | LString of string

type const_value =
  | CVI32 of int32
  | CVQ16 of int32
  | CVBool of bool
  | CVVec3 of int32 * int32 * int32
  | CVStruct of string * (string * const_value) list
  | CVArray of const_value list

type binop =
  | Add | Sub | Mul | Div | Mod
  | Shl | Shr | BitAnd | BitOr | BitXor
  | Eq | Ne | Lt | Le | Gt | Ge
  | And | Or | Dot

type unop = Neg | Not

type expr = { desc : expr_desc; loc : Lexing.position }
and expr_desc =
  | Literal of literal
  | Variable of string
  | Binary of binop * expr * expr
  | Unary of unop * expr
  | Call of string * expr list
  | Field of expr * string
  | Index of expr * expr

type stmt =
  | Block of stmt list
  | Let of string * typ * expr option
  | Assign of expr * expr
  | Expr of expr
  | If of expr * stmt * stmt option
  | While of expr * stmt
  | For of string * expr * expr * stmt
  | Break
  | Continue
  | Return of expr option

type field_decl = { field_name : string; field_type : typ }
type param = { param_name : string; param_type : typ }

type decl =
  | Const of string * typ * expr
  | StructDecl of string * field_decl list
  | Function of string * param list * typ * stmt

type program = decl list

let rec typ_to_string = function
  | I32 -> "i32" | Q16 -> "q16" | Bool -> "bool" | Vec3 -> "vec3"
  | Void -> "void" | Struct s -> s
  | Array (t, n) -> Printf.sprintf "[%s; %d]" (typ_to_string t) n

