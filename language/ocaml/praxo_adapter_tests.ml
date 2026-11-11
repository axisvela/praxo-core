let fail message = raise (Failure message)

let check condition message = if not condition then fail message

let field name = function
  | Praxo_core.Object fields ->
      let rec last = function
        | [] -> None
        | (key, value) :: rest ->
            begin match last rest with
            | Some _ as found -> found
            | None -> if key = name then Some value else None
            end
      in
      last fields
  | _ -> None

let string_field name value =
  match field name value with
  | Some (Praxo_core.String text) -> text
  | _ -> fail ("missing string " ^ name)

let array_field name value =
  match field name value with
  | Some (Praxo_core.Array items) -> items
  | _ -> fail ("missing array " ^ name)

let check_code expected thunk =
  try ignore (thunk ()); check (expected = "") ("expected error " ^ expected)
  with Praxo_core.Core_error (code, _) -> check (code = expected) ("error code " ^ code)

let test_openai_adapter () =
  let captured = ref None in
  let transport http =
    captured := Some http;
    {
      Praxo_core.http_status = 200;
      http_body = "{\"choices\":[{\"message\":{\"content\":\"done\",\"tool_calls\":[{\"id\":\"call-1\",\"type\":\"function\",\"function\":{\"name\":\"echo\",\"arguments\":\"{\\\"text\\\":\\\"hi\\\"}\"}}]},\"finish_reason\":\"tool_calls\"}],\"usage\":{\"prompt_tokens\":3,\"completion_tokens\":2}}";
    }
  in
  let config = {
    Praxo_core.openai_base_url = "https://api.example.com/v1/";
    openai_model = "test-model";
    openai_api_key = Some "secret";
    openai_tool_choice = Some "auto";
  } in
  let request = Praxo_core.request_make
    [
      Praxo_core.text_message "user" "hi";
      Praxo_core.tool_message "{}" "call-1";
    ]
    [Praxo_core.tool_spec_make "echo" "Echo"] in
  let response = Praxo_core.openai_generate config transport request in
  check (response.Praxo_core.response_message.Praxo_core.message_content = "done") "openai content";
  check (response.Praxo_core.response_usage.Praxo_core.input_tokens = 3 &&
         response.Praxo_core.response_usage.Praxo_core.output_tokens = 2) "openai usage";
  (match response.Praxo_core.response_message.Praxo_core.message_calls with
   | [call] ->
       check (call.Praxo_core.invocation_id = "call-1") "openai call id";
       check (call.Praxo_core.invocation_name = "echo") "openai call name";
       check (Praxo_core.json_equal call.Praxo_core.invocation_arguments
         (Praxo_core.Object [("text", Praxo_core.String "hi")])) "openai call arguments"
   | _ -> fail "openai call count");
  let http = match !captured with Some value -> value | None -> fail "openai transport" in
  check (http.Praxo_core.http_method = "POST") "openai method";
  check (http.Praxo_core.http_url = "https://api.example.com/v1/chat/completions") "openai url";
  check (List.assoc_opt "Authorization" http.Praxo_core.http_headers = Some "Bearer secret") "openai auth";
  let payload = Praxo_core.parse_json http.Praxo_core.http_payload in
  check (string_field "model" payload = "test-model") "openai model";
  check (string_field "tool_choice" payload = "auto") "openai tool choice";
  let payload_messages = array_field "messages" payload in
  check (List.length payload_messages = 2) "openai messages";
  check (string_field "tool_call_id" (List.nth payload_messages 1) = "call-1") "openai tool id";
  let payload_tools = array_field "tools" payload in
  check (List.length payload_tools = 1) "openai tools";
  check (string_field "name"
    (match field "function" (List.hd payload_tools) with
     | Some value -> value
     | None -> fail "openai function") = "echo") "openai tool name";
  let error_transport _ = { Praxo_core.http_status = 503; http_body = "down" } in
  check_code "PROVIDER_HTTP" (fun () ->
    ignore (Praxo_core.openai_generate config error_transport request));
  let missing = { config with Praxo_core.openai_base_url = "" } in
  check_code "PROVIDER_HTTP" (fun () ->
    ignore (Praxo_core.openai_generate missing (fun _ -> fail "openai transport called") request));
  let invalid_transport _ = {
    Praxo_core.http_status = 200;
    http_body = "{\"choices\":[{\"message\":{\"tool_calls\":[{\"id\":\"c\",\"function\":{\"name\":\"x\",\"arguments\":\"{bad\"}}]}}]}";
  } in
  check_code "PROVIDER_RESPONSE" (fun () ->
    ignore (Praxo_core.openai_generate config invalid_transport request));
  print_endline "test_openai_adapter passed"

