let read_file path =
  let channel = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in channel)
    (fun () -> really_input_string channel (in_channel_length channel))

let fail message = raise (Failure message)

let check condition message = if not condition then fail message

let field name = function
  | Praxo.Object fields ->
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
  match field name value with Some (Praxo.String text) -> text | _ -> fail ("missing string " ^ name)

let bool_field name value =
  match field name value with Some (Praxo.Bool flag) -> flag | _ -> fail ("missing bool " ^ name)

let array_field name value =
  match field name value with Some (Praxo.Array items) -> items | _ -> fail ("missing array " ^ name)

let path_set paths = List.sort_uniq compare paths

let test_json () =
  let node = Praxo.parse_json "{\"a\":[true,false,null,{\"b\":\"x\"}],\"n\":1.5}" in
  check (Praxo.encode_json node <> "") "encode";
  check (match Praxo.parse_json "\"\\u00e9\\ud83d\\ude00\"" with
    | Praxo.String value -> String.length value = 6
    | _ -> false) "unicode";
  (try ignore (Praxo.parse_json ""); fail "empty accepted" with Praxo.Json_error _ -> ());
  (try ignore (Praxo.parse_json "{} {}"); fail "trailing accepted" with Praxo.Json_error _ -> ());
  (try ignore (Praxo.parse_json (String.make 66 '[' ^ "0" ^ String.make 66 ']')); fail "depth accepted" with Praxo.Json_error _ -> ());
  (try ignore (Praxo.parse_json (String.make 1048577 ' ')); fail "capacity accepted" with Praxo.Json_error _ -> ());
  print_endline "test_json passed"

let test_toolcall root =
  let document = Praxo.parse_json (read_file (Filename.concat root "vectors/toolcall.json")) in
  let vectors = array_field "vectors" document in
  List.iter (fun vector ->
    let input = match field "input" vector with Some value -> value | None -> fail "input" in
    let expect = match field "expect" vector with Some value -> value | None -> fail "expect" in
    let content = string_field "content" input in
    let operation = string_field "operation" input in
    if operation = "strip" then
      let stripped = Praxo.strip_tool_call_markup content in check (stripped = string_field "text" expect) ("strip vector: " ^ stripped)
    else begin
      match Praxo.parse_tool_call content with
      | None -> check (field "nil" expect = Some (Praxo.Bool true)) "expected no call"
      | Some call ->
          check (field "nil" expect <> Some (Praxo.Bool true)) "unexpected call";
          check (call.Praxo.name = string_field "name" expect) "call name";
          check (Praxo.json_equal call.Praxo.input (match field "input" expect with Some value -> value | None -> fail "expected input")) "call input"
    end) vectors;
  (match Praxo.parse_tool_call "<a.one>{}</a.one><b.two>{bad}</b.two>" with None -> () | Some _ -> fail "invalid final block");
  (match Praxo.parse_tool_call "{\"name\":\"x\",\"input\":{},\"risk\":42}" with None -> () | Some _ -> fail "typed metadata");
  check (Praxo.strip_tool_call_markup "x.y {}" = "x.y {}") "strip preserves plain";
  (match Praxo.parse_tool_call "echo {}" with None -> () | Some _ -> fail "plain dotted");
  check (Praxo.strip_tool_call_markup "a<tool_call name=\"x\">unfinished" = "a") "unfinished block";
  print_endline "test_toolcall passed"

