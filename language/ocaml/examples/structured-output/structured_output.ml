#use "language/ocaml/praxo_core.ml"

let () =
  let schema = parse_json "{\"type\":\"object\",\"required\":[\"name\"],\"properties\":{\"name\":{\"type\":\"string\"}}}" in
  let valid = parse_json "{\"name\":\"ok\"}" in
  let invalid = parse_json "{}" in
  if validate_schema schema valid <> [] then failwith "valid output was rejected";
  if validate_schema schema invalid = [] then failwith "invalid output was accepted";
  print_endline "OCaml structured output example passed"
