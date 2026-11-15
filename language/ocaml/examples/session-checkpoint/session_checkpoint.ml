#use "praxo_core.ml"

let checkpoint_type = "session.checkpoint"

type checkpoint = {
  cp_id : string;
  cp_session_id : string;
  cp_run_id : string;
  cp_status : string;
  cp_messages : core_message list;
}

let json_string key value =
  match field key value with Some (String text) -> text | _ -> ""

let json_string_option key value =
  match field key value with Some (String text) -> Some text | _ -> None

let message_of_wire value =
  let blocks =
    match field "contentBlocks" value with
    | Some (Array items) ->
        List.map (fun item ->
          { block_type = json_string "type" item;
            block_text = json_string_option "text" item;
            block_image_url = json_string_option "image_url" item;
            block_data = json_string_option "data" item }) items
    | _ -> []
  in
  let calls =
    match field "toolCalls" value with
    | Some (Array items) ->
        List.map (fun item ->
          { invocation_id = json_string "id" item;
            invocation_name = json_string "name" item;
            invocation_arguments =
              (match field "arguments" item with Some arguments -> arguments | None -> Null) }) items
    | _ -> []
  in
  { message_role = json_string "role" value;
    message_content = json_string "content" value;
    message_blocks = blocks;
    message_calls = calls;
    message_tool_id = json_string_option "toolId" value }

let checkpoint_wire checkpoint =
  Object [
    ("id", String checkpoint.cp_id);
    ("sessionId", String checkpoint.cp_session_id);
    ("runId", String checkpoint.cp_run_id);
    ("status", String checkpoint.cp_status);
    ("messages", Array (List.map message_wire checkpoint.cp_messages));
  ]

let checkpoint_of_wire value =
  let messages =
    match field "messages" value with
    | Some (Array items) -> List.map message_of_wire items
    | _ -> failwith "checkpoint messages are invalid"
  in
  { cp_id = json_string "id" value;
    cp_session_id = json_string "sessionId" value;
    cp_run_id = json_string "runId" value;
    cp_status = json_string "status" value;
    cp_messages = messages }

let save_checkpoint allowlist store checkpoint =
  let payload = checkpoint_marshal allowlist checkpoint_type (checkpoint_wire checkpoint) in
  Hashtbl.replace store checkpoint.cp_session_id payload

let load_checkpoint allowlist store session_id =
  match Hashtbl.find_opt store session_id with
  | None -> failwith "checkpoint not found"
  | Some payload -> checkpoint_of_wire (checkpoint_unmarshal allowlist payload)

let make_checkpoint checkpoint_id session run_id messages = {
  cp_id = checkpoint_id;
  cp_session_id = session.session_id;
  cp_run_id = run_id;
  cp_status = "completed";
  cp_messages = messages;
}

let turn_model : model = {
  generate = fun request ->
    response_make
      (assistant_message ("turn " ^ string_of_int (List.length request.request_messages)) [])
      (usage_make 0 0);
}

let () =
  let allowlist = checkpoint_allowlist () in
  checkpoint_register allowlist checkpoint_type;
  let store = Hashtbl.create 4 in
  let session =
    session_make "session-1"
      [text_message "user" "first"; text_message "assistant" "ack"]
  in
  save_checkpoint allowlist store
    (make_checkpoint "cp-1" session "run-1" session.session_messages);

  let options = { (agent_options turn_model) with agent_max_steps = 2 } in

  let loaded = load_checkpoint allowlist store session.session_id in
  let session = { session with session_messages = loaded.cp_messages } in
  let result = run_agent options session "second" in
  if result.result_output <> "turn 3" then
    failwith ("unexpected second turn: " ^ result.result_output);

  let session =
    { session with
      session_messages =
        session.session_messages @
        [text_message "user" "second";
         text_message "assistant" result.result_output] }
  in
  save_checkpoint allowlist store
    (make_checkpoint "cp-2" session "run-2" session.session_messages);

  let loaded = load_checkpoint allowlist store session.session_id in
  let session = { session with session_messages = loaded.cp_messages } in
  let result = run_agent options session "third" in
  if result.result_output <> "turn 5" then
    failwith ("unexpected third turn: " ^ result.result_output);

  Printf.printf "restored messages: %d\n" (List.length loaded.cp_messages);
  Printf.printf "output: %s\n" result.result_output