let test_schema root =
  let document = Praxo.parse_json (read_file (Filename.concat root "vectors/jsonschema.json")) in
  let vectors = array_field "vectors" document in
  List.iter (fun vector ->
    let input = match field "input" vector with Some value -> value | None -> fail "input" in
    let expect = match field "expect" vector with Some value -> value | None -> fail "expect" in
    let schema = match field "schema" input with Some value -> value | None -> fail "schema" in
    let data = match field "data" input with Some value -> value | None -> fail "data" in
    let paths = Praxo.validate_schema schema data in
    let valid = bool_field "valid" expect in
    check ((paths = []) = valid) "schema validity";
    if not valid then
      let expected = array_field "errorPaths" expect in
      let expected = List.map (function Praxo.String value -> value | _ -> fail "path") expected in
      check (path_set paths = path_set expected) "schema paths") vectors;
  let schema = Praxo.parse_json "{\"type\":\"string\",\"pattern\":\"^a+$\"}" in
  let data = Praxo.parse_json "\"a\\n\"" in
  check (Praxo.validate_schema schema data = ["$"]) "pattern newline";
  (try ignore (Praxo.validate_schema (Praxo.parse_json "{\"pattern\":\"(a)\"}") (Praxo.parse_json "\"a\"")); fail "unsupported pattern accepted" with Praxo.Schema_error _ -> ());
  print_endline "test_schema passed"

let test_manifest root =
  let document = Praxo.parse_json (read_file (Filename.concat root "vectors/plugin.json")) in
  let vectors = array_field "vectors" document in
  List.iter (fun vector ->
    let input = match field "input" vector with Some value -> value | None -> fail "input" in
    let expect = match field "expect" vector with Some value -> value | None -> fail "expect" in
    let raw = match field "raw" input with
      | Some (Praxo.String value) -> value
      | _ -> Praxo.encode_json (match field "manifest" input with Some value -> value | None -> fail "manifest")
    in
    match Praxo.validate_manifest raw with
    | None -> check (not (bool_field "valid" expect)) "unexpected invalid manifest"
    | Some manifest ->
        check (bool_field "valid" expect) "unexpected valid manifest";
        (match field "id" expect with Some (Praxo.String id) -> check (string_field "id" manifest = id) "manifest id" | _ -> ());
        (match field "kind" expect with Some (Praxo.String kind) -> check (string_field "kind" manifest = kind) "manifest kind" | _ -> ())) vectors;
  check (Praxo.validate_manifest "{} {}" = None) "trailing manifest";
  check (Praxo.validate_manifest "" = None) "empty manifest";
  print_endline "test_manifest passed"

let bool_or name value fallback = match field name value with Some (Praxo.Bool flag) -> flag | _ -> fallback

let int_field name value =
  match field name value with Some (Praxo.Number number) -> int_of_float number | _ -> fail ("missing int " ^ name)

let string_list_field name value =
  List.map (function Praxo.String text -> text | _ -> fail ("missing string in " ^ name)) (array_field name value)

let group root name =
  let document = Praxo.parse_json (read_file (Filename.concat root ("vectors/" ^ name ^ ".json"))) in
  array_field "vectors" document

let check_code expected thunk =
  try ignore (thunk ()); check (expected = "") ("expected error " ^ expected)
  with Praxo.Core_error (code, _) -> check (code = expected) ("error code " ^ code)

let test_memory root =
  List.iter (fun vector ->
    let input = match field "input" vector with Some value -> value | None -> fail "input" in
    let expect = match field "expect" vector with Some value -> value | None -> fail "expect" in
    let store = Praxo.memory_store () in
    List.iter (fun put ->
      let session = string_field "session" put in
      let record = match field "record" put with Some value -> value | None -> fail "record" in
      ignore (Praxo.memory_put store session (Praxo.memory_record_make
        (string_field "id" record) (string_field "frame" record) (string_field "content" record)
        (match field "createdAt" record with Some (Praxo.String value) -> Some value | _ -> None)))) (array_field "puts" input);
    let records = Praxo.memory_search store (string_field "session" input) (string_field "query" input) (int_field "limit" input) in
    let ids = if records = [] then Praxo.Null else Praxo.Array (List.map (fun item -> Praxo.String item.Praxo.record_id) records) in
    let contents = if records = [] then Praxo.Null else Praxo.Array (List.map (fun item -> Praxo.String item.Praxo.record_content) records) in
    let expected_ids = match field "ids" expect with Some value -> value | None -> Praxo.Null in
    let expected_contents = match field "contents" expect with Some value -> value | None -> Praxo.Null in
    check (Praxo.json_equal ids expected_ids) "memory ids";
    check (Praxo.json_equal contents expected_contents) "memory contents") (group root "memory");
  print_endline "test_memory passed"

