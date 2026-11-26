open Praxo_types
open Praxo_json
open Praxo_message
open Praxo_runtime
open Praxo_middleware
let agent_options model = {
  agent_model = model;
  agent_tools = [];
  agent_tool_selection = None;
  agent_pii = false;
  agent_structured_output = None;
  agent_call_limit = None;
  agent_events = None;
  agent_system_prompt = "";
  agent_max_steps = 8;
  agent_max_tokens = 0;
  agent_session_id = "s1";
  agent_policy = None;
  agent_action_policy = None;
  agent_allowed_tools = [];
  agent_interrupt_on = [];
  agent_on_interrupt_decision = None;
  agent_on_interrupt = None;
  agent_on_delta = None;
  agent_require_policy = false;
  agent_require_tool_scope = false;
}

let tool_make name description invoke = {
  tool_name = name;
  tool_description = description;
  tool_invoke = invoke;
}

let find_tool tools name =
  let rec loop = function
    | [] -> None
    | tool :: rest -> if tool.tool_name = name then Some tool else loop rest
  in
  loop tools

let redact_message message = {
  message with
  message_content = pii_redact message.message_content;
  message_blocks = List.map (fun block ->
    { block with block_text = Option.map pii_redact block.block_text }) message.message_blocks;
}

let run_agent options session prompt =
  if options.agent_require_policy &&
     options.agent_policy = None && options.agent_action_policy = None then
    raise_core "AGENT_INVALID_OPTIONS" "agent: require policy: policy is required";
  if options.agent_require_tool_scope && options.agent_allowed_tools = [] then
    raise_core "AGENT_INVALID_OPTIONS" "agent: require tool scope: allowed_tools must not be empty";
  let max_steps = if options.agent_max_steps > 0 then options.agent_max_steps else 8 in
  let max_tokens = options.agent_max_tokens in
  (match options.agent_call_limit with
   | Some limit -> limit.models_called <- 0; limit.tools_called <- 0
   | None -> ());
  let run_id = "run-" ^ string_of_int (int_of_float (Sys.time ())) in
  let messages = ref session.session_messages in
  if options.agent_system_prompt <> "" then
    messages := text_message "system" options.agent_system_prompt :: !messages;
  messages := !messages @ [text_message "user" prompt];
  let emit_event event_type data =
    match options.agent_events with
    | Some sink -> sink (event_make event_type session.session_id (Some run_id) data)
    | None -> ()
  in
  let emit_failed message =
    emit_event "run.failed" (Object [("error", String message)])
  in
  let apply_decision kind tool_name arguments policy =
    let result = policy (agent_action_make kind session.session_id tool_name arguments) in
    if not result.decision_allowed then
      raise_core "AGENT_POLICY_DENIED"
        ("agent: " ^ kind ^ " denied" ^
           (if result.decision_reason <> "" then ": " ^ result.decision_reason else ""))
  in
  let authorize_action kind tool_name arguments =
    match options.agent_action_policy with
    | Some policy -> apply_decision kind tool_name arguments policy
    | None ->
        match options.agent_policy with
        | None -> ()
        | Some policy ->
            if not (policy kind) then
              raise_core "AGENT_POLICY_DENIED" ("agent: " ^ kind ^ " denied")
  in
  let authorize kind = authorize_action kind "" Null in
  let apply_interrupt call =
    if not (List.mem call.invocation_name options.agent_interrupt_on) then
      (call, None)
    else begin
      if options.agent_on_interrupt_decision = None && options.agent_on_interrupt = None then
        raise_core "AGENT_INTERRUPT_UNHANDLED"
          ("agent: approval handler not configured: " ^ call.invocation_name);
      emit_event "tool.interrupt" (Object [
        ("name", String call.invocation_name);
        ("arguments", call.invocation_arguments)]);
      let interrupt = interrupt_make run_id session.session_id call in
      match options.agent_on_interrupt_decision with
      | Some handler ->
          let decision = handler interrupt in
          if decision.interrupt_action = interrupt_approve then (call, None)
          else if decision.interrupt_action = interrupt_edit then
            (match decision.interrupt_arguments with
             | None ->
                 raise_core "AGENT_INTERRUPT_DECISION_INVALID" "agent: edit requires arguments"
             | Some arguments ->
                 ({ call with invocation_arguments = arguments }, None))
          else if decision.interrupt_action = interrupt_reject then
            raise_core "AGENT_APPROVAL_DENIED"
              ("agent: tool call denied by approval: " ^ call.invocation_name ^
                 ": " ^ decision.interrupt_reason)
          else if decision.interrupt_action = interrupt_respond then
            (call, Some decision.interrupt_response)
          else
            raise_core "AGENT_INTERRUPT_DECISION_INVALID"
              ("agent: invalid interrupt decision: " ^ decision.interrupt_action)
      | None ->
          let approved =
            match options.agent_on_interrupt with
            | Some approval -> approval interrupt
            | None -> false
          in
          if not approved then
            raise_core "AGENT_APPROVAL_DENIED"
              ("agent: tool call denied by approval: " ^ call.invocation_name);
          (call, None)
    end
  in
  try
    emit_event "run.started" Null;
    let total = ref (usage_make 0 0) in
    let step = ref 0 in
    let result = ref None in
    while !result = None do
      if !step >= max_steps then raise_core "AGENT_MAX_STEPS" "maximum steps exceeded";
      incr step;
      authorize "model.generate";
      let specs =
        let specs = List.map (fun tool -> tool_spec_make tool.tool_name tool.tool_description) options.agent_tools in
        let specs =
          match options.agent_allowed_tools with
          | [] -> specs
          | allowed -> List.filter (fun spec -> List.mem spec.spec_name allowed) specs
        in
        match options.agent_tool_selection with
        | None -> specs
        | Some selection -> select_tools selection specs
      in
      (match options.agent_call_limit with Some limit -> call_limit_model limit | None -> ());
      let request_messages = if options.agent_pii then List.map redact_message !messages else !messages in
      let response =
        match options.agent_on_delta with
        | Some on_delta ->
            (match options.agent_model.generate_stream with
             | Some stream -> stream (request_make request_messages specs) on_delta
             | None ->
                 let result = options.agent_model.generate (request_make request_messages specs) in
                 if result.response_message.message_content <> "" then
                   on_delta result.response_message.message_content;
                 result)
        | None -> options.agent_model.generate (request_make request_messages specs)
      in
      total := usage_add !total response.response_usage;
      if max_tokens > 0 && (!total).input_tokens + (!total).output_tokens > max_tokens then
        raise_core "AGENT_MAX_TOKENS" "token budget exceeded";
      messages := !messages @ [response.response_message];
      if response.response_message.message_calls = [] then begin
        let output =
          match options.agent_structured_output with
          | None -> response.response_message.message_content
          | Some config ->
              let value, code = structured_apply config response.response_message.message_content in
              (match value with
               | Some text -> text
               | None -> raise_core code "structured output failed")
        in
        emit_event "run.completed" Null;
        result := Some (run_result_make run_id output !step !total)
      end else begin
        let prepared = List.map (fun call ->
          let original_name = call.invocation_name in
          let original_arguments = call.invocation_arguments in
          if options.agent_allowed_tools <> [] &&
             not (List.mem original_name options.agent_allowed_tools) then
            raise_core "AGENT_TOOL_NOT_ALLOWED"
              ("agent: tool " ^ original_name ^ " is not allowed");
          (match options.agent_tool_selection with
           | None -> ()
           | Some selection -> check_tool_selected selection original_name);
          authorize_action "tool.invoke" original_name original_arguments;
          let active, interrupt_response = apply_interrupt call in
          match interrupt_response with
          | Some text -> (active, Some text, None)
          | None ->
              if options.agent_allowed_tools <> [] &&
                 not (List.mem active.invocation_name options.agent_allowed_tools) then
                raise_core "AGENT_TOOL_NOT_ALLOWED"
                  ("agent: tool " ^ active.invocation_name ^ " is not allowed");
              if active.invocation_name <> original_name ||
                 not (json_equal active.invocation_arguments original_arguments) then
                authorize_action "tool.invoke" active.invocation_name active.invocation_arguments;
              match find_tool options.agent_tools active.invocation_name with
              | None -> raise_core "TOOL_NOT_FOUND" ("tool not found: " ^ active.invocation_name)
              | Some tool -> (active, None, Some tool)
        ) response.response_message.message_calls in
        (match options.agent_call_limit with
         | Some limit when limit.tool_limit > 0 ->
             let executable = List.fold_left (fun count (_, response, _) ->
               if response = None then count + 1 else count) 0 prepared in
             if limit.tools_called + executable > limit.tool_limit then
               raise_core "AGENT_TOOL_CALL_LIMIT" "tool call limit"
         | _ -> ());
        List.iter (fun (active, interrupt_response, tool) ->
          match interrupt_response, tool with
          | Some text, _ ->
              messages := !messages @
                [tool_message (encode_json (String text)) active.invocation_id]
          | None, Some tool ->
              (match options.agent_call_limit with
               | Some limit -> limit.tools_called <- limit.tools_called + 1
               | None -> ());
              emit_event "tool.call" (Object [
                ("name", String active.invocation_name);
                ("arguments", active.invocation_arguments)]);
              let value = tool.tool_invoke active.invocation_arguments in
              let value = if options.agent_pii then redact_value value else value in
              messages := !messages @ [tool_message (encode_json value) active.invocation_id]
          | None, None -> raise_core "INTERNAL" "agent: prepared tool is missing"
        ) prepared
      end
    done;
    match !result with Some value -> value | None -> raise_core "AGENT_MAX_STEPS" "maximum steps exceeded"
  with error ->
    let backtrace = Printexc.get_raw_backtrace () in
    let message = match error with
      | Core_error (_, message) -> message
      | _ -> Printexc.to_string error
    in
    (try emit_failed message with _ -> ());
    Printexc.raise_with_backtrace error backtrace

