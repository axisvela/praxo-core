let run_fallback primary_fails fallback_fails =
  if not primary_fails then "primary"
  else if not fallback_fails then "fallback"
  else "MODEL_UNAVAILABLE"

let () =
  if run_fallback false false <> "primary" then failwith "primary path failed";
  if run_fallback true false <> "fallback" then failwith "fallback path failed";
  if run_fallback true true <> "MODEL_UNAVAILABLE" then failwith "both-failure path failed";
  print_endline "OCaml provider fallback example passed"
