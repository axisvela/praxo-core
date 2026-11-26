open Praxo_core

let object_field key value =
  match value with Object fields -> List.assoc_opt key fields | _ -> None

let string_field key value =
  match object_field key value with Some (String text) -> Some text | _ -> None

let effects = Hashtbl.create 8
let otel_spans = ref []
let harmovela_events = ref []
let child_calls = ref 0

let record_call id target =
  tool_invocation_make id "record" (Object [("target", String target)])

let tool_response call =
  response_make (assistant_message "" [call]) (usage_make 0 0)

let make_model steps final on_call =
  let remaining = ref steps in
  { generate = (fun _request ->
      (match on_call with Some callback -> callback () | None -> ());
      match !remaining with
      | step :: rest -> remaining := rest; step
      | [] -> response_make (assistant_message final []) (usage_make 0 0));
    generate_stream = None; }

let target_of action =
  match string_field "target" action.action_arguments with
  | Some value -> value
  | None -> ""

let parent_policy action =
  if action.action_kind = "model.generate" then decision_make true ""
  else if action.action_kind <> "tool.invoke" then
    decision_make false "unsupported action"
  else if action.action_tool_name = "record" then
    if target_of action = "blocked" then decision_make false "blocked target"
    else decision_make true ""
  else if action.action_tool_name = "delegate" then decision_make true ""
  else decision_make false "parent tool is not allowed"

let child_policy action =
  if action.action_kind = "model.generate" then decision_make true ""
  else if action.action_kind = "tool.invoke" && action.action_tool_name = "record"
  then decision_make true ""
  else decision_make false "child may only record"

let composed_policy action =
  let parent = parent_policy action in
  if not parent.decision_allowed then parent else child_policy action

let mcp_transport method_name params =
  match method_name with
  | "initialize" ->
      Object [
        ("protocolVersion", String "2024-11-05");
        ("serverInfo", Object [("name", String "fake-mcp")]);
      ]
  | "tools/list" ->
      Object [("tools", Array [
        Object [
          ("name", String "record");
          ("description", String "Record a target");
          ("inputSchema", Object [
            ("type", String "object");
            ("properties", Object [("target", Object [("type", String "string")])]);
            ("required", Array [String "target"]);
          ]);
        ];
      ])]
  | "tools/call" ->
      let arguments = match object_field "arguments" params with Some value -> value | None -> Object [] in
      let target = match string_field "target" arguments with Some value -> value | None -> "" in
      let count = try Hashtbl.find effects target with Not_found -> 0 in
      Hashtbl.replace effects target (count + 1);
      Object [("content", Array [
        Object [("type", String "text"); ("text", String ("recorded:" ^ target))];
      ])]
  | _ -> Object []

let () =
  let clock () = int_of_float (Sys.time () *. 1_000_000_000.) in
  let client = mcp_client mcp_transport in
  let tools = mcp_list_tools client in
  if List.length tools <> 1 then failwith "unexpected MCP tools";

  let record = tool_make "record" "Record a target through the MCP client"
    (fun arguments -> mcp_call_tool client "record" arguments) in

  let otel = otel_sink_new "http://otel.local/v1/traces"
    (fun _method _endpoint _content_type body ->
      let payload = parse_json body in
      List.iter (fun resource ->
        List.iter (fun scope ->
          List.iter (fun span ->
            match string_field "name" span with
            | Some name -> otel_spans := !otel_spans @ [name]
            | None -> ()) (field_array "spans" scope))
          (field_array "scopeSpans" resource))
        (field_array "resourceSpans" payload);
      (200, ""))
    clock in
  let harmovela = harmovela_config "http://harmovela.local"
    (fun request ->
      let payload = parse_json request.http_payload in
      (match string_field "type" payload with
       | Some kind -> harmovela_events := !harmovela_events @ [kind]
       | None -> ());
      { http_status = 202; http_body = "" })
    clock in
  let events = multi_sink [
    (fun event -> otel_emit otel event);
    harmovela_sink harmovela;
  ] in

  let delegate = tool_make "delegate"
    "Run a governed child agent with the narrowed record scope"
    (fun _arguments ->
      let child_model = make_model
        [tool_response (record_call "child-record" "child")] "DONE"
        (Some (fun () -> incr child_calls)) in
      let options = {
        (agent_options child_model) with
        agent_tools = [record];
        agent_allowed_tools = ["record"];
        agent_action_policy = Some composed_policy;
        agent_require_policy = true;
        agent_require_tool_scope = true;
        agent_events = Some events;
        agent_max_steps = 3;
      } in
      let result = run_agent options (session_make "chain-child" []) "record child" in
      Object [("output", String result.result_output)]) in

  let parent_model = make_model [
    tool_response (record_call "parent-record" "parent");
    tool_response (tool_invocation_make "parent-delegate" "delegate"
      (Object [("task", String "record child")]));
  ] "DONE" None in
  let parent_options = {
    (agent_options parent_model) with
    agent_tools = [record; delegate];
    agent_allowed_tools = ["record"; "delegate"];
    agent_action_policy = Some parent_policy;
    agent_require_policy = true;
    agent_require_tool_scope = true;
    agent_events = Some events;
    agent_max_steps = 4;
  } in
  let parent = run_agent parent_options (session_make "chain-parent" [])
    "record parent, then delegate" in

  let denied_model = make_model [
    tool_response (record_call "denied-record" "edit-me");
  ] "DONE" None in
  let denied_options = {
    (agent_options denied_model) with
    agent_tools = [record];
    agent_allowed_tools = ["record"];
    agent_action_policy = Some parent_policy;
    agent_require_policy = true;
    agent_require_tool_scope = true;
    agent_events = Some events;
    agent_max_steps = 2;
    agent_interrupt_on = ["record"];
    agent_on_interrupt_decision = Some (fun _interrupt ->
      interrupt_decision_make ~arguments:(Object [("target", String "blocked")]) "edit");
  } in
  let denied_error =
    try
      ignore (run_agent denied_options (session_make "chain-denied" [])
        "attempt a denied edit");
      ""
    with Core_error (code, _) -> code in

  mcp_close client;
  Printf.printf "output: %s\n" parent.result_output;
  Printf.printf "effects: parent=%d child=%d\n"
    (try Hashtbl.find effects "parent" with Not_found -> 0)
    (try Hashtbl.find effects "child" with Not_found -> 0);
  Printf.printf "child calls: %d\n" !child_calls;
  Printf.printf "otel spans: %d\n" (List.length !otel_spans);
  Printf.printf "harmovela events: %d\n" (List.length !harmovela_events);
  Printf.printf "denied effects: %d\n"
    (try Hashtbl.find effects "blocked" with Not_found -> 0);
  assert (parent.result_output = "DONE");
  assert ((try Hashtbl.find effects "parent" with Not_found -> 0) = 1);
  assert ((try Hashtbl.find effects "child" with Not_found -> 0) = 1);
  assert (!child_calls = 2);
  assert (List.length !otel_spans >= 3);
  assert (List.length !harmovela_events >= 3);
  assert ((try Hashtbl.find effects "blocked" with Not_found -> 0) = 0);
  assert (denied_error <> "")
