#use "language/ocaml/praxo_core.ml"

let () =
  let all = ref [] and tool = ref [] in
  let all_sink event = all := !all @ [event.event_type] in
  let tool_sink event = tool := !tool @ [event.event_type] in
  let filtered = filter_sink tool_sink (fun event -> event.event_type = "tool.call") in
  let multi = multi_sink [all_sink; filtered] in
  List.iter (fun kind ->
    emit multi { event_type = kind; event_session_id = "s1";
                 event_run_id = None; event_data = Null })
    ["run.started"; "tool.call"; "run.completed"];
  if !all <> ["run.started"; "tool.call"; "run.completed"] ||
     !tool <> ["tool.call"] then failwith "unexpected event delivery";
  print_endline "OCaml event sink example passed"
