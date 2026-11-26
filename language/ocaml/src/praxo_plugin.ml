open Praxo_types
open Praxo_json
type plugin_process_config = {
  process_plugin_id : string;
  process_path : string;
  process_args : string list;
  process_token : string;
  process_token_env : string;
  process_start_timeout : float;
  process_invoke_timeout : float;
}

type plugin_process_host = {
  process_config : plugin_process_config;
  process_token_value : string;
  process_pid : int;
  process_input : Unix.file_descr;
  process_output : Unix.file_descr;
  process_error : Unix.file_descr;
  mutable process_buffer : string;
  mutable process_stderr : string;
  mutable process_seq : int;
  mutable process_active : bool;
}

let plugin_process_config_make plugin_id path args token = {
  process_plugin_id = plugin_id;
  process_path = path;
  process_args = args;
  process_token = token;
  process_token_env = "PRAXOVELA_PLUGIN_TOKEN";
  process_start_timeout = 10.0;
  process_invoke_timeout = 30.0;
}

let plugin_process_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

let plugin_process_encode input =
  let out = Buffer.create (String.length input * 2) in
  let length = String.length input in
  let index = ref 0 in
  while !index < length do
    let a = Char.code input.[!index] in
    let b = if !index + 1 < length then Char.code input.[!index + 1] else 0 in
    let c = if !index + 2 < length then Char.code input.[!index + 2] else 0 in
    Buffer.add_char out plugin_process_alphabet.[a lsr 2];
    Buffer.add_char out plugin_process_alphabet.[((a land 3) lsl 4) lor (b lsr 4)];
    Buffer.add_char out (if !index + 1 < length then plugin_process_alphabet.[((b land 15) lsl 2) lor (c lsr 6)] else '=');
    Buffer.add_char out (if !index + 2 < length then plugin_process_alphabet.[c land 63] else '=');
    index := !index + 3
  done;
  Buffer.contents out

let plugin_process_decode input =
  let table = Array.make 256 (-1) in
  String.iteri (fun index value -> table.(Char.code value) <- index) plugin_process_alphabet;
  let out = Buffer.create (String.length input) in
  let buffer = ref 0 in
  let bits = ref 0 in
  String.iter (fun value ->
      if value <> '=' then begin
        let digit = table.(Char.code value) in
        if digit < 0 then raise_core "INTERNAL" "plugin: invalid payload";
        buffer := (!buffer lsl 6) lor digit;
        bits := !bits + 6;
        if !bits >= 8 then begin
          bits := !bits - 8;
          Buffer.add_char out (Char.chr ((!buffer lsr !bits) land 255))
        end
      end) input;
  Buffer.contents out

let plugin_process_write host text =
  let data = Bytes.of_string text in
  let rec loop offset =
    if offset < Bytes.length data then
      let written = Unix.write host.process_input data offset (Bytes.length data - offset) in
      loop (offset + written)
  in
  loop 0

let plugin_process_drain_stderr host =
  let buffer = Bytes.create 8192 in
  let rec drain () =
    let ready, _, _ = Unix.select [host.process_error] [] [] 0.0 in
    if ready = [] then ()
    else
      let count = try Unix.read host.process_error buffer 0 8192 with Unix.Unix_error _ -> 0 in
      if count > 0 then begin
        let combined = host.process_stderr ^ Bytes.sub_string buffer 0 count in
        host.process_stderr <-
          if String.length combined > 16384 then String.sub combined (String.length combined - 16384) 16384
          else combined;
        drain ()
      end
  in
  drain ()

let plugin_process_read host timeout =
  let deadline = Unix.gettimeofday () +. timeout in
  let rec loop () =
    match String.index_opt host.process_buffer '\n' with
    | Some index ->
        let line = String.sub host.process_buffer 0 index in
        host.process_buffer <-
          String.sub host.process_buffer (index + 1)
            (String.length host.process_buffer - index - 1);
        Some line
    | None ->
        let remaining = deadline -. Unix.gettimeofday () in
        if remaining <= 0.0 then None
        else
          let ready, _, _ =
            Unix.select [host.process_output; host.process_error] [] [] remaining in
          if List.exists (fun descriptor -> descriptor = host.process_error) ready then
            plugin_process_drain_stderr host;
          if not (List.exists (fun descriptor -> descriptor = host.process_output) ready) then
            if ready = [] then None else loop ()
          else
            let buffer = Bytes.create 8192 in
            let count = Unix.read host.process_output buffer 0 8192 in
            if count = 0 then None
            else begin
              host.process_buffer <- host.process_buffer ^ Bytes.sub_string buffer 0 count;
              loop ()
            end
  in
  loop ()

