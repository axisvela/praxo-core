open Praxo_core

let effects = Hashtbl.create 8
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

let parent_policy action =
  if action.action_kind = "model.generate" then decision_make true ""
  else if action.action_kind = "tool.invoke" && action.action_tool_name = "delegate"
  then decision_make true ""
  else decision_make false "parent may only delegate"

let child_policy action =
  if action.action_kind = "model.generate" then decision_make true ""
  else if action.action_kind = "tool.invoke" && action.action_tool_name = "record"
  then decision_make true ""
  else decision_make false "child may only record"

let () =
  let record = tool_make "record" "Record a target in an in-memory counter"
    (fun arguments ->
      let target = match arguments with
        | Object fields -> (match List.assoc_opt "target" fields with
            | Some (String value) -> value | _ -> "")
        | _ -> "" in
      let count = try Hashtbl.find effects target with Not_found -> 0 in
      Hashtbl.replace effects target (count + 1);
      String ("recorded:" ^ target)) in
  let child_model = make_model
    [tool_response (record_call "child-record" "child")] "child done"
    (Some (fun () -> incr child_calls)) in
  let delegate = tool_make "delegate"
    "Run a child agent with a narrowed record scope"
    (fun _arguments ->
      let options = {
        (agent_options child_model) with
        agent_tools = [record];
        agent_allowed_tools = ["record"];
        agent_action_policy = Some child_policy;
        agent_require_policy = true;
        agent_require_tool_scope = true;
        agent_max_steps = 3;
      } in
      let result = run_agent options (session_make "demo-child" []) "record child" in
      String result.result_output) in
  let parent_model = make_model [
    tool_response (tool_invocation_make "parent-delegate" "delegate"
      (Object [("task", String "record child")]));
  ] "parent done" None in
  let options = {
    (agent_options parent_model) with
    agent_tools = [record; delegate];
    agent_allowed_tools = ["delegate"];
    agent_action_policy = Some parent_policy;
    agent_require_policy = true;
    agent_require_tool_scope = true;
  } in
  let result = run_agent options (session_make "demo-parent" []) "delegate" in
  print_endline "delegation: child recorded; parent scope enforced";

  let direct_model = make_model [
    tool_response (record_call "direct-record" "child");
  ] "parent done" None in
  let direct_options = {
    (agent_options direct_model) with
    agent_tools = [record; delegate];
    agent_allowed_tools = ["delegate"];
    agent_action_policy = Some parent_policy;
    agent_require_policy = true;
    agent_require_tool_scope = true;
  } in
  let denied =
    try
      ignore (run_agent direct_options (session_make "demo-direct" [])
        "record directly");
      false
    with Core_error _ -> true in
  print_endline "deny: parent record blocked; child effect unchanged";
  assert (result.result_output = "parent done");
  assert ((try Hashtbl.find effects "child" with Not_found -> 0) = 1);
  assert denied
