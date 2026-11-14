#use "language/ocaml/praxo_core.ml"

let () =
  let allow = checkpoint_allowlist () in
  checkpoint_register allow "order";
  let value = Object [("value", String "x")] in
  let data = checkpoint_marshal allow "order" value in
  let decoded = checkpoint_unmarshal allow data in
  if not (equal_json decoded value) then failwith "checkpoint payload did not round trip";
  print_endline "OCaml checkpoint example passed"
