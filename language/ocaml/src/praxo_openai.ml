open Praxo_types
open Praxo_json
open Praxo_message
open Praxo_provider_util
let openai_message_json message =
  let content =
    if message.message_content = "" && message.message_blocks <> [] then
      String.concat "" (List.filter_map (fun block ->
        if block.block_type = "text" then block.block_text else None) message.message_blocks)
    else message.message_content
  in
  let fields = ref [("role", String message.message_role); ("content", String content)] in
  if message.message_role = "assistant" && message.message_calls <> [] then
    fields := !fields @ [("tool_calls", Array (List.map (fun call -> Object [
      ("id", String call.invocation_id);
      ("type", String "function");
      ("function", Object [
        ("name", String call.invocation_name);
        ("arguments", String (encode_json call.invocation_arguments));
      ]);
    ]) message.message_calls))];
  (match message.message_tool_id with
   | Some tool_id when message.message_role = "tool" ->
       fields := !fields @ [("tool_call_id", String tool_id)]
   | _ -> ());
  Object !fields

let openai_request ?(stream = false) config request =
  if config.openai_base_url = "" then
    raise_core "PROVIDER_HTTP" "provider base URL is required";
  let base =
    let rec trim text =
      let length = String.length text in
      if length > 0 && text.[length - 1] = '/' then trim (String.sub text 0 (length - 1))
      else text
    in
    trim config.openai_base_url
  in
  let fields = ref [
    ("model", String config.openai_model);
    ("messages", Array (List.map openai_message_json request.request_messages));
  ] in
  if request.request_tools <> [] then
    fields := !fields @ [("tools", Array (List.map (fun spec -> Object [
      ("type", String "function");
      ("function", Object [
        ("name", String spec.spec_name);
        ("description", String spec.spec_description);
        ("parameters", Object [("type", String "object")]);
      ]);
    ]) request.request_tools))];
  (match config.openai_tool_choice with
   | Some choice -> fields := !fields @ [("tool_choice", String choice)]
   | None -> ());
  if stream then fields := !fields @ [("stream", Bool true)];
  let accept = if stream then "text/event-stream" else "application/json" in
  let headers =
    [("Content-Type", "application/json"); ("Accept", accept)] @
    (match config.openai_api_key with
     | Some key -> [("Authorization", "Bearer " ^ key)]
     | None -> [])
  in
  {
    http_method = "POST";
    http_url = base ^ "/chat/completions";
    http_headers = headers;
    http_payload = encode_json (Object !fields);
  }

let openai_parse_response text =
  let data =
    try parse_json text
    with Json_error message ->
      raise_core "PROVIDER_RESPONSE" ("provider returned invalid JSON: " ^ message)
  in
  match field_array "choices" data with
  | [] -> raise_core "PROVIDER_RESPONSE" "provider response has no choices"
  | choice :: _ ->
      let message =
        match field "message" choice with Some value -> value | None -> Object []
      in
      let calls = List.map (fun item ->
        let function_value =
          match field "function" item with Some value -> value | None -> Object []
        in
        let arguments =
          match field "arguments" function_value with
          | Some (String raw) when raw <> "" ->
              (try match parse_json raw with
                | Object _ as value -> value
                | _ -> raise_core "PROVIDER_RESPONSE" "tool arguments must be an object"
               with Json_error message ->
                 raise_core "PROVIDER_RESPONSE" ("tool arguments are not valid JSON: " ^ message))
          | Some (Object _ as value) -> value
          | _ -> Object []
        in
        tool_invocation_make
          (match field_string "id" item with Some value -> value | None -> "")
          (match field_string "name" function_value with Some value -> value | None -> "")
          arguments) (field_array "tool_calls" message)
      in
      let usage =
        match field "usage" data with Some value -> value | None -> Object []
      in
      let content =
        match field_string "content" message with Some value -> value | None -> ""
      in
      response_make (assistant_message content calls)
        (usage_make (openai_int "prompt_tokens" usage)
                    (openai_int "completion_tokens" usage))

