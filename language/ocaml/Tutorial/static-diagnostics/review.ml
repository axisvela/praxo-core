#directory "../../src";;
#use "praxo_core_bundle.ml"

let tool_messages request =
  List.filter (fun message -> message.message_role = "tool") request.request_messages

let last = function
  | [] -> failwith "empty tool messages"
  | values -> List.nth values (List.length values - 1)

let parse_content message =
  try parse_json message.message_content with _ -> Null

type diagnostic = { file : string; line : int; rule : string; message : string }

let split_colon text =
  let rec walk index current acc =
    if index = String.length text then List.rev (current :: acc)
    else if text.[index] = ':' then walk (index + 1) "" (current :: acc)
    else walk (index + 1) (current ^ String.make 1 text.[index]) acc
  in
  walk 0 "" []

let parse_line text =
  match split_colon text with
  | [ file; line; rule; message ] ->
      (try Some { file; line = int_of_string line; rule; message }
       with _ -> None)
  | _ -> None

let parse_diagnostics text =
  let lines = String.split_on_char '\n' text |> List.filter (fun line -> String.trim line <> "") in
  let parsed = List.map (fun line -> (line, parse_line line)) lines in
  match List.find_opt (fun (_, value) -> value = None) parsed with
  | Some (line, _) -> Error line
  | None -> Ok (List.filter_map snd parsed)

let analyze diagnostics =
  let high = List.filter (fun item -> item.rule = "unsafe_shell") diagnostics in
  let low = List.filter (fun item -> item.rule <> "unsafe_shell") diagnostics in
  let locations =
    List.map (fun item -> item.file ^ ":" ^ string_of_int item.line) diagnostics
  in
  (high, low, locations)

let fixture_model scope source : model =
  { generate =
      (fun request ->
        match tool_messages request with
        | [] ->
            response_make
              (assistant_message ""
                 [ tool_invocation_make "read-1" "read_diagnostics"
                     (Object [ ("scope", String scope) ]) ])
              (usage_make 0 0)
        | first :: _ ->
            let evidence = parse_content first in
            (match field_string "error" evidence with
             | Some code -> response_make (assistant_message code []) (usage_make 0 0)
             | None ->
                 if List.length (tool_messages request) = 1 then
                   let action =
                     match field "high" evidence with
                     | Some (Number value) when value > 0.0 -> "review_high"
                     | _ -> "review_low"
                   in
                   response_make
                     (assistant_message ""
                        [ tool_invocation_make "draft-1" "draft_review"
                            (Object [ ("scope", String scope); ("action", String action) ]) ])
                     (usage_make 0 0)
                 else
                   let revision = parse_content (last (tool_messages request)) in
                   response_make
                     (assistant_message
                        (encode_json
                           (Object
                              [ ("stage", String "diagnostics_reviewed");
                                ("analysis", evidence);
                                ("review", revision);
                                ("fixes_applied", Number 0.0) ]))
                        [])
                     (usage_make 0 0)));
    generate_stream = None; }

let action_policy action =
  if action.action_kind = "model.generate" then decision_make true ""
  else if action.action_kind <> "tool.invoke" then decision_make false "unsupported action"
  else
    match field_string "scope" action.action_arguments with
    | Some "repo-100" -> (
        match action.action_tool_name with
        | "read_diagnostics" -> decision_make true ""
        | "draft_review" -> (
            match field_string "action" action.action_arguments with
            | Some "review_high" | Some "review_low" -> decision_make true ""
            | _ -> decision_make false "invalid review action")
        | _ -> decision_make false "unknown tool")
    | _ -> decision_make false "only repo-100 is in scope"

let default_input =
  "app.ml:12:unsafe_shell:uses Sys.command\n\
   app.ml:40:missing_test:no regression test\n\
   lib.ml:7:unsafe_shell:shell interpolation"

let clean_input = "util.ml:9:missing_doc:no documentation"

