let run_retry failures max_attempts =
  let rec go attempt =
    if attempt > failures then Ok ("status: green", attempt)
    else if attempt = max_attempts then Error ("MODEL_UNAVAILABLE", attempt)
    else go (attempt + 1)
  in
  go 1

let () =
  (match run_retry 2 3 with
   | Ok ("status: green", 3) -> ()
   | _ -> failwith "transient retry failed");
  (match run_retry 3 3 with
   | Error ("MODEL_UNAVAILABLE", 3) -> print_endline "OCaml retry example passed"
   | _ -> failwith "exhausted retry failed")