let test_event root =
  List.iter (fun vector ->
    let input = match field "input" vector with Some value -> value | None -> fail "input" in
    let expect = match field "expect" vector with Some value -> value | None -> fail "expect" in
    let events = List.map (fun kind -> Praxo.event_make kind "s1" None Praxo.Null) (string_list_field "events" input) in
    if string_field "sink" input = "multi" then begin
      let count = max 1 (int_field "sinkCount" input) in
      let sinks = List.init count (fun _ ->
        let types : string list ref = ref [] in
        ((fun event -> types := event.Praxo.event_type :: !types), types)) in
      let multi = Praxo.multi_sink (List.map fst sinks) in
      List.iter multi events;
      let per_sink = List.map (fun (_, types) -> Praxo.Array (List.map (fun item -> Praxo.String item) (List.rev !types))) sinks in
      let expected = match field "perSink" expect with Some value -> value | None -> Praxo.Null in
      check (Praxo.json_equal (Praxo.Array per_sink) expected) "perSink"
    end else begin
      let delivered : string list ref = ref [] in
      let sink event = delivered := event.Praxo.event_type :: !delivered in
      let predicate = match field "predicateTypes" input with Some _ -> string_list_field "predicateTypes" input | None -> [] in
      let filtered = Praxo.filter_sink sink predicate in
      List.iter filtered events;
      let output = if !delivered = [] then Praxo.Null else Praxo.Array (List.map (fun item -> Praxo.String item) (List.rev !delivered)) in
      let expected = match field "delivered" expect with Some value -> value | None -> Praxo.Null in
      check (Praxo.json_equal output expected) "delivered"
    end) (group root "event");
  print_endline "test_event passed"

let test_stream root =
  let kinds = Praxo.Array (List.map (fun kind -> Praxo.String kind)
    ["values"; "updates"; "messages"; "tasks"; "debug"; "checkpoint"]) in
  List.iter (fun vector ->
    let expect = match field "expect" vector with Some value -> value | None -> fail "expect" in
    check (Praxo.json_equal kinds (match field "kinds" expect with Some value -> value | None -> Praxo.Null)) "stream kinds") (group root "stream");
  print_endline "test_stream passed"

let test_checkpoint root =
  List.iter (fun vector ->
    let input = match field "input" vector with Some value -> value | None -> fail "input" in
    let expect = match field "expect" vector with Some value -> value | None -> fail "expect" in
    let allow = Praxo.checkpoint_allowlist () in
    let registered = match field "registered" input with Some (Praxo.Array values) -> values | _ -> [] in
    List.iter (function Praxo.String kind -> Praxo.checkpoint_register allow kind | _ -> fail "registered") registered;
    let operation = match field "operation" input with Some (Praxo.String value) -> value | _ -> "roundtrip" in
    let event_type = string_field "type" input in
    let value = match field "value" input with Some value -> value | None -> Praxo.Null in
    if operation = "roundtrip" then begin
      let data = Praxo.checkpoint_marshal allow event_type value in
      let decoded = Praxo.checkpoint_unmarshal allow data in
      let expected = match field "value" expect with Some value -> value | None -> Praxo.Null in
      check (Praxo.json_equal decoded expected) "checkpoint value"
    end else begin
      let expected = match field "errorCode" expect with Some (Praxo.String value) -> value | _ -> "" in
      check_code expected (fun () ->
        if operation = "marshal" then ignore (Praxo.checkpoint_marshal allow event_type value)
        else ignore (Praxo.checkpoint_unmarshal allow (Praxo.encode_json (Praxo.Object [("type", Praxo.String event_type); ("data", value)]))))
    end) (group root "checkpoint");
  print_endline "test_checkpoint passed"

