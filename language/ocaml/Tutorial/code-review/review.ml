#use "../../praxo_core.ml"

let tool_messages request =
  List.filter (fun message -> message.message_role = "tool") request.request_messages

let last = function
  | [] -> failwith "empty tool messages"
  | values -> List.nth values (List.length values - 1)

let parse_content message =
  try parse_json message.message_content with _ -> Null

let fixture_model repo : model =
  { generate =
      (fun request ->
        let tools = tool_messages request in
        match tools with
        | [] ->
            response_make
              (assistant_message ""
                 [ tool_invocation_make "change-1" "read_change"
                     (Object [ ("repo", String repo) ]) ])
              (usage_make 0 0)
        | first :: _ ->
            let change = parse_content first in
            (match field_string "error" change with
             | Some code ->
                 response_make (assistant_message code []) (usage_make 0 0)
             | None ->
                 if List.length tools = 1 then
                   response_make
                     (assistant_message ""
                        [ tool_invocation_make "review-1" "draft_review"
                            (Object
                               [ ("repo", String repo);
                                 ("action", String "request_changes") ]) ])
                     (usage_make 0 0)
                 else
                   let review = parse_content (last tools) in
                   let report =
                     Object
                       [ ("stage", String "review_drafted");
                         ("change", change);
                         ("review", review);
                         ("comments_written", Number 0.0) ]
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
    let repo =
      match field_string "repo" action.action_arguments with
      | Some value -> value
      | None -> ""
    in
    if repo <> "repo-100" then
      decision_make false "only repo-100 is in review scope"
    else if action.action_tool_name = "read_change" then decision_make true ""
    else if action.action_tool_name = "draft_review" then
      match field_string "action" action.action_arguments with
      | Some "request_changes" -> decision_make true ""
      | _ -> decision_make false "only a request_changes draft is allowed"
    else decision_make false "unknown tool"

let run_case repo simulate_failure =
  let reads = ref 0 in
  let drafts = ref 0 in
  let read_change =
    tool_make "read_change" "Read a fixed diff and dependency manifest; no writes."
      (fun _arguments ->
        incr reads;
        if simulate_failure then
          Object [ ("error", String "CHANGE_SOURCE_UNAVAILABLE") ]
        else
          Object
            [ ("repo", String "repo-100");
              ("files", Array [ String "src/shell.sh"; String "src/app.py" ]);
              ("findings",
               Array
                 [ Object
                     [ ("id", String "f-1");
                       ("severity", String "high");
                       ("rule", String "unsafe_shell") ];
                   Object
                     [ ("id", String "f-2");
                       ("severity", String "low");
                       ("rule", String "test_missing") ] ]);
              ("license", String "mit-ok");
              ("source", String "change_fixture") ])
  in
  let draft_review =
    tool_make "draft_review" "Draft a review-only comment set; never writes."
      (fun arguments ->
        incr drafts;
        Object
          [ ("review_id", String "review-100");
            ("repo", (match field_string "repo" arguments with Some value -> String value | None -> String ""));
            ("action", (match field_string "action" arguments with Some value -> String value | None -> String ""));
            ("status", String "draft_only");
            ("review_required", Bool true);
            ("comments_written", Number 0.0) ])
  in
  let options =
    { (agent_options (fixture_model repo)) with
      agent_tools = [ read_change; draft_review ];
      agent_allowed_tools = [ "read_change"; "draft_review" ];
      agent_max_steps = 4;
      agent_action_policy = Some action_policy;
      agent_require_policy = true;
      agent_require_tool_scope = true; }
  in
  try
    let result =
      run_agent options (session_make "code-review" [])
        "Review the fixed change and draft review-only comments."
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
    let success = run_case "repo-100" false in
    (match success with
     | Some output, 1, 1, None ->
         let report = parse_json output in
         let change = match field "change" report with Some value -> value | None -> Null in
         let review = match field "review" report with Some value -> value | None -> Null in
         let findings =
           match field "findings" change with Some (Array values) -> values | _ -> []
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
           field_string "stage" report <> Some "review_drafted"
           || not high
           || field_string "status" review <> Some "draft_only"
           || field "comments_written" report <> Some (Number 0.0)
         then failwith "unexpected report"
         else
           print_endline
             "success: repo-100 high=unsafe_shell status=draft_only comments_written=0 reads=1"
     | _ -> failwith "success verification failed");

    (match run_case "repo-200" false with
     | None, 0, 0, Some "AGENT_POLICY_DENIED" ->
         print_endline "deny: AGENT_POLICY_DENIED reads=0"
     | _ -> failwith "deny verification failed");

    match run_case "repo-100" true with
    | Some "CHANGE_SOURCE_UNAVAILABLE", 1, 0, None ->
        print_endline "failure: CHANGE_SOURCE_UNAVAILABLE reads=1"
    | _ -> failwith "failure verification failed"
  in

  if List.mem "--test" args then run_tests ()
  else
    let repo = value_after "--repo" "repo-100" in
    let simulate_failure = List.mem "--simulate-failure" args in
    match run_case repo simulate_failure with
    | Some output, _, _, None when output = "CHANGE_SOURCE_UNAVAILABLE" ->
        print_endline output;
        exit 1
    | Some output, _, _, None -> print_endline output
    | _, _, _, Some code ->
        Printf.eprintf "code review failed: %s\n" code;
        exit 1
    | _ -> failwith "unexpected outcome"
