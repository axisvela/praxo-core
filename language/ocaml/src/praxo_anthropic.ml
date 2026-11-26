open Praxo_types
open Praxo_json
open Praxo_message
open Praxo_provider_util
let anthropic_message_json message =
  let content = ref [] in
  if message.message_content <> "" then
    content := !content @ [Object [("type", String "text"); ("text", String message.message_content)]];
  List.iter (fun block ->
    if block.block_type = "text" then
      match block.block_text with
      | Some text when text <> "" ->
          content := !content @ [Object [("type", String "text"); ("text", String text)]]
      | _ -> ()) message.message_blocks;
  List.iter (fun call ->
    content := !content @ [Object [
      ("type", String "tool_use");
      ("id", String call.invocation_id);
      ("name", String call.invocation_name);
      ("input", call.invocation_arguments);
    ]]) message.message_calls;
  !content

let anthropic_request ?(stream = false) config request =
  if config.anthropic_base_url = "" then
    raise_core "PROVIDER_HTTP" "provider base URL is required";
  if config.anthropic_api_key = "" then
    raise_core "MODEL_CONFIG" "anthropic: API key is required";
  if config.anthropic_model = "" then
    raise_core "MODEL_CONFIG" "anthropic: model is required";
  let system = ref [] in
  let messages = ref [] in
  let pending = ref [] in
  let flush () =
    if !pending <> [] then begin
      messages := !messages @ [Object [("role", String "user"); ("content", Array !pending)]];
      pending := []
    end
  in
  List.iter (fun message ->
    if message.message_role = "system" then
      system := !system @ [message.message_content]
    else if message.message_role = "tool" then
      pending := !pending @ [Object [
        ("type", String "tool_result");
        ("tool_use_id", String (match message.message_tool_id with Some value -> value | None -> ""));
        ("content", String message.message_content);
      ]]
    else begin
      flush ();
      let content = anthropic_message_json message in
      if content <> [] then
        messages := !messages @ [Object [("role", String message.message_role); ("content", Array content)]]
    end) request.request_messages;
  flush ();
  let fields = ref [
    ("model", String config.anthropic_model);
    ("max_tokens", Number (float_of_int config.anthropic_max_tokens));
    ("messages", Array !messages);
  ] in
  if !system <> [] then fields := !fields @ [("system", String (String.concat "\n\n" !system))];
  if request.request_tools <> [] then begin
    fields := !fields @ [("tools", Array (List.map (fun spec -> Object [
      ("name", String spec.spec_name);
      ("description", String spec.spec_description);
      ("input_schema", Object [("type", String "object")]);
    ]) request.request_tools))];
    (match config.anthropic_tool_choice with
     | Some "auto" -> fields := !fields @ [("tool_choice", Object [("type", String "auto")])]
     | Some "required" -> fields := !fields @ [("tool_choice", Object [("type", String "any")])]
     | Some "none" -> fields := !fields @ [("tool_choice", Object [("type", String "none")])]
     | _ -> ())
  end;
  if stream then fields := !fields @ [("stream", Bool true)];
  let accept = if stream then "text/event-stream" else "application/json" in
  {
    http_method = "POST";
    http_url = provider_trim config.anthropic_base_url ^ "/v1/messages";
    http_headers = [
      ("Content-Type", "application/json");
      ("Accept", accept);
      ("x-api-key", config.anthropic_api_key);
      ("anthropic-version", config.anthropic_version);
    ];
    http_payload = encode_json (Object !fields);
  }

let anthropic_parse_response text =
  let data =
    try parse_json text
    with Json_error message ->
      raise_core "PROVIDER_RESPONSE" ("provider returned invalid JSON: " ^ message)
  in
  if field "error" data <> None then raise_core "PROVIDER_HTTP" "anthropic: provider error";
  let content = Buffer.create 64 in
  let calls = ref [] in
  List.iter (fun block ->
    match field_string "type" block with
    | Some "text" ->
        (match field_string "text" block with
         | Some value -> Buffer.add_string content value
         | None -> ())
    | Some "tool_use" ->
        let arguments = match field "input" block with Some (Object _ as value) -> value | _ -> Object [] in
        calls := !calls @ [tool_invocation_make
          (match field_string "id" block with Some value -> value | None -> "")
          (match field_string "name" block with Some value -> value | None -> "")
          arguments]
    | _ -> ()) (field_array "content" data);
  let usage = match field "usage" data with Some value -> value | None -> Object [] in
  response_make (assistant_message (Buffer.contents content) !calls)
    (usage_make (openai_int "input_tokens" usage) (openai_int "output_tokens" usage))