let test_policy root =
  List.iter (fun vector ->
    let input = match field "input" vector with Some value -> value | None -> fail "input" in
    let expect = match field "expect" vector with Some value -> value | None -> fail "expect" in
    let grants = List.map (fun item -> Praxo.path_grant_make (string_field "root" item)
      (match field "access" item with Some (Praxo.String value) -> value | _ -> "read")) (array_field "grants" input) in
    let target = string_field "target" input and need = string_field "need" input in
    if bool_or "error" expect false then
      check_code "POLICY_ERROR" (fun () -> ignore (Praxo.path_check (Praxo.path_checker grants) target need))
    else
      let decision = Praxo.path_check (Praxo.path_checker grants) target need in
      check (decision.Praxo.decision_allowed = bool_field "allowed" expect) "policy allowed") (group root "policy");
  let checker = Praxo.path_checker [Praxo.path_grant_make "allowed" "read"] in
  List.iter (fun target ->
    check (not (Praxo.path_allowed checker target "read")) ("relative escape " ^ target))
    ["../allowed/secret"; "../../allowed/secret"; "x/../../allowed/secret";
     "..\\allowed\\secret"];
  check (Praxo.path_allowed checker "other/../allowed/secret" "read") "relative normalization";
  let parent_checker = Praxo.path_checker [Praxo.path_grant_make "../allowed" "read"] in
  check (Praxo.path_allowed parent_checker "../allowed/secret" "read") "relative parent grant";
  check (not (Praxo.path_allowed parent_checker "allowed/secret" "read")) "relative parent grant isolation";
  let absolute_checker = Praxo.path_checker [Praxo.path_grant_make "/allowed" "read"] in
  check (Praxo.path_allowed absolute_checker "/../../allowed/secret" "read") "absolute parent normalization";
  print_endline "test_policy passed"

let test_context root =
  List.iter (fun vector ->
    let input = match field "input" vector with Some value -> value | None -> fail "input" in
    let expect = match field "expect" vector with Some value -> value | None -> fail "expect" in
    let messages = List.map (fun item -> Praxo.text_message (string_field "role" item)
      (match field "content" item with Some (Praxo.String value) -> value | _ -> "")) (array_field "messages" input) in
    if string_field "operation" input = "estimate" then
      check (Praxo.estimate_tokens messages = int_field "tokens" expect) "context tokens"
    else begin
      let budget_value = match field "budget" input with Some value -> value | None -> Praxo.Object [] in
      let budget = Praxo.context_budget_make (int_field "maxTokens" budget_value) (int_field "keepRecent" budget_value) in
      let output, ok = Praxo.compact_context budget messages in
      check (ok = bool_field "ok" expect) "context ok";
      if ok then begin
        check (Praxo.estimate_tokens output = int_field "tokens" expect) "context tokens";
        let wire = Praxo.Array (List.map Praxo.message_wire output) in
        let expected = match field "messages" expect with Some value -> value | None -> Praxo.Null in
        check (Praxo.json_equal wire expected) "context messages"
      end
    end) (group root "context");
  print_endline "test_context passed"