let plugin_process_call host service method_name payload timeout =
  host.process_seq <- host.process_seq + 1;
  let request_id = Printf.sprintf "req-%d" host.process_seq in
  let frame = Object [
    ("id", String request_id);
    ("version", Number 1.0);
    ("plugin_id", String host.process_config.process_plugin_id);
    ("service", String service);
    ("method", String method_name);
    ("token", String host.process_token_value);
    ("payload", String (plugin_process_encode payload));
  ] in
  plugin_process_write host (encode_json frame ^ "\n");
  let deadline = Unix.gettimeofday () +. timeout in
  let rec await () =
    let remaining = deadline -. Unix.gettimeofday () in
    if remaining <= 0.0 then raise_core "TIMEOUT" "plugin: invocation timed out";
    match plugin_process_read host remaining with
    | None -> raise_core "TIMEOUT" "plugin: invocation timed out"
    | Some line ->
        match parse_json line with
        | Object fields ->
            let object_value = Object fields in
            let id = match field_string "id" object_value with Some value -> value | None -> "" in
            if id <> request_id then await ()
            else if field "ok" object_value <> Some (Bool true) then
              let code = match field_string "code" object_value with Some value -> value | None -> "INTERNAL" in
              let message = match field_string "message" object_value with Some value -> value | None -> "" in
              raise_core code message
            else
              let payload = match field_string "payload" object_value with Some value -> value | None -> "" in
              plugin_process_decode payload
        | _ -> await ()
  in
  await ()

let start_plugin_process config =
  if config.process_plugin_id = "" then raise_core "INVALID_REQUEST" "plugin: PluginID is required";
  if config.process_path = "" then raise_core "INVALID_REQUEST" "plugin: path is required";
  let token = if config.process_token = "" then Digest.to_hex (Digest.string (string_of_float (Unix.gettimeofday ()))) else config.process_token in
  let input_read, input_write = Unix.pipe () in
  let output_read, output_write = Unix.pipe () in
  let error_read, error_write = Unix.pipe () in
  let env = Array.of_list ((config.process_token_env ^ "=" ^ token) :: Array.to_list (Unix.environment ())) in
  let argv = Array.of_list (config.process_path :: config.process_args) in
  let close_quietly descriptor = try Unix.close descriptor with Unix.Unix_error _ -> () in
  let pid =
    try Unix.create_process_env config.process_path argv env input_read output_write error_write
    with error ->
      List.iter close_quietly [input_read; input_write; output_read; output_write; error_read; error_write];
      raise error
  in
  Unix.close input_read;
  Unix.close output_write;
  Unix.close error_write;
  let host = {
    process_config = config;
    process_token_value = token;
    process_pid = pid;
    process_input = input_write;
    process_output = output_read;
    process_error = error_read;
    process_buffer = "";
    process_stderr = "";
    process_seq = 0;
    process_active = false;
  } in
  try
    ignore (plugin_process_call host "host.control" "health" "" config.process_start_timeout);
    host.process_active <- true;
    host
  with error ->
    (try Unix.kill pid Sys.sigkill with Unix.Unix_error _ -> ());
    (try ignore (Unix.waitpid [] pid) with Unix.Unix_error _ -> ());
    List.iter close_quietly [input_write; output_read; error_read];
    raise error

let invoke_plugin_process host service method_name payload =
  if not host.process_active then raise_core "NOT_ACTIVE" "plugin: host is not active";
  plugin_process_call host service method_name payload host.process_config.process_invoke_timeout

let stop_plugin_process host =
  (try ignore (plugin_process_call host "host.control" "shutdown" "" 5.0) with _ -> ());
  host.process_active <- false;
  (try Unix.kill host.process_pid Sys.sigkill with _ -> ());
  (try ignore (Unix.waitpid [] host.process_pid) with _ -> ());
  Unix.close host.process_input;
  Unix.close host.process_output;
  Unix.close host.process_error