let anthropic_generate config transport request =
  let http = anthropic_request config request in
  let response = transport http in
  if response.http_status < 200 || response.http_status >= 300 then
    raise_core "PROVIDER_HTTP"
      (Printf.sprintf "provider returned HTTP %d: %s" response.http_status (openai_bound response.http_body));
  anthropic_parse_response response.http_body

let anthropic_parse_sse text on_delta =
  let content = Buffer.create 256 in
  let calls : (int, string * string * string) Hashtbl.t = Hashtbl.create 8 in
  let input_tokens = ref 0 in
  let output_tokens = ref 0 in
  let cached_tokens = ref 0 in
  let stop_reason = ref None in
  let done_stream = ref false in
  List.iter (fun raw ->
    let line = String.trim raw in
    if String.length line >= 5 && String.sub line 0 5 = "data:" then begin
      let chunk = String.trim (String.sub line 5 (String.length line - 5)) in
      if chunk <> "" then begin
        let event =
          try parse_json chunk
          with Json_error message ->
            raise_core "MODEL_STREAM" ("invalid SSE packet: " ^ message)
        in
        match (match field_string "type" event with Some value -> value | None -> "") with
        | "message_start" ->
            let message = match field "message" event with Some value -> value | None -> Object [] in
            (match field "usage" message with
             | Some usage ->
                 input_tokens := openai_int "input_tokens" usage;
                 cached_tokens := openai_int "cache_read_input_tokens" usage
             | None -> ())
        | "content_block_start" ->
            let index =
              match field "index" event with
              | Some (Number number) -> int_of_float number
              | _ -> Hashtbl.length calls
            in
            let block = match field "content_block" event with Some value -> value | None -> Object [] in
            if (match field_string "type" block with Some value -> value | None -> "") = "tool_use" then
              Hashtbl.replace calls index
                ((match field_string "id" block with Some value -> value | None -> ""),
                 (match field_string "name" block with Some value -> value | None -> ""),
                 "")
        | "content_block_delta" ->
            let index =
              match field "index" event with
              | Some (Number number) -> int_of_float number
              | _ -> 0
            in
            let delta = match field "delta" event with Some value -> value | None -> Object [] in
            (match field_string "type" delta with
             | Some "text_delta" ->
                 (match field_string "text" delta with
                  | Some piece when piece <> "" ->
                      Buffer.add_string content piece;
                      on_delta piece
                  | _ -> ())
             | Some "input_json_delta" ->
                 (match field_string "partial_json" delta with
                  | Some partial ->
                      let id, name, arguments =
                        match Hashtbl.find_opt calls index with
                        | Some value -> value
                        | None -> ("", "", "")
                      in
                      Hashtbl.replace calls index (id, name, arguments ^ partial)
                  | None -> ())
             | _ -> ())
        | "message_delta" ->
            let delta = match field "delta" event with Some value -> value | None -> Object [] in
            (match field_string "stop_reason" delta with
             | Some reason -> stop_reason := Some reason
             | None -> ());
            (match field "usage" event with
             | Some usage -> output_tokens := openai_int "output_tokens" usage
             | None -> ())
        | "message_stop" -> done_stream := true
        | "error" -> raise_core "MODEL_STREAM" "anthropic: provider stream error"
        | _ -> ()
      end
    end
  ) (String.split_on_char '\n' text);
  if not !done_stream && !stop_reason = None then
    raise_core "MODEL_STREAM" "stream ended before completion";
  let indexes = Hashtbl.fold (fun index _ acc -> index :: acc) calls [] |> List.sort compare in
  let tool_calls = List.filter_map (fun index ->
    match Hashtbl.find_opt calls index with
    | None -> None
    | Some (_, name, _) when name = "" -> None
    | Some (id, name, arguments) ->
        let parsed =
          if arguments = "" then Object []
          else
            try parse_json arguments
            with Json_error message ->
              raise_core "PROVIDER_JSON" ("anthropic: tool arguments are not valid JSON: " ^ message)
        in
        (match parsed with
         | Object _ -> Some (tool_invocation_make id name parsed)
         | _ -> raise_core "PROVIDER_JSON" "anthropic: tool arguments must be an object")
  ) indexes in
  response_make (assistant_message (Buffer.contents content) tool_calls)
    (usage_make !input_tokens !output_tokens)

let anthropic_generate_stream config transport request on_delta =
  let http = anthropic_request ~stream:true config request in
  let response = transport http in
  if response.http_status < 200 || response.http_status >= 300 then
    raise_core "PROVIDER_HTTP"
      (Printf.sprintf "provider returned HTTP %d: %s" response.http_status (openai_bound response.http_body));
  anthropic_parse_sse response.http_body on_delta

let anthropic_model config transport =
  {
    generate = (fun request -> anthropic_generate config transport request);
    generate_stream = Some (fun request on_delta ->
      anthropic_generate_stream config transport request on_delta);
  }