let test_middleware root =
  List.iter (fun vector ->
    let input = match field "input" vector with Some value -> value | None -> fail "input" in
    let expect = match field "expect" vector with Some value -> value | None -> fail "expect" in
    match string_field "operation" input with
    | "pii" -> check (Praxo.pii_redact (string_field "text" input) = string_field "text" expect) "pii"
    | "pii-value" -> check (Praxo.json_equal (Praxo.redact_value (match field "value" input with Some value -> value | None -> Praxo.Null))
        (match field "value" expect with Some value -> value | None -> Praxo.Null)) "pii value"
    | "structured" ->
        let schema = match field "schema" input with Some value -> value | None -> Praxo.Object [] in
        let repair = match field "repairOutput" input with Some (Praxo.String value) -> Some (fun _ -> value) | _ -> None in
        let output, code = Praxo.structured_apply (Praxo.structured_output schema (int_field "maxRepairs" input) repair) (string_field "output" input) in
        if bool_field "ok" expect then
          check (output <> None && Option.get output = string_field "output" expect) "structured output"
        else check (code = string_field "errorCode" expect) "structured code"
    | "call-limit" ->
        let limit = Praxo.call_limit (int_field "modelLimit" input) (int_field "toolLimit" input) in
        let outcomes = List.map (fun kind ->
          try (if kind = "model" then Praxo.call_limit_model limit else Praxo.call_limit_tool limit); "ok"
          with Praxo.Core_error (code, _) -> code) (string_list_field "calls" input) in
        let expected = match field "outcomes" expect with Some value -> value | None -> Praxo.Null in
        check (Praxo.json_equal (Praxo.Array (List.map (fun item -> Praxo.String item) outcomes)) expected) "call limit"
    | "tool-selection" ->
        let selection = Praxo.tool_selection (string_list_field "selected" input) in
        let tools = List.map (fun name -> Praxo.tool_spec_make name "") (string_list_field "tools" input) in
        let advertised = List.map (fun item -> Praxo.String item.Praxo.spec_name) (Praxo.select_tools selection tools) in
        let expected = match field "advertised" expect with Some value -> value | None -> Praxo.Null in
        check (Praxo.json_equal (Praxo.Array advertised) expected) "advertised";
        let reject = try Praxo.check_tool_selected selection (string_field "requested" input); "ok" with Praxo.Core_error (code, _) -> code in
        check (reject = string_field "reject" expect) "tool selection reject"
    | "fallback" ->
        let content = string_field "fallbackContent" input in
        let model = Praxo.fallback_model (Praxo.failing_model ()) (Praxo.static_model content) in
        let response = model.Praxo.generate (Praxo.request_make [] []) in
        check (response.Praxo.response_message.Praxo.message_content = content) "fallback output"
    | _ -> fail "unknown middleware operation") (group root "middleware");
  print_endline "test_middleware passed"

let test_agent_loop root =
  List.iter (fun vector ->
    let input = match field "input" vector with Some value -> value | None -> fail "input" in
    let expect = match field "expect" vector with Some value -> value | None -> fail "expect" in
    let invocations = ref 0 in
    let tools = List.map (fun item -> Praxo.tool_make (string_field "name" item)
      (match field "description" item with Some (Praxo.String value) -> value | _ -> "")
      (fun arguments -> incr invocations; arguments)) (match field "tools" input with Some (Praxo.Array values) -> values | _ -> []) in
    let script = List.map (fun item ->
      let calls = List.map (fun call -> Praxo.tool_invocation_make (string_field "id" call)
        (string_field "name" call) (match field "arguments" call with Some value -> value | None -> Praxo.Object []))
        (match field "toolCalls" item with Some (Praxo.Array values) -> values | _ -> []) in
      Praxo.response_make (Praxo.assistant_message
        (match field "content" item with Some (Praxo.String value) -> value | _ -> "") calls)
        (Praxo.usage_make (match field "inputTokens" item with Some (Praxo.Number value) -> int_of_float value | _ -> 0)
                          (match field "outputTokens" item with Some (Praxo.Number value) -> int_of_float value | _ -> 0)))
      (array_field "script" input) in
    let event_types : string list ref = ref [] in
    let options = { (Praxo.agent_options (Praxo.scripted_model script)) with
      Praxo.agent_tools = tools;
      agent_events = Some (fun event -> event_types := event.Praxo.event_type :: !event_types);
      agent_max_steps = (match field "maxSteps" input with Some (Praxo.Number value) -> int_of_float value | _ -> 0);
      agent_max_tokens = (match field "maxTokens" input with Some (Praxo.Number value) -> int_of_float value | _ -> 0) } in
    let session_id = "s1" in
    let session = Praxo.session_make session_id [] in
    let prompt = match field "prompt" input with Some (Praxo.String value) -> value | _ -> "" in
    if bool_or "error" expect false then
      (try ignore (Praxo.run_agent options session prompt); fail "unexpected success"
       with Praxo.Core_error (code, _) ->
         (match field "errorCode" expect with Some (Praxo.String expected) -> check (code = expected) "agent error code" | _ -> ()))
    else begin
      let result = Praxo.run_agent options session prompt in
      check (result.Praxo.result_output = string_field "output" expect) "agent output";
      check (result.Praxo.result_steps = int_field "steps" expect) "agent steps"
    end;
    check (!invocations = int_field "toolInvocations" expect) "agent invocations";
    let events = if !event_types = [] then Praxo.Null else Praxo.Array (List.map (fun item -> Praxo.String item) (List.rev !event_types)) in
    let expected = match field "events" expect with Some value -> value | None -> Praxo.Null in
    check (Praxo.json_equal events expected) "agent events") (group root "agent-loop");
  print_endline "test_agent_loop passed"

