open Praxo_types
open Praxo_json
open Praxo_schema
open Praxo_message
open Praxo_provider_util
let session_make session_id messages = { session_id; session_messages = messages }

let run_result_make run_id output steps usage_value = {
  result_run_id = run_id;
  result_output = output;
  result_steps = steps;
  result_usage = usage_value;
}

let memory_record_make id frame content created_at = {
  record_id = id;
  record_frame = frame;
  record_content = content;
  record_created_at = created_at;
}

let path_grant_make root access = { grant_root = root; grant_access = access }
let decision_make allowed reason = { decision_allowed = allowed; decision_reason = reason }

let event_make event_type session_id run_id data = {
  event_type;
  event_session_id = session_id;
  event_run_id = run_id;
  event_data = data;
}

let context_budget_make max_tokens keep_recent = {
  budget_max_tokens = max_tokens;
  budget_keep_recent = keep_recent;
}

let message_wire message =
  let fields = ref [("role", String message.message_role)] in
  if message.message_content <> "" ||
     (message.message_blocks = [] && message.message_calls = [] && message.message_tool_id = None)
  then fields := !fields @ [("content", String message.message_content)];
  if message.message_blocks <> [] then
    fields := !fields @ [("contentBlocks", Array (List.map (fun block ->
      let item = ref [("type", String block.block_type)] in
      (match block.block_text with Some value -> item := !item @ [("text", String value)] | None -> ());
      (match block.block_image_url with Some value -> item := !item @ [("image_url", String value)] | None -> ());
      (match block.block_data with Some value -> item := !item @ [("data", String value)] | None -> ());
      Object !item) message.message_blocks))];
  if message.message_calls <> [] then
    fields := !fields @ [("toolCalls", Array (List.map (fun call -> Object [
      ("id", String call.invocation_id);
      ("name", String call.invocation_name);
      ("arguments", call.invocation_arguments);
    ]) message.message_calls))];
  (match message.message_tool_id with Some value -> fields := !fields @ [("toolId", String value)] | None -> ());
  Object !fields

let emit sink event = sink event
let multi_sink sinks = fun event -> List.iter (fun sink -> sink event) sinks
let filter_sink sink predicate_types = fun event ->
  if predicate_types = [] || List.mem event.event_type predicate_types then sink event

let harmovela_config base_url transport clock = {
  harmovela_base_url = base_url;
  harmovela_source = "praxo-core";
  harmovela_spec_version = "0.2";
  harmovela_clock = clock;
  harmovela_transport = transport;
}

let harmovela_floor_div left right =
  let quotient = left / right in
  if left mod right <> 0 && ((left < 0) <> (right < 0)) then quotient - 1 else quotient

let harmovela_civil days =
  let z = days + 719468 in
  let era = if z >= 0 then z / 146097 else (z - 146096) / 146097 in
  let doe = z - era * 146097 in
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365 in
  let year = yoe + era * 400 in
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100) in
  let mp = (5 * doy + 2) / 153 in
  let day = doy - (153 * mp + 2) / 5 + 1 in
  let month = if mp < 10 then mp + 3 else mp - 9 in
  ((if month <= 2 then year + 1 else year), month, day)

let format_harmovela_timestamp nanos =
  let seconds = harmovela_floor_div nanos 1_000_000_000 in
  let fraction = nanos - seconds * 1_000_000_000 in
  let days = harmovela_floor_div seconds 86400 in
  let day_seconds = seconds - days * 86400 in
  let year, month, day = harmovela_civil days in
  let hour = day_seconds / 3600 in
  let minute = (day_seconds mod 3600) / 60 in
  let second = day_seconds mod 60 in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02d.%09dZ"
    year month day hour minute second fraction

let harmovela_payload event =
  let base = match event.event_data with Object fields -> fields | _ -> [] in
  let apply key value fields =
    match value with
    | None | Some "" -> fields
    | Some text -> List.filter (fun (name, _) -> name <> key) fields @ [(key, String text)]
  in
  apply "session_id"
    (if event.event_session_id = "" then None else Some event.event_session_id)
    (apply "run_id" event.event_run_id base)

let harmovela_envelope config event nanos =
  let prefix = match event.event_run_id with
    | Some value when value <> "" -> value
    | _ -> if event.event_session_id = "" then "event" else event.event_session_id
  in
  let source = if config.harmovela_source = "" then "praxo-core" else config.harmovela_source in
  let spec_version =
    if config.harmovela_spec_version = "" then "0.2" else config.harmovela_spec_version in
  Object [
    ("spec_version", String spec_version);
    ("id", String (Printf.sprintf "%s-%d" prefix nanos));
    ("type", String event.event_type);
    ("source", String source);
    ("created_at", String (format_harmovela_timestamp nanos));
    ("payload", Object (harmovela_payload event));
  ]

