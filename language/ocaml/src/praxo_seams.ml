open Praxo_types
open Praxo_json
open Praxo_message
let mcp_client ?(client_version = "0.5.0") ?(protocol_version = "2024-11-05") transport =
  let client_version = if client_version = "" then "0.5.0" else client_version in
  let protocol_version =
    if protocol_version = "" then "2024-11-05" else protocol_version
  in
  let params = Object [
    ("protocolVersion", String protocol_version);
    ("capabilities", Object []);
    ("clientInfo", Object [
      ("name", String "praxo-core");
      ("version", String client_version);
    ]);
  ] in
  let result = transport "initialize" params in
  (match result with
   | Object _ -> ()
   | _ -> raise_core "MCP_PROTOCOL" "mcp: initialize result must be an object");
  let version = match field "protocolVersion" result with
    | Some (String value) -> value
    | _ -> ""
  in
  if version = "" then
    raise_core "MCP_HANDSHAKE" "mcp: initialize returned no protocol version";
  let server_info = match field "serverInfo" result with
    | Some (Object _ as info) -> info
    | _ -> Object []
  in
  ignore (transport "notifications/initialized" (Object []));
  { mcp_transport = transport;
    mcp_client_version = client_version;
    mcp_protocol_version = version;
    mcp_server_info = server_info;
    mcp_closed = false;
  }

let mcp_ensure_open client =
  if client.mcp_closed then raise_core "MCP_CLOSED" "mcp: client is closed"

let mcp_list_tools client =
  mcp_ensure_open client;
  let tools = ref [] in
  let names = Hashtbl.create 8 in
  let cursors = Hashtbl.create 8 in
  let cursor = ref "" in
  let finished = ref false in
  while not !finished do
    let params =
      if !cursor = "" then Object []
      else Object [("cursor", String !cursor)]
    in
    let result = client.mcp_transport "tools/list" params in
    let items = match field "tools" result with
      | Some (Array values) -> values
      | _ -> raise_core "MCP_PROTOCOL" "mcp: tools/list tools must be an array"
    in
    List.iter (fun item ->
      let name = match item with
        | Object _ ->
            (match field "name" item with Some (String name) -> name | _ -> "")
        | _ -> ""
      in
      if name = "" then raise_core "MCP_PROTOCOL" "mcp: tool name is required";
      if Hashtbl.mem names name then
        raise_core "MCP_DUPLICATE_TOOL" ("mcp: duplicate tool " ^ name);
      Hashtbl.replace names name ();
      tools := item :: !tools
    ) items;
    let next = match field "nextCursor" result with
      | Some (String value) -> value
      | Some _ -> raise_core "MCP_PROTOCOL" "mcp: nextCursor must be a string"
      | None -> ""
    in
    if next = "" then finished := true
    else begin
      if Hashtbl.mem cursors next then
        raise_core "MCP_PAGINATION" "mcp: repeated tool pagination cursor";
      Hashtbl.replace cursors next ();
      cursor := next
    end
  done;
  List.rev !tools

let mcp_call_tool client name arguments =
  mcp_ensure_open client;
  if name = "" then raise_core "MCP_PROTOCOL" "mcp: tool name is required";
  let result = client.mcp_transport "tools/call" (Object [
    ("name", String name);
    ("arguments", arguments);
  ]) in
  (match result with
   | Object _ -> ()
   | _ -> raise_core "MCP_PROTOCOL" "mcp: tools/call result must be an object");
  (match field_bool "isError" result with
   | Some true -> raise_core "MCP_TOOL_ERROR" ("mcp: tool " ^ name ^ " failed")
   | _ -> ());
  match field "structuredContent" result with
  | Some value -> value
  | None ->
      let texts =
        field_array "content" result
        |> List.filter_map (fun item ->
             match item with
             | Object _ ->
                 (match field "type" item, field "text" item with
                  | Some (String "text"), Some (String text) -> Some text
                  | _ -> None)
             | _ -> None)
      in
      (match texts with
       | [] -> Null
       | [text] -> String text
       | _ -> Array (List.map (fun text -> String text) texts))

let mcp_close client = client.mcp_closed <- true

