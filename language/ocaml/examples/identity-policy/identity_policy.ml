let authorize tenant role active tool target =
  active && role = "operator" && tenant = target && tool = "record"

let () =
  if not (authorize "acme" "operator" true "record" "acme") then failwith "operator denied";
  if authorize "acme" "viewer" true "record" "acme" then failwith "viewer allowed";
  if authorize "acme" "operator" true "record" "other" then failwith "tenant mismatch";
  print_endline "OCaml identity policy example passed"
