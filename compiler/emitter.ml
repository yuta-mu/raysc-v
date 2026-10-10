open Ast
open Ir

let emit_program (out : out_channel) (p : Ir.program) (ctx : Semant.context) =
  let ppr fmt = Printf.fprintf out fmt in

  ppr ".section .text\n";

  List.iter (fun (f : Ir.func) ->
    ppr ".globl %s\n" f.name;
    ppr "%s:\n" f.name;

    (* 最大呼び出しスタック引数領域の計算 *)
    let max_caller_stack_args = ref 0 in
    List.iter (function
      | Call (_, _, arg_words) ->
          let total = List.length arg_words in
          if total > 8 then
            let stack_w = total - 8 in
            if stack_w > !max_caller_stack_args then max_caller_stack_args := stack_w
      | _ -> ()
    ) f.code;

    let frame_words = !max_caller_stack_args + f.frame_size + 1 in
    let frame_bytes = frame_words * 4 in
    let ra_offset = frame_bytes - 4 in

    ppr "    addi sp, sp, -%d\n" frame_bytes;
    ppr "    sw ra, %d(sp)\n" ra_offset;

    let slot_offset s = (!max_caller_stack_args + s) * 4 in

    (* 着信引数を自フレームのスロットに退避 *)
    if f.param_words > 0 then begin
      let reg_words = min 8 f.param_words in
      for i = 0 to reg_words - 1 do
        ppr "    sw a%d, %d(sp)\n" i (slot_offset i)
      done;
      if f.param_words > 8 then begin
        for i = 8 to f.param_words - 1 do
          let caller_off = frame_bytes + (i - 8) * 4 in
          ppr "    lw t0, %d(sp)\n" caller_off;
          ppr "    sw t0, %d(sp)\n" (slot_offset i)
        done
      end
    end;

    let load_op reg = function
      | Imm (LI32 v) | Imm (LQ16 v) | Imm (LChar v) ->
          ppr "    li %s, %ld\n" reg v
      | Imm (LBool b) ->
          ppr "    li %s, %d\n" reg (if b then 1 else 0)
      | Imm (LString _) -> ()
      | Slot s ->
          ppr "    lw %s, %d(sp)\n" reg (slot_offset s)
      | Static name ->
          ppr "    la %s, %s\n" reg name
    in

    List.iter (function
      | Label l -> ppr ".L%s_%d:\n" f.name l
      | Jump l  -> ppr "    j .L%s_%d\n" f.name l
      | BranchFalse (s_cond, l) ->
          ppr "    lw t0, %d(sp)\n" (slot_offset s_cond);
          ppr "    beqz t0, .L%s_%d\n" f.name l

      | Move (dst, op) ->
          load_op "t0" op;
          ppr "    sw t0, %d(sp)\n" (slot_offset dst)

      | Bin (dst, Q16, Mul, sa, sb) ->
          ppr "    lw t0, %d(sp)\n" (slot_offset sa);
          ppr "    lw t1, %d(sp)\n" (slot_offset sb);
          ppr "    mul t2, t0, t1\n";
          ppr "    mulh t3, t0, t1\n";
          ppr "    srli t2, t2, 16\n";
          ppr "    slli t3, t3, 16\n";
          ppr "    or t2, t2, t3\n";
          ppr "    sw t2, %d(sp)\n" (slot_offset dst)

      | Bin (dst, _, Dot, sa, sb) ->
          ppr "    lw t0, %d(sp)\n" (slot_offset sa);
          ppr "    lw t1, %d(sp)\n" (slot_offset sb);
          ppr "    mul t2, t0, t1\n    mulh t3, t0, t1\n    srli t2, t2, 16\n    slli t3, t3, 16\n    or t4, t2, t3\n";
          ppr "    lw t0, %d(sp)\n" (slot_offset (sa + 1));
          ppr "    lw t1, %d(sp)\n" (slot_offset (sb + 1));
          ppr "    mul t2, t0, t1\n    mulh t3, t0, t1\n    srli t2, t2, 16\n    slli t3, t3, 16\n    or t2, t2, t3\n";
          ppr "    add t4, t4, t2\n";
          ppr "    lw t0, %d(sp)\n" (slot_offset (sa + 2));
          ppr "    lw t1, %d(sp)\n" (slot_offset (sb + 2));
          ppr "    mul t2, t0, t1\n    mulh t3, t0, t1\n    srli t2, t2, 16\n    slli t3, t3, 16\n    or t2, t2, t3\n";
          ppr "    add t4, t4, t2\n";
          ppr "    sw t4, %d(sp)\n" (slot_offset dst)

      | Bin (dst, Vec3, (Add | Sub as op), sa, sb) ->
          let op_s = if op = Sub then "sub" else "add" in
          for i = 0 to 2 do
            ppr "    lw t0, %d(sp)\n" (slot_offset (sa + i));
            ppr "    lw t1, %d(sp)\n" (slot_offset (sb + i));
            ppr "    %s t2, t0, t1\n" op_s;
            ppr "    sw t2, %d(sp)\n" (slot_offset (dst + i))
          done

      | Bin (dst, Vec3, Mul, sa, sb) ->
          ppr "    lw t1, %d(sp)\n" (slot_offset sb);
          for i = 0 to 2 do
            ppr "    lw t0, %d(sp)\n" (slot_offset (sa + i));
            ppr "    mul t2, t0, t1\n    mulh t3, t0, t1\n    srli t2, t2, 16\n    slli t3, t3, 16\n    or t2, t2, t3\n";
            ppr "    sw t2, %d(sp)\n" (slot_offset (dst + i))
          done

      | Bin (dst, ty, op, sa, sb) ->
          ppr "    lw t0, %d(sp)\n" (slot_offset sa);
          ppr "    lw t1, %d(sp)\n" (slot_offset sb);
          (match ty, op with
           | _, Add -> ppr "    add t2, t0, t1\n"
           | _, Sub -> ppr "    sub t2, t0, t1\n"
           | I32, Mul -> ppr "    mul t2, t0, t1\n"
           | I32, Div -> ppr "    div t2, t0, t1\n"
           | I32, Mod -> ppr "    rem t2, t0, t1\n"
           | I32, Shl -> ppr "    sll t2, t0, t1\n"
           | I32, Shr -> ppr "    sra t2, t0, t1\n"
           | I32, BitAnd -> ppr "    and t2, t0, t1\n"
           | I32, BitOr  -> ppr "    or t2, t0, t1\n"
           | I32, BitXor -> ppr "    xor t2, t0, t1\n"
           | _, Eq -> ppr "    sub t2, t0, t1\n    sltiu t2, t2, 1\n"
           | _, Ne -> ppr "    sub t2, t0, t1\n    sltu t2, x0, t2\n"
           | _, Lt -> ppr "    slt t2, t0, t1\n"
           | _, Ge -> ppr "    slt t2, t0, t1\n    xori t2, t2, 1\n"
           | _, Gt -> ppr "    slt t2, t1, t0\n"
           | _, Le -> ppr "    slt t2, t1, t0\n    xori t2, t2, 1\n"
           | _ -> failwith "unsupported op");
          ppr "    sw t2, %d(sp)\n" (slot_offset dst)

      | Un (dst, _, Neg, sa) ->
          ppr "    lw t0, %d(sp)\n" (slot_offset sa);
          ppr "    sub t1, x0, t0\n";
          ppr "    sw t1, %d(sp)\n" (slot_offset dst)
      | Un (dst, _, Not, sa) ->
          ppr "    lw t0, %d(sp)\n" (slot_offset sa);
          ppr "    xori t1, t0, 1\n";
          ppr "    sw t1, %d(sp)\n" (slot_offset dst)

      | PrintStr (_, id) ->
          let str_lbl = Printf.sprintf ".L_str_%d" id in
          let loop_lbl = Printf.sprintf ".L_print_loop_%d" id in
          let done_lbl = Printf.sprintf ".L_print_done_%d" id in
          ppr "    la t0, %s\n" str_lbl;
          ppr "    li t1, 0x10000000\n";
          ppr "%s:\n" loop_lbl;
          ppr "    lbu t2, 0(t0)\n";
          ppr "    beqz t2, %s\n" done_lbl;
          ppr "    sb t2, 0(t1)\n";
          ppr "    addi t0, t0, 1\n";
          ppr "    j %s\n" loop_lbl;
          ppr "%s:\n" done_lbl

      | Call (_, "bprint", [sa]) ->
          ppr "    lw t0, %d(sp)\n" (slot_offset sa);
          ppr "    li t1, 0x10000000\n";
          ppr "    sb t0, 0(t1)\n"

      | Call (dst, "cycles", []) ->
          ppr "    li t0, 0x20000000\n";
          ppr "    lw t1, 0(t0)\n";
          Option.iter (fun d -> ppr "    sw t1, %d(sp)\n" (slot_offset d)) dst

      | Call (dst, "q16", [sa]) ->
          ppr "    lw t0, %d(sp)\n" (slot_offset sa);
          ppr "    slli t1, t0, 16\n";
          Option.iter (fun d -> ppr "    sw t1, %d(sp)\n" (slot_offset d)) dst

      | Call (dst, "i32", [sa]) ->
          ppr "    lw t0, %d(sp)\n" (slot_offset sa);
          ppr "    srai t1, t0, 16\n";
          Option.iter (fun d -> ppr "    sw t1, %d(sp)\n" (slot_offset d)) dst

      | Call (dst, "sqrt", [sa]) ->
          ppr "    lw a0, %d(sp)\n" (slot_offset sa);
          ppr "    jal ra, __q16_sqrt\n";
          Option.iter (fun d -> ppr "    sw a0, %d(sp)\n" (slot_offset d)) dst

      | Call (dst, "rcp", [sa]) ->
          ppr "    lw a0, %d(sp)\n" (slot_offset sa);
          ppr "    jal ra, __q16_rcp\n";
          Option.iter (fun d -> ppr "    sw a0, %d(sp)\n" (slot_offset d)) dst

      | Call (dst, name, arg_words) ->
          List.iteri (fun i slot ->
            if i < 8 then
              ppr "    lw a%d, %d(sp)\n" i (slot_offset slot)
            else begin
              ppr "    lw t0, %d(sp)\n" (slot_offset slot);
              ppr "    sw t0, %d(sp)\n" ((i - 8) * 4)
            end
          ) arg_words;
          ppr "    jal ra, %s\n" name;
          Option.iter (fun d ->
            let ret_ty = (Hashtbl.find ctx.Semant.functions name).ret_type in
            let rw = Semant.type_words ctx.Semant.structs ret_ty in
            for i = 0 to rw - 1 do
              ppr "    sw a%d, %d(sp)\n" i (slot_offset (d + i))
            done
          ) dst

      | IndexGet (dst, base_op, sidx) ->
          load_op "t0" base_op;
          ppr "    lw t1, %d(sp)\n" (slot_offset sidx);
          ppr "    slli t1, t1, 2\n";
          ppr "    add t0, t0, t1\n";
          ppr "    lw t2, 0(t0)\n";
          ppr "    sw t2, %d(sp)\n" (slot_offset dst)

      | IndexSet (sbase, sidx, sval) ->
          ppr "    addi t0, sp, %d\n" (slot_offset sbase);
          ppr "    lw t1, %d(sp)\n" (slot_offset sidx);
          ppr "    slli t1, t1, 2\n";
          ppr "    add t0, t0, t1\n";
          ppr "    lw t2, %d(sp)\n" (slot_offset sval);
          ppr "    sw t2, 0(t0)\n"

      | Return (Some s) ->
          let rw = Semant.type_words ctx.Semant.structs f.ret_type in
          for i = 0 to rw - 1 do
            ppr "    lw a%d, %d(sp)\n" i (slot_offset (s + i))
          done;
          ppr "    lw ra, %d(sp)\n" ra_offset;
          ppr "    addi sp, sp, %d\n" frame_bytes;
          ppr "    jalr x0, ra, 0\n"

      | Return None ->
          ppr "    lw ra, %d(sp)\n" ra_offset;
          ppr "    addi sp, sp, %d\n" frame_bytes;
          ppr "    jalr x0, ra, 0\n"
    ) f.code;
  ) p.functions;

  (* RV32IM 平方根サブルーチン *)
  ppr "\n.globl __q16_sqrt\n__q16_sqrt:\n";
  ppr "    blez a0, .L_sqrt_zero\n";
  ppr "    srai t4, a0, 16\n    slli t5, a0, 16\n";
  ppr "    li t0, 0\n    li t1, 0x01000000\n    li a2, 0\n";
  ppr ".L_sqrt_loop:\n";
  ppr "    add t2, t0, t1\n    srli t2, t2, 1\n";
  ppr "    mul t6, t2, t2\n    mulh a1, t2, t2\n";
  ppr "    blt a1, t4, .L_sqrt_le\n    bgt a1, t4, .L_sqrt_gt\n";
  ppr "    bgeu t5, t6, .L_sqrt_le\n";
  ppr ".L_sqrt_gt:\n    addi t1, t2, -1\n    j .L_sqrt_check\n";
  ppr ".L_sqrt_le:\n    mv a2, t2\n    addi t0, t2, 1\n";
  ppr ".L_sqrt_check:\n    bge t1, t0, .L_sqrt_loop\n";
  ppr "    mv a0, a2\n    jalr x0, ra, 0\n";
  ppr ".L_sqrt_zero:\n    li a0, 0\n    jalr x0, ra, 0\n";

  (* RV32IM 逆数サブルーチン (2^32 / x の 32bit シフト除算) *)
  ppr "\n.globl __q16_rcp\n__q16_rcp:\n";
  ppr "    beqz a0, .L_rcp_zero\n";        (* x == 0 -> 0x7FFFFFFF *)
  ppr "    li t0, 0\n";                   (* 符号フラグ: 0=正, 1=負 *)
  ppr "    bgez a0, .L_rcp_abs\n";
  ppr "    li t0, 1\n";
  ppr "    sub a0, x0, a0\n";             (* a0 = abs(x) *)
  ppr ".L_rcp_abs:\n";
  ppr "    li a1, 1\n";                   (* rem_hi = 1 *)
  ppr "    li a2, 0\n";                   (* rem_lo = 0 (分子 = 2^32) *)
  ppr "    li a3, 0\n";                   (* quot = 0 *)
  ppr "    li t1, 32\n";                  (* loop count *)
  ppr ".L_rcp_loop:\n";
  ppr "    slli a3, a3, 1\n";             (* quot <<= 1 *)
  ppr "    srli t2, a2, 31\n";            (* rem_lo の MSB *)
  ppr "    slli a1, a1, 1\n";             (* rem_hi <<= 1 *)
  ppr "    or a1, a1, t2\n";
  ppr "    slli a2, a2, 1\n";             (* rem_lo <<= 1 *)
  ppr "    bltu a1, a0, .L_rcp_next\n";
  ppr "    sub a1, a1, a0\n";
  ppr "    ori a3, a3, 1\n";              (* quot |= 1 *)
  ppr ".L_rcp_next:\n";
  ppr "    addi t1, t1, -1\n";
  ppr "    bnez t1, .L_rcp_loop\n";
  ppr "    beqz t0, .L_rcp_pos_ret\n";
  (* 負の分母の floor 補正: 余り(a1|a2) != 0 なら --quot *)
  ppr "    or t3, a1, a2\n";
  ppr "    beqz t3, .L_rcp_neg_exact\n";
  ppr "    addi a3, a3, 1\n";             (* - (quot + 1) *)
  ppr ".L_rcp_neg_exact:\n";
  ppr "    sub a0, x0, a3\n";
  ppr "    jalr x0, ra, 0\n";
  ppr ".L_rcp_pos_ret:\n";
  ppr "    mv a0, a3\n";
  ppr "    jalr x0, ra, 0\n";
  ppr ".L_rcp_zero:\n";
  ppr "    lui a0, 0x80000\n    addi a0, a0, -1\n"; (* 0x7FFFFFFF *)
  ppr "    jalr x0, ra, 0\n";

  (* 定数データセクション (.rodata) *)
  ppr "\n.section .rodata\n";
  List.iter (fun (name, _, v) ->
    ppr ".globl %s\n%s:\n" name name;
    match v with
    | CVI32 x | CVQ16 x -> ppr "    .word %ld\n" x
    | CVBool b -> ppr "    .word %d\n" (if b then 1 else 0)
    | CVArray xs ->
        List.iter (function
          | CVI32 x | CVQ16 x -> ppr "    .word %ld\n" x
          | _ -> ()
        ) xs
    | _ -> ()
  ) p.constants;

  (* 文字列リテラル (.rodata) *)
  List.iter (fun (f : Ir.func) ->
    List.iter (function
      | PrintStr (s, id) ->
          ppr ".L_str_%d:\n    .string %S\n" id s
      | _ -> ()
    ) f.code
  ) p.functions

