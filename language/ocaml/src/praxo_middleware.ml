open Praxo_types
open Praxo_message
let call_limit model_limit tool_limit = {
  model_limit;
  tool_limit;
  models_called = 0;
  tools_called = 0;
}

let call_limit_model limit =
  limit.models_called <- limit.models_called + 1;
  if limit.model_limit > 0 && limit.models_called > limit.model_limit then
    raise_core "AGENT_MODEL_CALL_LIMIT" "model call limit"

let call_limit_tool limit =
  limit.tools_called <- limit.tools_called + 1;
  if limit.tool_limit > 0 && limit.tools_called > limit.tool_limit then
    raise_core "AGENT_TOOL_CALL_LIMIT" "tool call limit"

let tool_selection selected = selected
let select_tools selection tools = List.filter (fun tool -> List.mem tool.spec_name selection) tools

let check_tool_selected selection name =
  if not (List.mem name selection) then raise_core "AGENT_TOOL_NOT_SELECTED" "tool not selected"

let scripted_model responses =
  let index = ref 0 in
  {
    generate = (fun _ ->
      if !index >= List.length responses then raise_core "MODEL_ERROR" "script exhausted";
      let response = List.nth responses !index in
      incr index;
      response);
    generate_stream = None;
  }

let static_model content = {
  generate = (fun _ -> response_make (assistant_message content []) (usage_make 0 0));
  generate_stream = None;
}

let failing_model () = {
  generate = (fun _ -> raise_core "MODEL_ERROR" "primary model failed");
  generate_stream = None;
}

let fallback_model primary fallback = {
  generate = (fun request -> try primary.generate request with _ -> fallback.generate request);
  generate_stream = None;
}

let interrupt_approve = "approve"
let interrupt_edit = "edit"
let interrupt_reject = "reject"
let interrupt_respond = "respond"

let agent_action_make kind session_id tool_name arguments = {
  action_kind = kind;
  action_session_id = session_id;
  action_tool_name = tool_name;
  action_arguments = arguments;
}

let interrupt_make run_id session_id call = {
  interrupt_run_id = run_id;
  interrupt_session_id = session_id;
  interrupt_call = call;
}

let interrupt_decision_make ?arguments ?(response = "") ?(reason = "") action = {
  interrupt_action = action;
  interrupt_arguments = arguments;
  interrupt_response = response;
  interrupt_reason = reason;
}

