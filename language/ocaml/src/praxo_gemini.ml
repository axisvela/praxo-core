open Praxo_types
open Praxo_json
open Praxo_message
open Praxo_provider_util
let gemini_message_parts message =
  let parts = ref [] in
  if message.message_content <> "" then parts := !parts @ [Object [("text", String message.message_content)]];
  List.iter (fun block ->
    if block.block_type = "text" then
      match block.block_text with
      | Some text when text <> "" -> parts := !parts @ [Object [("text", String text)]]
      | _ -> ()) message.message_blocks;
  List.iter (fun call -> parts := !parts @ [Object [("functionCall", Object [
    ("name", String call.invocation_name);
    ("args", call.invocation_arguments);
  ])]]) message.message_calls;
  !parts

let gemini_request ?(stream = false) config request =
  if config.gemini_base_url = "" then
    raise_core "PROVIDER_HTTP" "provider base URL is required";
  if config.gemini_api_key = "" then
    raise_core "MODEL_CONFIG" "gemini: API key is required";
  if config.gemini_model = "" then
    raise_core "MODEL_CONFIG" "gemini: model is required";
  let system = ref [] in
  let contents = ref [] in
  let pending = ref [] in
  let function_names = Hashtbl.create 8 in
  let flush () =
    if !pending <> [] then begin
      contents := !contents @ [Object [("role", String "user"); ("parts", Array !pending)]];
      pending := []
    end
  in
  List.iter (fun message ->
    if message.message_role = "system" then
      system := !system @ [Object [("text", String message.message_content)]]
    else if message.message_role = "tool" then
      let name =
        match message.message_tool_id with
        | Some id -> (match Hashtbl.find_opt function_names id with Some name -> name | None -> "tool")
        | None -> "tool"
      in
      pending := !pending @ [Object [("functionResponse", Object [
        ("name", String name);
        ("response", Object [("result", String message.message_content)]);
      ])]]
    else begin
      flush ();
      let parts = gemini_message_parts message in
      if parts <> [] then
        contents := !contents @ [Object [
          ("role", String (if message.message_role = "assistant" then "model" else "user"));
          ("parts", Array parts);
        ]];
      List.iter (fun call ->
        if call.invocation_id <> "" then
          Hashtbl.replace function_names call.invocation_id call.invocation_name)
        message.message_calls
    end) request.request_messages;
  flush ();
  let fields = ref [("contents", Array !contents)] in
  if !system <> [] then fields := !fields @ [("system_instruction", Object [("parts", Array !system)])];
  if request.request_tools <> [] then begin
    fields := !fields @ [("tools", Array [Object [
      ("functionDeclarations", Array (List.map (fun spec -> Object [
        ("name", String spec.spec_name);
        ("description", String spec.spec_description);
        ("parameters", Object [("type", String "object")]);
      ]) request.request_tools));
    ]])];
    let mode = match config.gemini_tool_choice with
      | Some "required" -> "ANY"
      | Some "none" -> "NONE"
      | _ -> "AUTO"
    in
    fields := !fields @ [("toolConfig", Object [("functionCallingConfig", Object [("mode", String mode)])])]
  end;
  if config.gemini_max_output_tokens > 0 then
    fields := !fields @ [("generationConfig", Object [
      ("maxOutputTokens", Number (float_of_int config.gemini_max_output_tokens));
    ])];
  {
    http_method = "POST";
    http_url =
      provider_trim config.gemini_base_url ^ "/v1beta/models/" ^ config.gemini_model ^
      (if stream then ":streamGenerateContent?alt=sse" else ":generateContent");
    http_headers = [
      ("Content-Type", "application/json");
      ("Accept", if stream then "text/event-stream" else "application/json");
      ("x-goog-api-key", config.gemini_api_key);
    ];
    http_payload = encode_json (Object !fields);
  }

