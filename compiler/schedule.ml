let regs = [
  "zero"; "ra"; "sp"; "gp"; "tp";
  "t0"; "t1"; "t2"; "t3"; "t4"; "t5"; "t6";
  "s0"; "s1"; "s2"; "s3"; "s4"; "s5"; "s6"; "s7"; "s8"; "s9"; "s10"; "s11";
  "a0"; "a1"; "a2"; "a3"; "a4"; "a5"; "a6"; "a7" ]

let is_reg s = List.mem s regs

(*命令の種類*)
type kind =
  | Plain            (* 自由に動かせる命令 *)
  | Load             (* メモリを読む *)
  | Mem              (* メモリに書く、または順番を変えてはいけない命令 *)
  | Barrier          (* 動かさない(ここでブロックを区切る) *)

type insn = {
  text : string;           (* 元の行 *)
  defs : string list;      (* 書くレジスタ *)
  uses : string list;      (* 読むレジスタ *)
  kind : kind;
}

let loads = ["lw"; "lh"; "lhu"; "lb"; "lbu"]
let stores = ["sw"; "sh"; "sb"]
let branches = ["j"; "jal"; "jalr"; "beq"; "bne"; "blt"; "bge"; "bltu"; "bgeu";
                "beqz"; "bnez"; "bltz"; "bgez"; "blez"; "bgtz"; "ble"; "bgt"; "ret"; "call"; "ecall"; "ebreak"]
let ordered = ["qseed"; "qrand"; "qrands"]          (*状態を持つ専用命令*)
(*1つ目が書く先で、残りを読む命令*)
let plain = ["add"; "sub"; "mul"; "mulh"; "mulhu"; "mulhsu"; "div"; "divu"; "rem"; "remu";
             "and"; "or"; "xor"; "sll"; "srl"; "sra"; "slt"; "sltu";
             "addi"; "andi"; "ori"; "xori"; "slli"; "srli"; "srai"; "slti"; "sltiu";
             "li"; "la"; "lui"; "auipc"; "mv"; "neg"; "not"; "seqz"; "snez";
             "min"; "max"; "minu"; "maxu"; "andn"; "orn"; "xnor"; "clz"; "ctz"; "cpop";
             "sext.b"; "sext.h"; "zext.h"; "rol"; "ror"; "rori";
             "qmul"; "qsqrt"; "qrsqrt"; "qrcp"]

(*1行を読む。命令でない行(ラベル、.globl、空行)はNone*)
let parse (line : string) : insn option =
  let s = String.trim line in
  if s = "" || s.[0] = '.' || s.[0] = '#' || s.[String.length s - 1] = ':' then None
  else begin
    let op, rest =
      match String.index_opt s ' ' with
      | Some k -> (String.sub s 0 k, String.sub s (k + 1) (String.length s - k - 1))
      | None -> (s, "") in
    (*オペランドをレジスタ名に分ける。"40(sp)" のspも拾う*)
    let toks = String.split_on_char ',' rest
               |> List.concat_map (fun t ->
                    String.split_on_char '(' t |> List.concat_map (String.split_on_char ')'))
               |> List.map String.trim |> List.filter (fun t -> t <> "") in
    let rs = List.filter (fun t -> is_reg t && t <> "zero") toks in
    let first = match toks with t :: _ when is_reg t -> [t] | _ -> [] in
    let first_def = List.filter (fun r -> r <> "x0" && r <> "zero") first in
    let rest_regs = match toks with t :: tl when is_reg t -> List.filter is_reg tl | tl -> List.filter is_reg tl in
    let mk kind defs uses = Some { text = line; defs; uses; kind } in
    if List.mem op loads then mk Load first_def rest_regs
    else if List.mem op stores then mk Mem [] rs
    else if List.mem op ordered then mk Mem first_def rest_regs
    else if List.mem op branches then mk Barrier [] []
    else if List.mem op plain then mk Plain first_def rest_regs
    else mk Barrier [] []                               (*知らない命令は動かさない*)
  end

let inter a b = List.exists (fun x -> List.mem x b) a

(*jがiより後ろにあるとき、iより前に出してはいけないか*)
let depends i j =
  inter i.defs j.uses                      (* 書いてから読む *)
  || inter i.uses j.defs                   (* 読んでから書く *)
  || inter i.defs j.defs                   (* 書いてから書く *)
  || (i.kind <> Plain && j.kind <> Plain)
     (*メモリの命令どうし。MMIOは読む順番にも意味があるので、lwとlwも入れかえない*)

(*直前の命令prevがlwで、cがその値を読むなら待ちが起きる*)
let stalls prev c =
  match prev with
  | Some p when p.kind = Load -> inter p.defs c.uses
  | _ -> false

(*1つのブロック(動かしてよい命令だけの並び)を並べかえる*)
let schedule_block (xs : insn array) : insn list =
  let n = Array.length xs in
  (*preds.(j) = jより前に出さないといけない命令の数*)
  let preds = Array.make n 0 and succs = Array.make n [] in
  for j = 0 to n - 1 do
    for i = 0 to j - 1 do
      if depends xs.(i) xs.(j) then begin
        preds.(j) <- preds.(j) + 1;
        succs.(i) <- j :: succs.(i)
      end
    done
  done;
  let done_ = Array.make n false in
  let out = ref [] and prev = ref None in
  for _ = 1 to n do
    (*出せる命令(前に出すべき命令が全部出ている)を、元の順番で*)
    let ready = List.filter (fun k -> not done_.(k) && preds.(k) = 0) (List.init n Fun.id) in
    let pick =
      match List.find_opt (fun k -> not (stalls !prev xs.(k))) ready with
      | Some k -> k                                   (* 待たずに出せる命令 *)
      | None -> List.hd ready in                      (* どれも待つなら元の順番 *)
    done_.(pick) <- true;
    List.iter (fun j -> preds.(j) <- preds.(j) - 1) succs.(pick);
    out := xs.(pick) :: !out;
    prev := Some xs.(pick)
  done;
  List.rev !out

(*アセンブリ全体を並べかえる*)
let run (asm : string) : string =
  let out = ref [] in                              (* 出力する行(逆順) *)
  let pending = ref [] in                          (* 並べかえを待っている命令(逆順) *)
  let flush () =
    if !pending <> [] then begin
      let xs = Array.of_list (List.rev !pending) in
      List.iter (fun i -> out := i.text :: !out) (schedule_block xs);
      pending := []
    end in
  List.iter (fun line ->
    match parse line with
    | Some i when i.kind <> Barrier -> pending := i :: !pending
    | _ ->                                         (* ラベル、分岐、知らない命令:ここで区切る *)
        flush ();
        out := line :: !out) (String.split_on_char '\n' asm);
  flush ();
  String.concat "\n" (List.rev !out)