let test_agent_failures () =
  Printexc.record_backtrace true;
  let run_case source fail_failure_sink =
    let original = Failure ("failure from " ^ source) in
    let origin = ref "" in
    let throw () =
      try raise original with error ->
        let trace = Printexc.get_raw_backtrace () in
        origin := Printexc.raw_backtrace_to_string trace;
        Printexc.raise_with_backtrace error trace
    in
    let events = ref [] in
    let failure_data = ref Praxo.Null in
    let model = if source = "model" then { Praxo.generate = (fun _ -> throw ()) }
      else if source = "tool" || source = "tool.call" then
        Praxo.scripted_model [Praxo.response_make
          (Praxo.assistant_message "" [Praxo.tool_invocation_make "1" "test" Praxo.Null])
          (Praxo.usage_make 0 0)]
      else Praxo.static_model "ok" in
    let options = { (Praxo.agent_options model) with
      Praxo.agent_tools = [Praxo.tool_make "test" "" (fun _ -> if source = "tool" then throw () else Praxo.Null)];
      agent_events = Some (fun event ->
        events := !events @ [event.Praxo.event_type];
        if event.Praxo.event_type = "run.failed" then begin
          failure_data := event.Praxo.event_data;
          if fail_failure_sink then failwith "failure sink"
        end;
        if event.Praxo.event_type = source then throw ()) } in
    (try ignore (Praxo.run_agent options (Praxo.session_make "s1" []) "hello");
         fail "agent failure expected"
     with error ->
       let trace = Printexc.raw_backtrace_to_string (Printexc.get_raw_backtrace ()) in
       check (error == original) (source ^ " original exception");
       check (!origin <> "" && List.hd (String.split_on_char '\n' !origin) =
         List.hd (String.split_on_char '\n' trace)) (source ^ " original backtrace"));
    check (List.length (List.filter ((=) "run.failed") !events) = 1) (source ^ " failure event count");
    check (!failure_data = Praxo.Object [("error", Praxo.String (Printexc.to_string original))])
      (source ^ " failure event data");
    check (List.hd (List.rev !events) = "run.failed") (source ^ " failure event order")
  in
  List.iter (fun source -> run_case source false; run_case source true)
    ["model"; "tool"; "run.started"; "tool.call"; "run.completed"];
  let original = Praxo.Core_error ("MODEL_ERROR", "model failed") in
  let failure_data = ref Praxo.Null in
  let model = { Praxo.generate = (fun _ -> raise original) } in
  let options = { (Praxo.agent_options model) with
    Praxo.agent_events = Some (fun event ->
      if event.Praxo.event_type = "run.failed" then begin
        failure_data := event.Praxo.event_data;
        failwith "failure sink"
      end) } in
  (try ignore (Praxo.run_agent options (Praxo.session_make "s1" []) "hello");
       fail "core error expected"
   with error -> check (error == original) "original core error");
  check (!failure_data = Praxo.Object [("error", Praxo.String "model failed")])
    "core error failure event data";
  print_endline "test_agent_failures passed"

let () =
  let root = if Array.length Sys.argv > 1 then Sys.argv.(1) else "../../spec" in
  test_json ();
  test_toolcall root;
  test_schema root;
  test_manifest root;
  test_memory root;
  test_event root;
  test_stream root;
  test_checkpoint root;
  test_policy root;
  test_context root;
  test_middleware root;
  test_agent_loop root;
  test_agent_failures ();
  print_endline "OCaml declared vector tests passed; Core review remains pending"
