#use "../../src/praxo_core.ml"

let tool_messages request =
  List.filter (fun message -> message.message_role = "tool") request.request_messages

let last = function
  | [] -> failwith "empty tool messages"
  | values -> List.nth values (List.length values - 1)

let parse_content message =
  try parse_json message.message_content with _ -> Null

let fixture_model contract : model =
  { generate =
      (fun request ->
        let tools = tool_messages request in
        match tools with
        | [] ->
            response_make
              (assistant_message ""
                 [ tool_invocation_make "clauses-1" "read_clauses"
                     (Object [ ("contract", String contract) ]) ])
              (usage_make 0 0)
        | first :: _ ->
            let clauses = parse_content first in
            (match field_string "error" clauses with
             | Some code ->
                 response_make (assistant_message code []) (usage_make 0 0)
             | None ->
                 if List.length tools = 1 then
                   response_make
                     (assistant_message ""
                        [ tool_invocation_make "revision-1" "draft_revision"
                            (Object
                               [ ("contract", String contract);
                                 ("action", String "propose_redline") ]) ])
                     (usage_make 0 0)
                 else
                   let revision = parse_content (last tools) in
                   let report =
                     Object
                       [ ("stage", String "redline_drafted");
                         ("clauses", clauses);
                         ("revision", revision);
                         ("edits_applied", Number 0.0) ]
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
    let contract =
      match field_string "contract" action.action_arguments with
      | Some value -> value
      | None -> ""
    in
    if contract <> "contract-100" then
      decision_make false "only contract-100 is in review scope"
    else if action.action_tool_name = "read_clauses" then decision_make true ""
    else if action.action_tool_name = "draft_revision" then
      match field_string "action" action.action_arguments with
      | Some "propose_redline" -> decision_make true ""
      | _ -> decision_make false "only a propose_redline draft is allowed"
    else decision_make false "unknown tool"

let run_case contract simulate_failure =
  let reads = ref 0 in
  let drafts = ref 0 in
  let read_clauses =
    tool_make "read_clauses" "Compare fixed clauses against a redline set; no writes."
      (fun _arguments ->
        incr reads;
        if simulate_failure then
          Object [ ("error", String "CLAUSE_SOURCE_UNAVAILABLE") ]
        else
          Object
            [ ("contract", String "contract-100");
              ("clauses",
               Array
                 [ Object [ ("id", String "c-1"); ("term", String "liability cap missing") ];
                   Object [ ("id", String "c-2"); ("term", String "payment 90 days") ];
                   Object [ ("id", String "c-3"); ("term", String "termination for convenience") ] ]);
              ("findings",
               Array
                 [ Object
                     [ ("id", String "f-1");
                       ("rule", String "liability_cap_missing");
                       ("severity", String "high") ];
                   Object
                     [ ("id", String "f-2");
                       ("rule", String "payment_terms_extended");
                       ("severity", String "medium") ] ]);
              ("source", String "clause_fixture") ])
  in
  let draft_revision =
    tool_make "draft_revision" "Draft review-only redlines; never edits a contract."
      (fun arguments ->
        incr drafts;
        Object
          [ ("revision_id", String "redline-100");
            ("contract", (match field_string "contract" arguments with Some value -> String value | None -> String ""));
            ("action", (match field_string "action" arguments with Some value -> String value | None -> String ""));
            ("status", String "draft_only");
            ("review_required", Bool true);
            ("edits_applied", Number 0.0) ])
  in
  let options =
    { (agent_options (fixture_model contract)) with
      agent_tools = [ read_clauses; draft_revision ];
      agent_allowed_tools = [ "read_clauses"; "draft_revision" ];
      agent_max_steps = 4;
      agent_action_policy = Some action_policy;
      agent_require_policy = true;
      agent_require_tool_scope = true; }
  in
  try
    let result =
      run_agent options (session_make "contract-review" [])
        "Compare fixed clauses against the redline set and draft review-only redlines."
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
    let success = run_case "contract-100" false in
    (match success with
     | Some output, 1, 1, None ->
         let report = parse_json output in
         let clauses = match field "clauses" report with Some value -> value | None -> Null in
         let revision = match field "revision" report with Some value -> value | None -> Null in
         let findings =
           match field "findings" clauses with Some (Array values) -> values | _ -> []
         in
         let high =
           List.exists
             (fun finding ->
               match field_string "severity" finding with
               | Some "high" -> true
               | _ -> false)
             findings
         in
         if
           field_string "stage" report <> Some "redline_drafted"
           || List.length findings <> 2
           || not high
           || field_string "status" revision <> Some "draft_only"
           || field "edits_applied" report <> Some (Number 0.0)
         then failwith "unexpected report"
         else
           print_endline
             "success: contract-100 findings=2 high=liability_cap_missing status=draft_only edits=0 reads=1"
     | _ -> failwith "success verification failed");

    (match run_case "contract-200" false with
     | None, 0, 0, Some "AGENT_POLICY_DENIED" ->
         print_endline "deny: AGENT_POLICY_DENIED reads=0"
     | _ -> failwith "deny verification failed");

    match run_case "contract-100" true with
    | Some "CLAUSE_SOURCE_UNAVAILABLE", 1, 0, None ->
        print_endline "failure: CLAUSE_SOURCE_UNAVAILABLE reads=1"
    | _ -> failwith "failure verification failed"
  in

  if List.mem "--test" args then run_tests ()
  else
    let contract = value_after "--contract" "contract-100" in
    let simulate_failure = List.mem "--simulate-failure" args in
    match run_case contract simulate_failure with
    | Some output, _, _, None when output = "CLAUSE_SOURCE_UNAVAILABLE" ->
        print_endline output;
        exit 1
    | Some output, _, _, None -> print_endline output
    | _, _, _, Some code ->
        Printf.eprintf "contract review failed: %s\n" code;
        exit 1
    | _ -> failwith "unexpected outcome"
