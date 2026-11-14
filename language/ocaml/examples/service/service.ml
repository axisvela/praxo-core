let contains text needle =
  let length_text = String.length text and length_needle = String.length needle in
  let rec loop index =
    index + length_needle <= length_text &&
    (String.sub text index length_needle = needle || loop (index + 1))
  in
  length_needle = 0 || loop 0

let handle method path principal body =
  if method = "GET" && path = "/healthz" then (200, "{\"status\":\"ok\"}")
  else if method <> "POST" || path <> "/run" then (404, "{\"error\":\"not found\"}")
  else if principal = "" then (401, "{\"error\":\"missing X-Praxo-Principal\"}")
  else if not (contains body "\"prompt\"") then (400, "{\"error\":\"prompt is required\"}")
  else (200, "{\"output\":\"hello from the service\"}")

let () =
  if fst (handle "GET" "/healthz" "" "") <> 200 then failwith "health failed";
  if fst (handle "POST" "/run" "" "{\"prompt\":\"hi\"}") <> 401 then failwith "missing principal";
  if fst (handle "POST" "/run" "user-1" "{\"prompt\":\"hi\"}") <> 200 then failwith "run failed";
  print_endline "OCaml service example passed"
