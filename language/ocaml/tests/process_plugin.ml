open Praxo_core

let token = match Sys.getenv_opt "PRAXOVELA_PLUGIN_TOKEN" with Some value -> value | None -> ""

let string_field key = function
  | Object fields ->
      let rec find = function
        | [] -> ""
        | (name, String text) :: _ when name = key -> text
        | _ :: rest -> find rest
      in
      find (List.rev fields)
  | _ -> ""

let respond fields =
  print_endline (encode_json (Object fields));
  flush stdout

let handle_request request =
  let id = string_field "id" request in
  if string_field "token" request <> token then
    respond [
      ("id", String id);
      ("version", Number 1.0);
      ("ok", Bool false);
      ("code", String "INVALID_REQUEST");
      ("message", String "token mismatch");
    ]
  else
    match string_field "method" request with
    | "health" | "cancel" ->
        if string_field "method" request = "health" then begin
          output_string stderr (String.make 131072 'x');
          flush stderr
        end;
        respond [("id", String id); ("version", Number 1.0); ("ok", Bool true); ("payload", String "")]
    | "echo" ->
        respond [
          ("id", String id);
          ("version", Number 1.0);
          ("ok", Bool true);
          ("payload", String (string_field "payload" request));
        ]
    | "denied" ->
        respond [
          ("id", String id);
          ("version", Number 1.0);
          ("ok", Bool false);
          ("code", String "CAPABILITY_DENIED");
          ("message", String "denied");
        ]
    | "block" -> Unix.sleepf 30.0
    | "shutdown" ->
        respond [("id", String id); ("version", Number 1.0); ("ok", Bool true); ("payload", String "")];
        exit 0
    | _ ->
        respond [
          ("id", String id);
          ("version", Number 1.0);
          ("ok", Bool false);
          ("code", String "NOT_FOUND");
          ("message", String "unknown method");
        ]

let handle_line line =
  match (try Some (parse_json line) with Json_error _ -> None) with
  | Some (Object _ as request) -> handle_request request
  | Some _ | None -> ()

let () =
  try
    while true do
      handle_line (input_line stdin)
    done
  with End_of_file -> ()
