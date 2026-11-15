#use "praxo_core.ml"

let get_env name fallback =
  match Sys.getenv_opt name with
  | Some value when value <> "" -> value
  | _ -> fallback

let iso8601 tm =
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02d"
    (tm.Unix.tm_year + 1900) (tm.Unix.tm_mon + 1) tm.Unix.tm_mday
    tm.Unix.tm_hour tm.Unix.tm_min tm.Unix.tm_sec

let get_time_value arguments =
  let zone =
    match arguments with
    | Object fields ->
        (match List.assoc_opt "zone" fields with
         | Some (String value) -> value
         | _ -> "utc")
    | _ -> "utc"
  in
  if zone = "local" then
    String (iso8601 (Unix.localtime (Unix.time ())))
  else
    String (iso8601 (Unix.gmtime (Unix.time ())) ^ "Z")

let transport request =
  failwith
    (Printf.sprintf
       "no HTTP transport is configured for %s %s; supply a transport function"
       request.http_method request.http_url)

let () =
  let base_url = get_env "PRAXO_BASE_URL" "http://localhost:11434/v1" in
  let model_name = get_env "PRAXO_MODEL" "qwen3.5:4b" in
  let prompt =
    get_env "PRAXO_PROMPT"
      "What time is it? Use get_time with zone set to utc and reply with the time."
  in
  let api_key =
    match Sys.getenv_opt "PRAXO_API_KEY" with
    | Some value when value <> "" -> Some value
    | _ -> None
  in
  let config =
    { openai_base_url = base_url;
      openai_model = model_name;
      openai_api_key = api_key;
      openai_tool_choice = Some "auto" }
  in
  let get_time =
    tool_make "get_time"
      "Return the current time in ISO 8601 format for the requested zone."
      get_time_value
  in
  let options =
    { (agent_options (openai_model config transport)) with
      agent_tools = [get_time];
      agent_allowed_tools = ["get_time"];
      agent_system_prompt =
        "You are a concise assistant. Use the provided tools when they help.";
      agent_max_steps = 4;
      agent_policy =
        Some (fun kind -> kind = "model.generate" || kind = "tool.invoke") }
  in
  try
    let result = run_agent options (session_make "live-model" []) prompt in
    print_endline result.result_output
  with error ->
    prerr_endline ("live model run failed: " ^ Printexc.to_string error);
    prerr_endline
      (Printf.sprintf
         "Check PRAXO_BASE_URL (%s), PRAXO_MODEL (%s), and PRAXO_API_KEY"
         base_url model_name);
    exit 1