let test_anthropic_adapter () =
  let captured = ref None in
  let transport http =
    captured := Some http;
    {
      Praxo_core.http_status = 200;
      http_body = "{\"content\":[{\"type\":\"text\",\"text\":\"hello\"},{\"type\":\"tool_use\",\"id\":\"tool-1\",\"name\":\"echo\",\"input\":{\"text\":\"hi\"}}],\"stop_reason\":\"end_turn\",\"usage\":{\"input_tokens\":3,\"output_tokens\":4}}";
    }
  in
  let config = {
    Praxo_core.anthropic_base_url = "https://api.anthropic.com/";
    anthropic_model = "claude-test";
    anthropic_api_key = "ak";
    anthropic_version = "2023-06-01";
    anthropic_max_tokens = 1024;
    anthropic_tool_choice = Some "auto";
  } in
  let request = Praxo_core.request_make
    [Praxo_core.text_message "system" "be brief"; Praxo_core.text_message "user" "hi"]
    [Praxo_core.tool_spec_make "echo" "Echo"] in
  let response = Praxo_core.anthropic_generate config transport request in
  check (response.Praxo_core.response_message.Praxo_core.message_content = "hello") "anthropic content";
  check (response.Praxo_core.response_usage.Praxo_core.input_tokens = 3) "anthropic usage";
  (match response.Praxo_core.response_message.Praxo_core.message_calls with
   | [call] ->
       check (call.Praxo_core.invocation_id = "tool-1") "anthropic call id";
       check (call.Praxo_core.invocation_name = "echo") "anthropic call name";
       check (Praxo_core.json_equal call.Praxo_core.invocation_arguments
         (Praxo_core.Object [("text", Praxo_core.String "hi")])) "anthropic arguments"
   | _ -> fail "anthropic call count");
  let http = match !captured with Some value -> value | None -> fail "anthropic transport" in
  check (http.Praxo_core.http_url = "https://api.anthropic.com/v1/messages") "anthropic url";
  check (List.assoc_opt "x-api-key" http.Praxo_core.http_headers = Some "ak") "anthropic key";
  let payload = Praxo_core.parse_json http.Praxo_core.http_payload in
  check (string_field "model" payload = "claude-test") "anthropic model";
  check (string_field "system" payload = "be brief") "anthropic system";
  check (List.length (array_field "tools" payload) = 1) "anthropic tools";
  print_endline "test_anthropic_adapter passed"

let test_gemini_adapter () =
  let captured = ref None in
  let transport http =
    captured := Some http;
    {
      Praxo_core.http_status = 200;
      http_body = "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"hello\"},{\"functionCall\":{\"name\":\"echo\",\"args\":{\"text\":\"hi\"}}}]},\"finishReason\":\"STOP\"}],\"usageMetadata\":{\"promptTokenCount\":3,\"candidatesTokenCount\":4}}";
    }
  in
  let config = {
    Praxo_core.gemini_base_url = "https://generativelanguage.googleapis.com/";
    gemini_model = "gemini-test";
    gemini_api_key = "gk";
    gemini_max_output_tokens = 0;
    gemini_tool_choice = Some "auto";
  } in
  let request = Praxo_core.request_make
    [Praxo_core.text_message "system" "be brief"; Praxo_core.text_message "user" "hi"]
    [Praxo_core.tool_spec_make "echo" "Echo"] in
  let response = Praxo_core.gemini_generate config transport request in
  check (response.Praxo_core.response_message.Praxo_core.message_content = "hello") "gemini content";
  check (response.Praxo_core.response_usage.Praxo_core.input_tokens = 3) "gemini usage";
  (match response.Praxo_core.response_message.Praxo_core.message_calls with
   | [call] -> check (call.Praxo_core.invocation_name = "echo") "gemini call name"
   | _ -> fail "gemini call count");
  let http = match !captured with Some value -> value | None -> fail "gemini transport" in
  check (Praxo_core.ends_with ":generateContent" http.Praxo_core.http_url) "gemini url";
  check (List.assoc_opt "x-goog-api-key" http.Praxo_core.http_headers = Some "gk") "gemini key";
  let payload = Praxo_core.parse_json http.Praxo_core.http_payload in
  check (List.length (array_field "parts" (match field "system_instruction" payload with Some value -> value | None -> fail "gemini system")) = 1) "gemini system";
  print_endline "test_gemini_adapter passed"