let rec harmovela_trim_slash text =
  let length = String.length text in
  if length > 0 && text.[length - 1] = '/'
  then harmovela_trim_slash (String.sub text 0 (length - 1))
  else text

let harmovela_emit config event =
  if config.harmovela_base_url = "" then
    raise_core "HARMOVELA_URL" "harmovela: base URL is required";
  let nanos = config.harmovela_clock () in
  let request = {
    http_method = "POST";
    http_url = harmovela_trim_slash config.harmovela_base_url ^ "/events";
    http_headers = [("content-type", "application/json")];
    http_payload = encode_json (harmovela_envelope config event nanos);
  } in
  let response = config.harmovela_transport request in
  if response.http_status < 200 || response.http_status >= 300 then
    raise_core "HARMOVELA_HTTP"
      (Printf.sprintf "harmovela: HTTP %d: %s" response.http_status
        (openai_bound (String.trim response.http_body)))

let harmovela_sink config event = harmovela_emit config event

let memory_store () = { records = Hashtbl.create 8; sequence = 0 }

let memory_put store session_id record =
  let record =
    if record.record_id = "" then begin
      let id = Printf.sprintf "mem-%d" store.sequence in
      store.sequence <- store.sequence + 1;
      { record with record_id = id }
    end else record
  in
  let existing = match Hashtbl.find_opt store.records session_id with Some value -> value | None ->
    let value = ref [] in Hashtbl.add store.records session_id value; value
  in
  existing := !existing @ [record];
  record

let memory_search store session_id query limit =
  let records = match Hashtbl.find_opt store.records session_id with Some value -> !value | None -> [] in
  let needle = String.lowercase_ascii (String.trim query) in
  let matches = List.filter (fun record ->
    needle = "" ||
      match find_sub (String.lowercase_ascii record.record_content) needle 0 with
      | Some _ -> true
      | None -> false
  ) records in
  let sorted = List.sort (fun left right ->
    compare (Option.value ~default:"" right.record_created_at)
            (Option.value ~default:"" left.record_created_at)) matches in
  if limit > 0 then
    let rec take n values = if n <= 0 then [] else match values with [] -> [] | head :: tail -> head :: take (n - 1) tail in
    take limit sorted
  else sorted

let checkpoint_allowlist () = Hashtbl.create 8

let checkpoint_register allowlist event_type =
  if event_type = "" then raise_core "CHECKPOINT_ERROR" "checkpoint: type is required";
  Hashtbl.replace allowlist event_type ()

let checkpoint_marshal allowlist event_type value =
  if not (Hashtbl.mem allowlist event_type) then
    raise_core "CHECKPOINT_TYPE_NOT_ALLOWED" "checkpoint: payload type not allowed";
  encode_json (Object [("type", String event_type); ("data", value)])

let checkpoint_unmarshal allowlist data =
  match parse_json data with
  | Object _ as envelope ->
      let event_type = match field_string "type" envelope with Some value -> value | None -> "" in
      if not (Hashtbl.mem allowlist event_type) then
        raise_core "CHECKPOINT_TYPE_NOT_ALLOWED" "checkpoint: payload type not allowed";
      (match field "data" envelope with Some value -> value | None -> Null)
  | _ -> raise_core "CHECKPOINT_ERROR" "checkpoint: envelope must be an object"

let normalize_path value =
  let path = String.map (fun character -> if character = '\\' then '/' else character) value in
  let prefix, body =
    if String.length path >= 2 && path.[1] = ':' then
      (String.sub path 0 2, String.sub path 2 (String.length path - 2))
    else if starts_with "/" path then ("/", path)
    else ("", path)
  in
  let parts = ref [] in
  List.iter (fun part ->
    if part = "" || part = "." then ()
    else if part = ".." then (match !parts with
      | head :: rest when head <> ".." -> parts := rest
      | _ when prefix <> "/" && not (starts_with "/" body) -> parts := ".." :: !parts
      | _ -> ())
    else parts := part :: !parts) (String.split_on_char '/' body);
  let result = prefix ^ String.concat "/" (List.rev !parts) in
  if Sys.win32 then String.lowercase_ascii result else result

