#use "praxo_core_bundle.ml"

let note_arguments visibility =
  Object [("text", String "hello"); ("visibility", String visibility)]

let fixture_model visibility : model =
  { generate = (fun request ->
      match List.rev request.request_messages with
      | message :: _ when message.message_role = "tool" ->
          response_make (assistant_message "done" []) (usage_make 0 0)
      | _ ->
          response_make
            (assistant_message ""
               [tool_invocation_make "write-note-1" "write_note"
                  (note_arguments visibility)])
            (usage_make 0 0));
    generate_stream = None; }

let visibility_of arguments =
  match arguments with
  | Object fields ->
      let rec find = function
        | [] -> ""
        | ("visibility", String value) :: _ -> value
        | _ :: rest -> find rest
      in
      find fields
  | _ -> ""

let authorize action =
  if action.action_kind = "model.generate" then decision_make true ""
  else if action.action_kind = "tool.invoke" then
    if action.action_tool_name = "write_note" &&
       visibility_of action.action_arguments = "public" then
      decision_make true "only public notes are permitted"
    else decision_make false "only public notes are permitted"
  else decision_make false "unsupported action"

type scenario_result = {
  output : string;
  code : string;
  effects : int;
}

let run_scenario session_id decision =
  let effects = ref 0 in
  let tool =
    tool_make "write_note"
      "Write a short note with the requested visibility."
      (fun _ -> incr effects; String "written")
  in
  let options =
    { (agent_options (fixture_model "public")) with
      agent_tools = [tool];
      agent_allowed_tools = ["write_note"];
      agent_max_steps = 3;
      agent_action_policy = Some authorize;
      agent_interrupt_on = ["write_note"];
      agent_on_interrupt_decision = Some (fun _ -> decision) }
  in
  try
    let result = run_agent options (session_make session_id []) "Write a note." in
    { output = result.result_output; code = ""; effects = !effects }
  with Core_error (code, _) ->
    { output = ""; code; effects = !effects }

let () =
  let approve =
    run_scenario "hitl-approve" (interrupt_decision_make interrupt_approve)
  in
  if approve.code <> "" || approve.output <> "done" || approve.effects <> 1 then
    failwith "approve scenario failed";
  print_endline "approve: written; effects=1";

  let edit =
    run_scenario "hitl-edit"
      (interrupt_decision_make ~arguments:(note_arguments "private")
         interrupt_edit)
  in
  if edit.code <> "AGENT_POLICY_DENIED" || edit.effects <> 0 then
    failwith "edit scenario failed";
  print_endline "edit: policy rejected; effects=0"