let test_harmovela () =
  let requests = ref [] in
  let transport request =
    requests := !requests @ [request];
    { Praxo_core.http_status = 201; http_body = "" }
  in
  let config = Praxo_core.harmovela_config
    "http://harmovela.test/aep/api/" transport
    (fun () -> 1794294000000000000) in
  let event = Praxo_core.event_make "tool.call" "s1" (Some "run-123")
    (Praxo_core.Object [("name", Praxo_core.String "echo")]) in
  Praxo_core.harmovela_emit config event;
  let request = List.hd !requests in
  check (request.Praxo_core.http_method = "POST") "harmovela method";
  check (request.Praxo_core.http_url = "http://harmovela.test/aep/api/events")
    "harmovela path";
  check (List.assoc_opt "content-type" request.Praxo_core.http_headers =
    Some "application/json") "harmovela content type";
  let envelope = Praxo_core.parse_json request.Praxo_core.http_payload in
  check (string_field "spec_version" envelope = "0.2") "harmovela spec";
  check (string_field "id" envelope = "run-123-1794294000000000000") "harmovela id";
  check (string_field "type" envelope = "tool.call") "harmovela type";
  check (string_field "source" envelope = "praxo-core") "harmovela source";
  check (string_field "created_at" envelope = "2026-11-10T07:00:00.000000000Z")
    "harmovela created at";
  let payload = match field "payload" envelope with
    | Some value -> value
    | None -> fail "harmovela payload" in
  check (string_field "name" payload = "echo") "harmovela payload data";
  check (string_field "session_id" payload = "s1") "harmovela payload session";
  check (string_field "run_id" payload = "run-123") "harmovela payload run";

  let custom_requests = ref [] in
  let custom_transport request =
    custom_requests := !custom_requests @ [request];
    { Praxo_core.http_status = 204; http_body = "" }
  in
  let custom = { (Praxo_core.harmovela_config
      "http://harmovela.test" custom_transport
      (fun () -> 1794294000000000000)) with
    Praxo_core.harmovela_source = "custom";
    Praxo_core.harmovela_spec_version = "0.3";
  } in
  let merged = Praxo_core.event_make "tool.call" "s1" None
    (Praxo_core.Object [
      ("name", Praxo_core.String "echo");
      ("session_id", Praxo_core.String "event-side");
      ("run_id", Praxo_core.String "old");
    ]) in
  Praxo_core.harmovela_emit custom merged;
  let custom_envelope =
    Praxo_core.parse_json (List.hd !custom_requests).Praxo_core.http_payload in
  check (string_field "source" custom_envelope = "custom") "harmovela custom source";
  check (string_field "spec_version" custom_envelope = "0.3")
    "harmovela custom spec";
  check (Praxo_core.starts_with "s1-" (string_field "id" custom_envelope))
    "harmovela session prefix";
  let custom_payload = match field "payload" custom_envelope with
    | Some value -> value
    | None -> fail "harmovela custom payload" in
  check (string_field "session_id" custom_payload = "s1")
    "harmovela session override";
  check (string_field "run_id" custom_payload = "old")
    "harmovela data run retained";

  List.iter (fun status ->
    let accepted = Praxo_core.harmovela_config "http://harmovela.test"
      (fun _ -> { Praxo_core.http_status = status; http_body = "" })
      (fun () -> 1) in
    Praxo_core.harmovela_emit accepted event) [200; 201; 204; 299];

  let failing = Praxo_core.harmovela_config "http://harmovela.test"
    (fun _ -> {
      Praxo_core.http_status = 503;
      http_body = String.concat "" (List.init 100 (fun _ -> "service down "));
    })
    (fun () -> 1) in
  (try
     Praxo_core.harmovela_emit failing event;
     fail "harmovela non-2xx accepted"
   with Praxo_core.Core_error (code, message) ->
     check (code = "HARMOVELA_HTTP") "harmovela error code";
     check (Praxo_core.starts_with "harmovela: HTTP 503: service down" message)
       "harmovela error status and body";
     check (String.length message <= 600) "harmovela error bounded");

  let missing = Praxo_core.harmovela_config "" (fun _ -> fail "harmovela transport")
    (fun () -> 1) in
  check_code "HARMOVELA_URL" (fun () -> Praxo_core.harmovela_emit missing event);
  print_endline "test_harmovela passed"