let gemini_parse_response text =
  let data =
    try parse_json text
    with Json_error message ->
      raise_core "PROVIDER_RESPONSE" ("provider returned invalid JSON: " ^ message)
  in
  if field "error" data <> None then raise_core "PROVIDER_HTTP" "gemini: provider error";
  match field_array "candidates" data with
  | [] -> raise_core "PROVIDER_HTTP" "gemini: empty response"
  | candidate :: _ ->
      let content = match field "content" candidate with Some value -> value | None -> Object [] in
      let text = Buffer.create 64 in
      let calls = ref [] in
      List.iter (fun part ->
        (match field_string "text" part with Some value -> Buffer.add_string text value | None -> ());
        match field "functionCall" part with
        | Some call ->
            let arguments = match field "args" call with Some (Object _ as value) -> value | _ -> Object [] in
            calls := !calls @ [tool_invocation_make
              (Printf.sprintf "call-%d" (List.length !calls + 1))
              (match field_string "name" call with Some value -> value | None -> "") arguments]
        | None -> ()) (field_array "parts" content);
      let usage = match field "usageMetadata" data with Some value -> value | None -> Object [] in
      response_make (assistant_message (Buffer.contents text) !calls)
        (usage_make (openai_int "promptTokenCount" usage) (openai_int "candidatesTokenCount" usage))

let gemini_generate config transport request =
  let http = gemini_request config request in
  let response = transport http in
  if response.http_status < 200 || response.http_status >= 300 then
    raise_core "PROVIDER_HTTP"
      (Printf.sprintf "provider returned HTTP %d: %s" response.http_status (openai_bound response.http_body));
  gemini_parse_response response.http_body

let gemini_parse_sse text on_delta =
  let content = Buffer.create 256 in
  let calls = ref [] in
  let input_tokens = ref 0 in
  let output_tokens = ref 0 in
  let cached_tokens = ref 0 in
  List.iter (fun raw ->
    let line = String.trim raw in
    if String.length line >= 5 && String.sub line 0 5 = "data:" then begin
      let chunk = String.trim (String.sub line 5 (String.length line - 5)) in
      if chunk <> "" && chunk <> "[DONE]" then begin
        let event =
          try parse_json chunk
          with Json_error message ->
            raise_core "MODEL_STREAM" ("gemini: invalid stream chunk: " ^ message)
        in
        if field "error" event <> None then
          raise_core "MODEL_STREAM" "gemini: provider stream error";
        (match field "usageMetadata" event with
         | Some usage ->
             input_tokens := openai_int "promptTokenCount" usage;
             output_tokens := openai_int "candidatesTokenCount" usage;
             cached_tokens := openai_int "cachedContentTokenCount" usage
         | None -> ());
        match field_array "candidates" event with
        | [] -> ()
        | candidate :: _ ->
            (match field "content" candidate with
             | Some candidate_content ->
                 List.iter (fun part ->
                   (match field_string "text" part with
                    | Some piece when piece <> "" ->
                        Buffer.add_string content piece;
                        on_delta piece
                    | _ -> ());
                   match field "functionCall" part with
                   | Some call ->
                       let arguments =
                         match field "args" call with Some (Object _ as value) -> value | _ -> Object []
                       in
                       calls := !calls @ [tool_invocation_make
                         (Printf.sprintf "call-%d" (List.length !calls + 1))
                         (match field_string "name" call with Some value -> value | None -> "") arguments]
                   | None -> ()) (field_array "parts" candidate_content)
             | None -> ())
      end
    end
  ) (String.split_on_char '\n' text);
  response_make (assistant_message (Buffer.contents content) !calls)
    (usage_make !input_tokens !output_tokens)

let gemini_generate_stream config transport request on_delta =
  let http = gemini_request ~stream:true config request in
  let response = transport http in
  if response.http_status < 200 || response.http_status >= 300 then
    raise_core "PROVIDER_HTTP"
      (Printf.sprintf "provider returned HTTP %d: %s" response.http_status (openai_bound response.http_body));
  gemini_parse_sse response.http_body on_delta

let gemini_model config transport =
  {
    generate = (fun request -> gemini_generate config transport request);
    generate_stream = Some (fun request on_delta ->
      gemini_generate_stream config transport request on_delta);
  }

