#use "../../src/praxo_core.ml"

let tool_messages request =
  List.filter (fun message -> message.message_role = "tool") request.request_messages

let last = function
  | [] -> failwith "empty tool messages"
  | values -> List.nth values (List.length values - 1)

let parse_content message =
  try parse_json message.message_content with _ -> Null

let fixture_model drawing : model =
  { generate =
      (fun request ->
        let tools = tool_messages request in
        match tools with
        | [] ->
            response_make
              (assistant_message ""
                 [ tool_invocation_make "drawing-1" "read_drawing"
                     (Object [ ("drawing", String drawing) ]) ])
              (usage_make 0 0)
        | first :: _ ->
            let evidence = parse_content first in
            (match field_string "error" evidence with
             | Some code ->
                 response_make (assistant_message code []) (usage_make 0 0)
             | None ->
                 if List.length tools = 1 then
                   response_make
                     (assistant_message ""
                        [ tool_invocation_make "bom-1" "draft_bom"
                            (Object
                               [ ("drawing", String drawing);
                                 ("action", String "publish_bom") ]) ])
                     (usage_make 0 0)
                 else
                   let bom = parse_content (last tools) in
                   let report =
                     Object
                       [ ("stage", String "bom_drafted");
                         ("drawing", evidence);
                         ("bom", bom);
                         ("revisions_applied", Number 0.0) ]
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
    let drawing =
      match field_string "drawing" action.action_arguments with
      | Some value -> value
      | None -> ""
    in
    if drawing <> "drawing-100" then
      decision_make false "only drawing-100 is in review scope"
    else if action.action_tool_name = "read_drawing" then decision_make true ""
    else if action.action_tool_name = "draft_bom" then
      match field_string "action" action.action_arguments with
      | Some "publish_bom" -> decision_make true ""
      | _ -> decision_make false "only a publish_bom draft is allowed"
    else decision_make false "unknown tool"

let run_case drawing simulate_failure =
  let reads = ref 0 in
  let drafts = ref 0 in
  let read_drawing =
    tool_make "read_drawing" "Read a fixed parsed drawing and check conflicts; no CAD access."
      (fun _arguments ->
        incr reads;
        if simulate_failure then
          Object [ ("error", String "DRAWING_SOURCE_UNAVAILABLE") ]
        else
          Object
            [ ("drawing", String "drawing-100");
              ("components",
               Array
                 [ Object [ ("part", String "bracket"); ("qty", Number 2.0) ];
                   Object [ ("part", String "bolt"); ("qty", Number 8.0) ];
                   Object [ ("part", String "gasket"); ("qty", Number 1.0) ] ]);
              ("conflicts", Array [ Object [ ("rule", String "clearance_conflict") ] ]);
              ("cost_estimate", Number 420.0);
              ("source", String "drawing_fixture") ])
  in
  let draft_bom =
    tool_make "draft_bom" "Draft a review-only BOM; never publishes or manufactures."
      (fun arguments ->
        incr drafts;
        Object
          [ ("bom_id", String "bom-100");
            ("drawing", (match field_string "drawing" arguments with Some value -> String value | None -> String ""));
            ("action", (match field_string "action" arguments with Some value -> String value | None -> String ""));
            ("status", String "draft_only");
            ("review_required", Bool true);
            ("revisions_applied", Number 0.0) ])
  in
  let options =
    { (agent_options (fixture_model drawing)) with
      agent_tools = [ read_drawing; draft_bom ];
      agent_allowed_tools = [ "read_drawing"; "draft_bom" ];
      agent_max_steps = 4;
      agent_action_policy = Some action_policy;
      agent_require_policy = true;
      agent_require_tool_scope = true; }
  in
  try
    let result =
      run_agent options (session_make "bom-review" [])
        "Read the fixed drawing and draft a review-only BOM."
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
    let success = run_case "drawing-100" false in
    (match success with
     | Some output, 1, 1, None ->
         let report = parse_json output in
         let drawing = match field "drawing" report with Some value -> value | None -> Null in
         let bom = match field "bom" report with Some value -> value | None -> Null in
         let components =
           match field "components" drawing with Some (Array values) -> values | _ -> []
         in
         let conflicts =
           match field "conflicts" drawing with Some (Array values) -> values | _ -> []
         in
         if
           field_string "stage" report <> Some "bom_drafted"
           || List.length components <> 3
           || List.length conflicts <> 1
           || field_string "status" bom <> Some "draft_only"
           || field "revisions_applied" report <> Some (Number 0.0)
         then failwith "unexpected report"
         else
           print_endline
             "success: drawing-100 components=3 conflicts=1 status=draft_only revisions=0 reads=1"
     | _ -> failwith "success verification failed");

    (match run_case "drawing-200" false with
     | None, 0, 0, Some "AGENT_POLICY_DENIED" ->
         print_endline "deny: AGENT_POLICY_DENIED reads=0"
     | _ -> failwith "deny verification failed");

    match run_case "drawing-100" true with
    | Some "DRAWING_SOURCE_UNAVAILABLE", 1, 0, None ->
        print_endline "failure: DRAWING_SOURCE_UNAVAILABLE reads=1"
    | _ -> failwith "failure verification failed"
  in

  if List.mem "--test" args then run_tests ()
  else
    let drawing = value_after "--drawing" "drawing-100" in
    let simulate_failure = List.mem "--simulate-failure" args in
    match run_case drawing simulate_failure with
    | Some output, _, _, None when output = "DRAWING_SOURCE_UNAVAILABLE" ->
        print_endline output;
        exit 1
    | Some output, _, _, None -> print_endline output
    | _, _, _, Some code ->
        Printf.eprintf "bom review failed: %s\n" code;
        exit 1
    | _ -> failwith "unexpected outcome"
