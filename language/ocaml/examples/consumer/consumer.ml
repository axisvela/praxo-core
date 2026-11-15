#use "praxo_core.ml"

let fixture_model target : model =
  { generate = fun request ->
      match List.rev request.request_messages with
      | message :: _ when message.message_role = "tool" ->
          response_make (assistant_message "recorded" []) (usage_make 0 0)
      | _ ->
          response_make
            (assistant_message ""
               [tool_invocation_make "record-1" "record"
                  (Object [("target", String target)])])
            (usage_make 0 0) }

let authorize target kind =
  kind = "model.generate" || (kind = "tool.invoke" && target = "public")

let run_case target =
  let calls = ref 0 in
  let record =
    tool_make "record" "Record a target in an in-memory counter."
      (fun _ -> incr calls; String "recorded")
  in
  let options =
    { (agent_options (fixture_model target)) with
      agent_tools = [record];
      agent_allowed_tools = ["record"];
      agent_max_steps = 3;
      agent_policy = Some (authorize target) }
  in
  try
    let result =
      run_agent options (session_make ("consumer-" ^ target) [])
        "Record the requested target."
    in
    (Some result.result_output, !calls, None)
  with Core_error (code, _) -> (None, !calls, Some code)

let () =
  let output, calls, error = run_case "public" in
  (match output, calls, error with
   | Some "recorded", 1, None -> print_endline "allow: recorded; effects=1"
   | _ -> failwith "allow verification failed");

  let output, calls, error = run_case "private" in
  (match output, calls, error with
   | None, 0, Some "AGENT_POLICY_DENIED" ->
       print_endline "deny: policy rejected; effects=0"
   | _ -> failwith "deny verification failed")