let run_case scope input simulate_failure =
  let reads = ref 0 in
  let drafts = ref 0 in
  let read_tool =
    tool_make "read_diagnostics" "Parse structured diagnostics and count rules; no source access."
      (fun arguments ->
        incr reads;
        if simulate_failure then Object [ ("error", String "DIAGNOSTICS_UNAVAILABLE") ]
        else
          match parse_diagnostics input with
          | Error line -> Object [ ("error", String ("DIAGNOSTICS_PARSE_ERROR:" ^ line)) ]
          | Ok diagnostics ->
              let high, low, locations = analyze diagnostics in
              Object
                [ ("total", Number (float_of_int (List.length diagnostics)));
                  ("high", Number (float_of_int (List.length high)));
                  ("low", Number (float_of_int (List.length low)));
                  ("locations", Array (List.map (fun value -> String value) locations));
                  ("source", String "diagnostics_fixture") ])
  in
  let draft_tool =
    tool_make "draft_review" "Draft a review-only finding set; never edits source."
      (fun arguments ->
        incr drafts;
        Object
          [ ("review_id", String "static-review-100");
            ("action", (match field_string "action" arguments with Some value -> String value | None -> String ""));
            ("status", String "draft_only");
            ("review_required", Bool true);
            ("fixes_applied", Number 0.0) ])
  in
  let options =
    { (agent_options (fixture_model scope input)) with
      agent_tools = [ read_tool; draft_tool ];
      agent_allowed_tools = [ "read_diagnostics"; "draft_review" ];
      agent_max_steps = 4;
      agent_action_policy = Some action_policy;
      agent_require_policy = true;
      agent_require_tool_scope = true; }
  in
  try
    let result =
      run_agent options (session_make "static-diagnostics" [])
        "Parse the structured diagnostics and draft review-only findings."
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
    (match run_case "repo-100" default_input false with
     | Some output, 1, 1, None ->
         let report = parse_json output in
         let analysis = match field "analysis" report with Some value -> value | None -> Null in
         let review = match field "review" report with Some value -> value | None -> Null in
         if field "total" analysis <> Some (Number 3.0)
            || field "high" analysis <> Some (Number 2.0)
            || field_string "action" review <> Some "review_high"
            || field "fixes_applied" report <> Some (Number 0.0)
         then failwith "unexpected diagnostics report"
         else print_endline "success: repo-100 total=3 high=2 action=review_high status=draft_only reads=1"
     | _ -> failwith "success verification failed");
    (match run_case "repo-100" clean_input false with
     | Some output, 1, 1, None ->
         let report = parse_json output in
         let review = match field "review" report with Some value -> value | None -> Null in
         if field_string "action" review <> Some "review_low" then failwith "clean branch failed"
         else print_endline "success: clean total=1 high=0 action=review_low reads=1"
     | _ -> failwith "clean verification failed");
    (match run_case "repo-200" default_input false with
     | None, 0, 0, Some "AGENT_POLICY_DENIED" -> print_endline "deny: AGENT_POLICY_DENIED reads=0"
     | _ -> failwith "deny verification failed");
    (match run_case "repo-100" default_input true with
     | Some "DIAGNOSTICS_UNAVAILABLE", 1, 0, None ->
         print_endline "failure: DIAGNOSTICS_UNAVAILABLE reads=1"
     | _ -> failwith "dependency failure verification failed");
    (match run_case "repo-100" "bad diagnostic line" false with
    | Some output, 1, 0, None
      when String.length output >= String.length "DIAGNOSTICS_PARSE_ERROR"
           && String.sub output 0 (String.length "DIAGNOSTICS_PARSE_ERROR")
              = "DIAGNOSTICS_PARSE_ERROR" ->
        print_endline "failure: DIAGNOSTICS_PARSE_ERROR reads=1"
    | _ -> failwith "parse failure verification failed");
    print_endline "OCaml static-diagnostics tutorial: all checks passed"
  in
  if List.mem "--test" args then run_tests ()
  else
    let scope = value_after "--scope" "repo-100" in
    let input = if List.mem "--invalid" args then "bad diagnostic line" else default_input in
    let simulate_failure = List.mem "--simulate-failure" args in
    match run_case scope input simulate_failure with
    | Some output, _, _, None when output = "DIAGNOSTICS_UNAVAILABLE"
                               || output = "DIAGNOSTICS_PARSE_ERROR:bad diagnostic line" ->
        print_endline output;
        exit 1
    | Some output, _, _, None -> print_endline output
    | _, _, _, Some code ->
        Printf.eprintf "static diagnostics failed: %s\n" code;
        exit 1
    | _ -> failwith "unexpected outcome"