let path_within root target =
  root = target ||
  if root = "/" then starts_with "/" target
  else if root = "" then
    target <> "" && target <> ".." && not (starts_with "../" target) && not (starts_with "/" target)
  else starts_with (root ^ "/") target

let access_allows grant need =
  if need = "read" then grant = "read" || grant = "readwrite"
  else if need = "write" then grant = "write" || grant = "readwrite"
  else grant = "readwrite"

let path_checker grants =
  List.map (fun grant ->
    if grant.grant_root = "" then raise_core "POLICY_ERROR" "policy: path grant root is required";
    if not (List.mem grant.grant_access ["read"; "write"; "readwrite"]) then
      raise_core "POLICY_ERROR" "policy: invalid grant access";
    { grant with grant_root = normalize_path grant.grant_root }) grants

let path_check checker target need =
  if not (List.mem need ["read"; "write"; "readwrite"]) then
    raise_core "POLICY_ERROR" "policy: invalid requested access";
  if checker = [] then decision_make false "no allowed roots"
  else
    let resolved = normalize_path target in
    let matched = ref false in
    let allowed = List.exists (fun grant ->
      if path_within grant.grant_root resolved then begin
        matched := true;
        access_allows grant.grant_access need
      end else false) checker in
    if allowed then decision_make true "allowed"
    else decision_make false (if !matched then "insufficient grant" else "outside roots")

let path_allowed checker target need =
  try (path_check checker target need).decision_allowed with Core_error _ -> false

let estimate_tokens messages =
  List.fold_left (fun total message ->
    let total = total + 4 + String.length message.message_content / 4 + String.length (Option.value ~default:"" message.message_tool_id) / 4 in
    let total = List.fold_left (fun acc block -> acc + 4 + String.length (Option.value ~default:"" block.block_text) / 4) total message.message_blocks in
    List.fold_left (fun acc call -> acc + 4 + String.length call.invocation_name / 4 + String.length (encode_json call.invocation_arguments) / 4) total message.message_calls
  ) 0 messages

let truncate_to_tokens value tokens =
  if tokens <= 0 then ""
  else
    let limit = tokens * 4 in
    if String.length value <= limit then value
    else if limit <= 16 then String.sub value 0 limit
    else String.sub value 0 (limit - 16) ^ "\n[truncated]"

let compact_context budget messages =
  if budget.budget_max_tokens <= 0 || estimate_tokens messages <= budget.budget_max_tokens then (messages, true)
  else
    let system, rest = List.partition (fun message -> message.message_role = "system" &&
      not (starts_with "[context compacted:" message.message_content)) messages in
    let system =
      if estimate_tokens system > budget.budget_max_tokens then
        match system with
        | [] -> []
        | first :: _ -> [{ first with message_content = truncate_to_tokens first.message_content (budget.budget_max_tokens - 4) }]
      else system
    in
    if estimate_tokens system > budget.budget_max_tokens then ([], false)
    else
      let keep = if budget.budget_keep_recent > 0 then budget.budget_keep_recent else 4 in
      let rest_array = Array.of_list rest in
      let start = ref (max 0 (Array.length rest_array - keep)) in
      while !start > 0 && rest_array.(!start).message_role = "tool" do decr start done;
      let marker = text_message "system" (Printf.sprintf "[context compacted: %d older messages omitted]" !start) in
      let kept = if !start >= Array.length rest_array then [] else Array.to_list (Array.sub rest_array !start (Array.length rest_array - !start)) in
      let build kept = system @ (if !start > 0 then [marker] else []) @ kept in
      let rec shrink kept =
        let output = build kept in
        if estimate_tokens output > budget.budget_max_tokens && List.length kept > 1 then
          match kept with
          | _ :: second :: _ when second.message_role = "tool" -> (output, false)
          | _ -> shrink (List.tl kept)
        else (output, estimate_tokens output <= budget.budget_max_tokens)
      in
      shrink kept

let is_alpha character =
  (character >= 'a' && character <= 'z') || (character >= 'A' && character <= 'Z')

let is_email_local character =
  is_alpha character || is_digit character ||
  List.mem character ['.'; '_'; '%'; '+'; '-']

let is_domain_character character =
  is_alpha character || is_digit character || List.mem character ['.'; '-']

