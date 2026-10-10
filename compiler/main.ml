let () =
  let input_file = ref "" in
  let output_file = ref "" in
  let opt_level = ref 0 in
  let accel_mode = ref "off" in

  let speclist = [
    ("-o", Arg.Set_string output_file, "Output assembly file (.s)");
    ("-O0", Arg.Unit (fun () -> opt_level := 0), "Optimization level 0");
    ("-O1", Arg.Unit (fun () -> opt_level := 1), "Optimization level 1");
    ("-O2", Arg.Unit (fun () -> opt_level := 2), "Optimization level 2");
    ("-O3", Arg.Unit (fun () -> opt_level := 3), "Optimization level 3");
    ("--accel", Arg.Set_string accel_mode, "Accelerator mode (off|math|isect)");
  ] in

  Arg.parse speclist (fun f -> input_file := f) "Usage: rayqc <input.rq> -o <output.s>";

  if !input_file = "" || !output_file = "" then begin
    prerr_endline "Error: input and output files are required";
    exit 1
  end;

  let ch = open_in !input_file in
  let lexbuf = Lexing.from_channel ch in
  lexbuf.Lexing.lex_curr_p <- { lexbuf.Lexing.lex_curr_p with Lexing.pos_fname = !input_file };
  let ast =
    try Parser.program Lexer.token lexbuf with
    | Lexer.Error msg -> prerr_endline msg; exit 1
    | Parsing.Parse_error ->
        let p = Lexing.lexeme_start_p lexbuf in
        Printf.eprintf "%s:%d:%d: syntax error\n" !input_file p.Lexing.pos_lnum
          (p.Lexing.pos_cnum - p.Lexing.pos_bol + 1);
        exit 1
  in
  close_in ch;

  let ctx =
    try Semant.analyze ast with
    | Semant.Error msg -> prerr_endline ("semantic error: " ^ msg); exit 1
  in
  let ir = Translate.compile ctx in

  let out = open_out !output_file in
  Emitter.emit_program out ir ctx;
  close_out out