let otel_sink_new endpoint transport clock = {
  otel_endpoint = endpoint;
  otel_service_name = "praxo-core";
  otel_allowed_data_keys = [];
  otel_clock = clock;
  otel_transport = transport;
}

let otel_attribute key value =
  Object [
    ("key", String key);
    ("value", Object [("stringValue", String value)]);
  ]

let otel_text value =
  match value with
  | String text -> text
  | _ -> json_text value

let otel_payload sink event nanos =
  let stamp = string_of_int nanos in
  let key =
    event.event_session_id ^ "|" ^
    (match event.event_run_id with Some run_id -> run_id | None -> "") ^ "|" ^
    event.event_type ^ "|" ^ stamp ^ "|" ^ json_text event.event_data
  in
  let hex prefix =
    Printf.sprintf "%016Lx" (Int64.of_int (Hashtbl.hash (prefix ^ key)))
  in
  let trace_id = hex "a" ^ hex "b" in
  let span_id = hex "s" in
  let attributes = ref [otel_attribute "praxo.event.type" event.event_type] in
  if event.event_session_id <> "" then
    attributes := !attributes @
      [otel_attribute "praxo.session.id" event.event_session_id];
  (match event.event_run_id with
   | Some run_id when run_id <> "" ->
       attributes := !attributes @ [otel_attribute "praxo.run.id" run_id]
   | _ -> ());
  attributes := !attributes @ [otel_attribute "praxo.event.at" stamp];
  List.iter (fun name ->
    match field name event.event_data with
    | Some value ->
        attributes := !attributes @
          [otel_attribute ("praxo.event.data." ^ name) (otel_text value)]
    | None -> ()) sink.otel_allowed_data_keys;
  let span = Object [
    ("traceId", String trace_id);
    ("spanId", String span_id);
    ("name", String ("praxo." ^ event.event_type));
    ("kind", Number 1.);
    ("startTimeUnixNano", String (string_of_int nanos));
    ("endTimeUnixNano", String (string_of_int nanos));
    ("attributes", Array !attributes);
  ] in
  Object [
    ("resourceSpans", Array [
      Object [
        ("resource", Object [
          ("attributes", Array [
            otel_attribute "service.name" sink.otel_service_name;
          ]);
        ]);
        ("scopeSpans", Array [
          Object [
            ("scope", Object [("name", String "praxo-core")]);
            ("spans", Array [span]);
          ];
        ]);
      ];
    ]);
  ]

let otel_emit sink event =
  let nanos = sink.otel_clock () in
  let body = encode_json (otel_payload sink event nanos) in
  let status, response_body =
    sink.otel_transport "POST" sink.otel_endpoint "application/json" body
  in
  if status < 200 || status >= 300 then begin
    let bounded =
      if String.length response_body > 512 then String.sub response_body 0 512
      else response_body
    in
    raise_core "OTEL_HTTP"
      ("otel: HTTP " ^ string_of_int status ^ ": " ^ bounded)
  end

let retrieve_documents retriever query limit =
  if limit < 0 then
    raise_core "RETRIEVER_INVALID" "retriever: invalid limit";
  retriever query limit

let subagent_run runner request =
  if request.request_parent_session_id = "" || request.request_agent_id = "" then
    raise_core "SUBAGENT_INVALID"
      "agent: subagent parent session and agent id are required";
  let timestamp = string_of_int (int_of_float (Sys.time ())) in
  let base = {
    task_id = "subagent";
    task_parent_session_id = request.request_parent_session_id;
    task_agent_id = request.request_agent_id;
    task_mode = if request.request_mode = "fork" then "fork" else "isolated";
    task_status = "running";
    task_output = "";
    task_error = "";
    task_created_at = timestamp;
    task_updated_at = timestamp;
  } in
  match (try Ok (runner request) with
    | Core_error (code, _) -> Error code
    | error -> Error (Printexc.to_string error)) with
  | Ok result ->
      { base with
        task_status = "completed";
        task_output = result.result_output;
        task_updated_at = timestamp;
      }
  | Error code ->
      { base with
        task_status = "failed";
        task_error = code;
        task_updated_at = timestamp;
      }