let openai_generate config transport request =
  let http = openai_request config request in
  let response = transport http in
  if response.http_status < 200 || response.http_status >= 300 then
    raise_core "PROVIDER_HTTP"
      (Printf.sprintf "provider returned HTTP %d: %s" response.http_status (openai_bound response.http_body));
  openai_parse_response response.http_body

let openai_parse_sse text on_delta =
  let content = Buffer.create 256 in
  let calls : (int, string * string * string) Hashtbl.t = Hashtbl.create 8 in
  let input_tokens = ref 0 in
  let output_tokens = ref 0 in
  let finish_reason = ref None in
  let done_stream = ref false in
  List.iter (fun raw ->
    let line = String.trim raw in
    if String.length line >= 5 && String.sub line 0 5 = "data:" then begin
      let chunk = String.trim (String.sub line 5 (String.length line - 5)) in
      if chunk <> "" then
        if chunk = "[DONE]" then done_stream := true
        else begin
          let event =
            try parse_json chunk
            with Json_error message ->
              raise_core "MODEL_STREAM" ("invalid SSE packet: " ^ message)
          in
          (match field "usage" event with
           | Some usage ->
               input_tokens := openai_int "prompt_tokens" usage;
               output_tokens := openai_int "completion_tokens" usage
           | None -> ());
          List.iter (fun choice ->
            (match field "delta" choice with
             | Some delta ->
                 (match field_string "content" delta with
                  | Some piece when piece <> "" ->
                      Buffer.add_string content piece;
                      on_delta piece
                  | _ -> ());
                 List.iter (fun item ->
                   let index =
                     match field "index" item with
                     | Some (Number number) -> int_of_float number
                     | _ -> Hashtbl.length calls
                   in
                   let id, name, arguments =
                     match Hashtbl.find_opt calls index with
                     | Some value -> value
                     | None -> ("", "", "")
                   in
                   let id =
                     match field_string "id" item with
                     | Some value -> id ^ value
                     | None -> id
                   in
                   let name, arguments =
                     match field "function" item with
                     | Some function_value ->
                         let name =
                           match field_string "name" function_value with
                           | Some value -> name ^ value
                           | None -> name
                         in
                         let arguments =
                           match field_string "arguments" function_value with
                           | Some value -> arguments ^ value
                           | None -> arguments
                         in
                         (name, arguments)
                     | None -> (name, arguments)
                   in
                   Hashtbl.replace calls index (id, name, arguments)
                 ) (field_array "tool_calls" delta)
             | None -> ());
            (match field_string "finish_reason" choice with
             | Some reason -> finish_reason := Some reason; done_stream := true
             | None -> ())
          ) (field_array "choices" event)
        end
    end
  ) (String.split_on_char '\n' text);
  if not !done_stream then
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
              raise_core "PROVIDER_JSON" ("tool arguments are not valid JSON: " ^ message)
        in
        (match parsed with
         | Object _ -> Some (tool_invocation_make id name parsed)
         | _ -> raise_core "PROVIDER_JSON" "tool arguments must be an object")
  ) indexes in
  response_make (assistant_message (Buffer.contents content) tool_calls)
    (usage_make !input_tokens !output_tokens)

let openai_generate_stream config transport request on_delta =
  let http = openai_request ~stream:true config request in
  let response = transport http in
  if response.http_status < 200 || response.http_status >= 300 then
    raise_core "PROVIDER_HTTP"
      (Printf.sprintf "provider returned HTTP %d: %s" response.http_status (openai_bound response.http_body));
  openai_parse_sse response.http_body on_delta

let openai_model config transport =
  {
    generate = (fun request -> openai_generate config transport request);
    generate_stream = Some (fun request on_delta ->
      openai_generate_stream config transport request on_delta);
  }

