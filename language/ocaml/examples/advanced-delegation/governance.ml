open Praxo_core

type gov_state = {
  effects : (string, int) Hashtbl.t;
  mutable budget : int;
  mutable children : int;
}

type run_config = {
  allowed : string list;
  policy : agent_action -> decision;
  tools : tool list;
  depth : int;
  max_depth : int;
  max_children : int;
  use_budget : bool;
  use_children : bool;
  cancelled : bool;
  edit_to_blocked : bool;
}

let default_config allowed policy tools = {
  allowed; policy; tools;
  depth = 0; max_depth = -1; max_children = -1;
  use_budget = false; use_children = false; cancelled = false;
  edit_to_blocked = false;
}

let make_state () = { effects = Hashtbl.create 8; budget = 0; children = 0 }

let object_field key value =
  match value with Object fields -> List.assoc_opt key fields | _ -> None

let string_field key value =
  match object_field key value with Some (String text) -> Some text | _ -> None

let target_of action =
  match string_field "target" action.action_arguments with
  | Some value -> value
  | None -> ""

let permissive_record action =
  if action.action_kind = "model.generate" then decision_make true ""
  else if action.action_kind = "tool.invoke" && action.action_tool_name = "record"
  then decision_make true ""
  else decision_make false "child may only record"

let parent_blocked action =
  if action.action_kind = "model.generate" then decision_make true ""
  else if action.action_kind <> "tool.invoke" || action.action_tool_name <> "record"
  then decision_make false "parent tool is not allowed"
  else if target_of action = "blocked" then decision_make false "blocked target"
  else decision_make true ""

let composed_policy action =
  let parent = parent_blocked action in
  if not parent.decision_allowed then parent else permissive_record action

let make_model steps =
  let remaining = ref steps in
  { generate = (fun _request ->
      match !remaining with
      | step :: rest -> remaining := rest; step
      | [] -> response_make (assistant_message "done" []) (usage_make 0 0));
    generate_stream = None; }

let model_for tool target =
  make_model [
    response_make (assistant_message "" [
      tool_invocation_make "call-1" tool (Object [("target", String target)]);
    ]) (usage_make 0 0);
    response_make (assistant_message "done" []) (usage_make 0 0);
  ]

let make_tools state =
  let make name =
    tool_make name name (fun arguments ->
      let target = match string_field "target" arguments with
        | Some value -> value
        | None -> "" in
      let count = try Hashtbl.find state.effects target with Not_found -> 0 in
      Hashtbl.replace state.effects target (count + 1);
      String "ok") in
  [make "record"; make "write"]

let denied_task status code = {
  task_id = "subagent";
  task_parent_session_id = "governance-parent";
  task_agent_id = "governance-child";
  task_mode = "isolated";
  task_status = status;
  task_output = "";
  task_error = code;
  task_created_at = "";
  task_updated_at = "";
}

let run_child state model config =
  if config.cancelled then denied_task "cancelled" "CANCELLED"
  else if config.max_depth >= 0 && config.depth > config.max_depth then
    denied_task "denied" "DEPTH_LIMIT"
  else if config.max_children >= 0 && state.children >= config.max_children then
    denied_task "denied" "CHILD_LIMIT"
  else if config.use_budget && state.budget <= 0 then
    denied_task "denied" "BUDGET_EXHAUSTED"
  else begin
    if config.use_children then state.children <- state.children + 1;
    let options = {
      (agent_options model) with
      agent_tools = config.tools;
      agent_allowed_tools = config.allowed;
      agent_action_policy = Some config.policy;
      agent_require_policy = true;
      agent_require_tool_scope = true;
      agent_max_steps = 3;
      agent_interrupt_on = if config.edit_to_blocked then ["record"] else [];
      agent_on_interrupt_decision = if config.edit_to_blocked then
        Some (fun _interrupt ->
          interrupt_decision_make ~arguments:(Object [("target", String "blocked")]) "edit")
      else None;
    } in
    let task = subagent_run (fun _request ->
      let result = run_agent options (session_make "governance-child" []) "run child" in
      { result_task_id = "child"; result_agent_id = "child";
        result_output = result.result_output }) {
      request_parent_session_id = "governance-parent";
      request_agent_id = "governance-child";
      request_prompt = "run child";
      request_mode = "isolated";
    } in
    if config.use_budget && task.task_status = "completed" then
      state.budget <- state.budget - 1;
    task
  end

let has_effect state name =
  try Hashtbl.find state.effects name with Not_found -> 0

let () =
  let scope_state = make_state () in
  let scope_result = run_child scope_state (model_for "write" "escape")
    (default_config ["record"] permissive_record (make_tools scope_state)) in
  assert (scope_result.task_status = "failed");
  assert (has_effect scope_state "escape" = 0);

  let policy_state = make_state () in
  let composed = run_child policy_state (model_for "record" "blocked")
    (default_config ["record"] composed_policy (make_tools policy_state)) in
  assert (composed.task_status = "failed");
  assert (has_effect policy_state "blocked" = 0);

  let budget_state = make_state () in
  budget_state.budget <- 1;
  let budget_config = {
    (default_config ["record"] permissive_record (make_tools budget_state)) with
    use_budget = true;
  } in
  let first = run_child budget_state (model_for "record" "sibling") budget_config in
  let second = run_child budget_state (model_for "record" "sibling") budget_config in
  assert (first.task_status = "completed");
  assert (second.task_status = "denied");
  assert (second.task_error = "BUDGET_EXHAUSTED");
  assert (has_effect budget_state "sibling" = 1);

  let limit_state = make_state () in
  let limit_config = {
    (default_config ["record"] permissive_record (make_tools limit_state)) with
    max_children = 1; use_children = true;
  } in
  let first_limit = run_child limit_state (model_for "record" "limit") limit_config in
  let second_limit = run_child limit_state (model_for "record" "limit") limit_config in
  let deep_config = { limit_config with depth = 2; max_depth = 1 } in
  let deep = run_child limit_state (model_for "record" "limit") deep_config in
  assert (first_limit.task_status = "completed");
  assert (second_limit.task_error = "CHILD_LIMIT");
  assert (deep.task_error = "DEPTH_LIMIT");
  assert (has_effect limit_state "limit" = 1);

  let cancel_state = make_state () in
  let cancel_config = {
    (default_config ["record"] permissive_record (make_tools cancel_state)) with
    cancelled = true;
  } in
  let cancelled = run_child cancel_state (model_for "record" "cancel") cancel_config in
  assert (cancelled.task_status = "cancelled");
  assert (has_effect cancel_state "cancel" = 0);

  let edit_state = make_state () in
  let edit_config = {
    (default_config ["record"] parent_blocked (make_tools edit_state)) with
    edit_to_blocked = true;
  } in
  let edited = run_child edit_state (model_for "record" "edit-me") edit_config in
  assert (edited.task_status = "failed");
  assert (has_effect edit_state "edit-me" = 0);
  assert (has_effect edit_state "blocked" = 0);

  print_endline "OCaml advanced delegation governance: 6/6 passed"
