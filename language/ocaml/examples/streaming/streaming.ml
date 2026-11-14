let () =
  let chunks = ["status: "; "green"] in
  let output = String.concat "" chunks in
  if output <> "status: green" || String.concat "" chunks <> output then
    failwith "deltas did not reconstruct the output";
  print_endline "OCaml streaming example passed"