let pii_redact text =
  let n = String.length text in
  let buffer = Buffer.create n in
  let rec email i =
    if i >= n then ()
    else if text.[i] = '@' then begin
      let start = ref i in
      while !start > 0 && is_email_local text.[!start - 1] do decr start done;
      let ending = ref (i + 1) in
      while !ending < n && is_domain_character text.[!ending] do incr ending done;
      let domain = String.sub text (i + 1) (!ending - i - 1) in
      let dot = try Some (String.rindex domain '.') with Not_found -> None in
      let valid = match dot with
        | Some position when position > 0 && String.length domain - position - 1 >= 2 ->
            let tld = String.sub domain (position + 1) (String.length domain - position - 1) in
            String.for_all is_alpha tld
        | _ -> false
      in
      if valid then begin
        let remove = i - !start in
        Buffer.truncate buffer (Buffer.length buffer - remove);
        Buffer.add_string buffer "[REDACTED:email]";
        email !ending
      end else begin
        Buffer.add_char buffer text.[i];
        email (i + 1)
      end
    end else begin
      Buffer.add_char buffer text.[i];
      email (i + 1)
    end
  in
  email 0;
  let first = Buffer.contents buffer in
  let buffer = Buffer.create (String.length first) in
  let rec ssn i =
    if i >= String.length first then ()
    else if i + 11 <= String.length first && is_digit first.[i] && is_digit first.[i+1] &&
            is_digit first.[i+2] && first.[i+3] = '-' && is_digit first.[i+4] &&
            is_digit first.[i+5] && first.[i+6] = '-' && is_digit first.[i+7] &&
            is_digit first.[i+8] && is_digit first.[i+9] && is_digit first.[i+10] then begin
      Buffer.add_string buffer "[REDACTED:ssn]";
      ssn (i + 11)
    end else begin
      Buffer.add_char buffer first.[i];
      ssn (i + 1)
    end
  in
  ssn 0;
  let second = Buffer.contents buffer in
  let buffer = Buffer.create (String.length second) in
  let credit_card_at start =
    let index = ref start in
    let valid = ref true in
    for group = 0 to 3 do
      if group > 0 && !index < String.length second && List.mem second.[!index] [' '; '-'] then incr index;
      for _ = 0 to 3 do
        if !index >= String.length second || not (is_digit second.[!index]) then valid := false
        else incr index
      done
    done;
    if !valid then !index else start
  in
  let rec card i =
    if i >= String.length second then ()
    else
      let ending = credit_card_at i in
      if ending > i then begin
        Buffer.add_string buffer "[REDACTED:credit_card]";
        card ending
      end else begin
        Buffer.add_char buffer second.[i];
        card (i + 1)
      end
  in
  card 0;
  Buffer.contents buffer

let rec redact_value value =
  match value with
  | String text -> String (pii_redact text)
  | Array items -> Array (List.map redact_value items)
  | Object fields -> Object (List.map (fun (key, item) -> (key, redact_value item)) fields)
  | other -> other

let extract_json text =
  let value = String.trim text in
  let value =
    if starts_with "```" value then
      let value = match String.index_opt value '\n' with
        | Some index -> String.sub value (index + 1) (String.length value - index - 1)
        | None -> value
      in
      match String.rindex_opt value '`' with
      | Some _ ->
          let rec find_close index =
            if index < 0 then 0
            else if index >= 2 && String.sub value (index - 2) 3 = "```" then index - 2
            else find_close (index - 1)
          in
          String.trim (String.sub value 0 (find_close (String.length value - 1)))
      | None -> String.trim value
    else value
  in
  let object_start = String.index_opt value '{' in
  let array_start = String.index_opt value '[' in
  let start = match object_start, array_start with
    | Some a, Some b -> Some (min a b)
    | Some a, None -> Some a
    | None, Some b -> Some b
    | None, None -> None
  in
  match start with
  | None -> None
  | Some index -> (try Some (parse_json (String.sub value index (String.length value - index))) with _ -> None)

let structured_output schema max_repairs repairer = {
  output_schema = schema;
  max_repairs;
  repairer;
}

let structured_apply config text =
  let rec attempt count output =
    let valid = match extract_json output with
      | Some value -> validate_schema config.output_schema value = []
      | None -> false
    in
    if valid then (Some output, "")
    else if count = config.max_repairs then (None, "AGENT_STRUCTURED_OUTPUT")
    else match config.repairer with
      | None -> (None, "AGENT_STRUCTURED_OUTPUT")
      | Some repair ->
          let repaired = repair output in
          if String.trim repaired = "" then (None, "AGENT_STRUCTURED_OUTPUT")
          else attempt (count + 1) repaired
  in
  attempt 0 text

