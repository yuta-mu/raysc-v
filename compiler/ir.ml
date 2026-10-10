open Ast

type operand =
  | Imm of literal
  | Static of string
  | Slot of int

type instr =
  | Move of int * operand               (* slot[dst] = op *)
  | Bin of int * typ * binop * int * int (* slot[dst] = slot[a] op slot[b] *)
  | Un of int * typ * unop * int         (* slot[dst] = op slot[a] *)
  | IndexGet of int * operand * int      (* slot[dst] = base[slot[idx]] *)
  | IndexSet of int * int * int          (* slot[base][slot[idx]] = slot[val] *)
  | Jump of int
  | BranchFalse of int * int             (* if !slot[cond] goto label *)
  | Label of int
  | Call of int option * string * int list (* dest_slot_opt, name, arg_word_slots *)
  | PrintStr of string * int             (* string, label_id *)
  | Return of int option                 (* ret_slot_opt *)

type func = {
  name : string;
  param_words : int;
  ret_type : typ;
  frame_size : int;
  code : instr list;
}

type program = {
  constants : (string * typ * const_value) list;
  functions : func list;
}

