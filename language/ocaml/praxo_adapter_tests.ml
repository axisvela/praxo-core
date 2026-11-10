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
