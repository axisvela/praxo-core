let check condition message = if not condition then failwith message

let () =
  let reads = ref 0 in
  let read_document = Praxo_core.tool_make "read_document" "Read a public document"
    (fun _ -> incr reads; Praxo_core.String "Public support instructions") in
  let authorize action =
    let allowed =
      action.Praxo_core.action_kind = "model.generate" ||
      (action.action_kind = "tool.invoke" &&
       action.action_tool_name = "read_document" &&
       action.action_arguments = Praxo_core.Object ["document_id", Praxo_core.String "public"])
    in
    Praxo_core.decision_make allowed "Only the public document may be read"
  in
  let run document_id =
    let call = Praxo_core.tool_invocation_make "read-1" "read_document"
      (Praxo_core.Object ["document_id", Praxo_core.String document_id]) in
    let respond message = Praxo_core.response_make message (Praxo_core.usage_make 0 0) in
    let model = Praxo_core.scripted_model [
      respond (Praxo_core.assistant_message "" [call]);
      respond (Praxo_core.assistant_message "Review-only support draft" []);
    ] in
    let options = { (Praxo_core.agent_options model) with
      Praxo_core.agent_tools = [read_document];
      agent_allowed_tools = ["read_document"];
      agent_action_policy = Some authorize;
      agent_require_policy = true;
      agent_require_tool_scope = true;
      agent_max_steps = 3;
    } in
    Praxo_core.run_agent options (Praxo_core.session_make "consumer" [])
      "Prepare a review-only support draft"
  in
  let allowed = run "public" in
  check (allowed.Praxo_core.result_output = "Review-only support draft") "allow output";
  check (!reads = 1) "allow must read exactly once";
  let denied =
    try ignore (run "private"); false
    with Praxo_core.Core_error ("AGENT_POLICY_DENIED", _) -> true
  in
  check denied "private document must be denied";
  check (!reads = 1) "denied request must not read";
  Printf.printf "Installed OCaml package %s: governed allow/deny consumer passed\n"
    Praxo_core.sdk_version
