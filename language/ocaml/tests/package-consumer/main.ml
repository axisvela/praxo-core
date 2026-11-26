let () =
  let parsed = Praxo_core.parse_json "{\"package\":\"praxo-core\"}" in
  assert (Praxo_core.encode_json parsed <> "");
  let tool = Praxo_core.parse_tool_call "<tool_call name=\"echo\">{}</tool_call>" in
  assert (Option.is_some tool);
  Printf.printf "Installed OCaml package %s consumer passed\n" Praxo_core.sdk_version
