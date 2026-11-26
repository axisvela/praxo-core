#directory "../../src";;
#use "praxo_core_bundle.ml"

let tool_messages request =
  List.filter (fun message -> message.message_role = "tool") request.request_messages

let last = function
  | [] -> failwith "empty tool messages"
  | values -> List.nth values (List.length values - 1)

let parse_content message =
  try parse_json message.message_content with _ -> Null

let fixture_model graph : model =
  { generate =
      (fun request ->
        let tools = tool_messages request in
        match tools with
        | [] ->
            response_make
              (assistant_message ""
                 [ tool_invocation_make "graph-1" "read_graph"
                     (Object [ ("graph", String graph) ]) ])
              (usage_make 0 0)
        | first :: _ ->
            let snapshot = parse_content first in
            (match field_string "error" snapshot with
             | Some code ->
                 response_make (assistant_message code []) (usage_make 0 0)
             | None ->
                 if List.length tools = 1 then
                   response_make
                     (assistant_message ""
                        [ tool_invocation_make "findings-1" "draft_findings"
                            (Object
                               [ ("graph", String graph);
                                 ("action", String "draft_change_findings") ]) ])
                     (usage_make 0 0)
                 else
                   let findings = parse_content (last tools) in
                   let report =
                     Object
                       [ ("stage", String "change_findings_drafted");
                         ("graph", snapshot);
                         ("findings", findings);
                         ("blocks", Number 0.0) ]
                   in
                   response_make
                     (assistant_message (encode_json report) [])
                     (usage_make 0 0)));
    generate_stream = None; }

let action_policy action =
  if action.action_kind = "model.generate" then decision_make true ""
  else if action.action_kind <> "tool.invoke" then
    decision_make false "unsupported action"
  else
    let graph =
      match field_string "graph" action.action_arguments with
      | Some value -> value
      | None -> ""
    in
    if graph <> "graph-100" then
      decision_make false "only graph-100 is in governance scope"
    else if action.action_tool_name = "read_graph" then decision_make true ""
    else if action.action_tool_name = "draft_findings" then
      match field_string "action" action.action_arguments with
      | Some "draft_change_findings" -> decision_make true ""
      | _ -> decision_make false "only a draft_change_findings draft is allowed"
    else decision_make false "unknown tool"

let run_case graph simulate_failure =
  let reads = ref 0 in
  let drafts = ref 0 in
  let read_graph =
    tool_make "read_graph" "Compare a fixed application/API graph with stated standards; no scanning."
      (fun _arguments ->
        incr reads;
        if simulate_failure then
          Object [ ("error", String "GRAPH_UNAVAILABLE") ]
        else
          Object
            [ ("graph", String "graph-100");
              ("nodes", Number 4.0);
              ("edges", Number 5.0);
              ("violations",
               Array
                 [ Object
                     [ ("id", String "v-1");
                       ("rule", String "unapproved_api");
                       ("severity", String "high") ];
                   Object
                     [ ("id", String "v-2");
                       ("rule", String "orphan_service");
                       ("severity", String "medium") ] ]);
              ("source", String "graph_fixture") ])
  in
  let draft_findings =
    tool_make "draft_findings" "Draft review-only change findings; never blocks a system."
      (fun arguments ->
        incr drafts;
        Object
          [ ("findings_id", String "findings-100");
            ("graph", (match field_string "graph" arguments with Some value -> String value | None -> String ""));
            ("action", (match field_string "action" arguments with Some value -> String value | None -> String ""));
            ("findings", Number 2.0);
            ("status", String "draft_only");
            ("review_required", Bool true);
            ("blocks", Number 0.0) ])
  in
  let options =
    { (agent_options (fixture_model graph)) with
      agent_tools = [ read_graph; draft_findings ];
      agent_allowed_tools = [ "read_graph"; "draft_findings" ];
      agent_max_steps = 4;
      agent_action_policy = Some action_policy;
      agent_require_policy = true;
      agent_require_tool_scope = true; }
  in
  try
    let result =
      run_agent options (session_make "architecture-graph" [])
        "Compare the fixed graph with standards and draft review-only change findings."
    in
    (Some result.result_output, !reads, !drafts, None)
  with Core_error (code, _) -> (None, !reads, !drafts, Some code)

let () =
  let args = Array.to_list Sys.argv in
  let value_after flag default =
    let rec find = function
      | [] -> default
      | current :: next :: _ when current = flag -> next
      | _ :: rest -> find rest
    in
    find args
  in

  let run_tests () =
    let success = run_case "graph-100" false in
    (match success with
     | Some output, 1, 1, None ->
         let report = parse_json output in
         let snapshot = match field "graph" report with Some value -> value | None -> Null in
         let findings = match field "findings" report with Some value -> value | None -> Null in
         let violations =
           match field "violations" snapshot with Some (Array values) -> values | _ -> []
         in
         let high =
           List.exists
             (fun violation ->
               match field_string "severity" violation with
               | Some "high" -> true
               | _ -> false)
             violations
         in
         if
           field_string "stage" report <> Some "change_findings_drafted"
           || List.length violations <> 2
           || not high
           || field_string "status" findings <> Some "draft_only"
           || field "blocks" report <> Some (Number 0.0)
         then failwith "unexpected report"
         else
           print_endline
             "success: graph-100 violations=2 high=unapproved_api status=draft_only blocks=0 reads=1"
     | _ -> failwith "success verification failed");

    (match run_case "graph-200" false with
     | None, 0, 0, Some "AGENT_POLICY_DENIED" ->
         print_endline "deny: AGENT_POLICY_DENIED reads=0"
     | _ -> failwith "deny verification failed");

    match run_case "graph-100" true with
    | Some "GRAPH_UNAVAILABLE", 1, 0, None ->
        print_endline "failure: GRAPH_UNAVAILABLE reads=1"
    | _ -> failwith "failure verification failed"
  in

  if List.mem "--test" args then run_tests ()
  else
    let graph = value_after "--graph" "graph-100" in
    let simulate_failure = List.mem "--simulate-failure" args in
    match run_case graph simulate_failure with
    | Some output, _, _, None when output = "GRAPH_UNAVAILABLE" ->
        print_endline output;
        exit 1
    | Some output, _, _, None -> print_endline output
    | _, _, _, Some code ->
        Printf.eprintf "architecture graph failed: %s\n" code;
        exit 1
    | _ -> failwith "unexpected outcome"
