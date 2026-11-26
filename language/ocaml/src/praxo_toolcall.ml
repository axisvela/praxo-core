open Praxo_types
open Praxo_json
let valid_dotted_name name =
  let n = String.length name in
  n >= 3 && String.contains name '.' && name.[0] <> '.' && name.[n - 1] <> '.' &&
  String.for_all (fun c ->
    (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
    (c >= '0' && c <= '9') || c = '_' || c = '.' || c = '-') name

let parse_object_text text =
  try match parse_json text with Object fields -> Some (Object fields) | _ -> None
  with _ -> None

let call_from_object = function
  | Object fields as value ->
      begin match field_string "name" value with
      | Some name when name <> "" ->
          let metadata key =
            match find_last_field key fields with
            | None -> Some ""
            | Some (String value) -> Some value
            | Some Null -> Some ""
            | _ -> None
          in
          begin match metadata "operation", metadata "resource", metadata "risk",
                      metadata "reason", metadata "idempotency_key" with
          | Some operation, Some resource, Some risk, Some reason, Some idempotency_key ->
              let input =
                match find_last_field "input" fields with
                | None | Some Null -> Object []
                | Some (Object _ as value) -> value
                | _ -> Null
              in
              begin match input with
              | Object _ -> Some { name; input; operation; resource; risk; reason; idempotency_key }
              | _ -> None
              end
          | _ -> None
          end
      | _ -> None
      end
  | _ -> None

let parse_xml_block content =
  let rec scan search found last =
    match find_sub content "<tool_call" search with
    | None -> if found then last else None
    | Some open_pos ->
        begin match find_sub content ">" (open_pos + 10) with
        | None -> if found then last else None
        | Some header_end ->
            let header = String.sub content (open_pos + 10) (header_end - open_pos - 10) in
            begin match find_sub header "name=\"" 0 with
            | None -> scan (header_end + 1) found last
            | Some name_start ->
                let after = String.sub header (name_start + 6) (String.length header - name_start - 6) in
                begin match String.index_opt after '"' with
                | None -> if found then last else None
                | Some name_end ->
                    let name = String.sub after 0 name_end in
                    if name = "" then if found then last else None
                    else begin match find_sub content "</tool_call>" (header_end + 1) with
                    | None -> if found then last else None
                    | Some close_pos ->
                        let body = String.sub content (header_end + 1) (close_pos - header_end - 1) in
                        scan (close_pos + 12) true (Some (name, body))
                    end
                end
            end
        end
  in
  match scan 0 false None with
  | None -> None
  | Some (name, body) ->
      begin match parse_object_text body with
      | Some input -> Some { name; input; operation = ""; resource = ""; risk = ""; reason = ""; idempotency_key = "" }
      | None -> None
      end

let parse_tag_block content =
  let rec scan search found last =
    match find_sub content "<" search with
    | None -> if found then last else None
    | Some open_pos ->
        begin match find_sub content ">" (open_pos + 1) with
        | None -> if found then last else None
        | Some header_end ->
            let name = String.sub content (open_pos + 1) (header_end - open_pos - 1) in
            if valid_dotted_name name then
              begin match find_sub content ("</" ^ name ^ ">") (header_end + 1) with
              | None -> if found then last else None
              | Some close_pos ->
                  let body = String.sub content (header_end + 1) (close_pos - header_end - 1) in
                  scan (close_pos + String.length name + 3) true (Some (name, body))
              end
            else scan (header_end + 1) found last
        end
  in
  match scan 0 false None with
  | None -> None
  | Some (name, body) ->
      begin match parse_object_text body with
      | Some input -> Some { name; input; operation = ""; resource = ""; risk = ""; reason = ""; idempotency_key = "" }
      | None -> None
      end

let trim text =
  let n = String.length text in
  let start = ref 0 and finish = ref n in
  while !start < n && is_space text.[!start] do incr start done;
  while !finish > !start && is_space text.[!finish - 1] do decr finish done;
  String.sub text !start (!finish - !start)

let split_lines text =
  let rec loop start acc =
    match find_sub text "\n" start with
    | None -> List.rev (String.sub text start (String.length text - start) :: acc)
    | Some index ->
        let line = String.sub text start (index - start) in
        loop (index + 1) (line :: acc)
  in
  loop 0 []

let parse_plain_line content =
  let lines = List.rev (split_lines content) in
  let rec choose = function
    | [] -> None
    | line :: rest ->
        let line = trim line in
        if line = "" then choose rest
        else
          match String.index_opt line ' ' with
          | None -> choose rest
          | Some space ->
              let name = String.sub line 0 space in
              let body = trim (String.sub line (space + 1) (String.length line - space - 1)) in
              if not (valid_dotted_name name) then choose rest
              else if String.length body < 2 || body.[0] <> '{' || body.[String.length body - 1] <> '}' then None
              else begin match parse_object_text body with
              | Some input -> Some { name; input; operation = ""; resource = ""; risk = ""; reason = ""; idempotency_key = "" }
              | None -> None
              end
  in
  choose lines

let parse_tool_call content =
  if String.length content > max_tool then raise (Toolcall_error "content exceeds capacity");
  let from_json =
    try match parse_json content with Object _ as value -> Some (call_from_object value) | _ -> None
    with _ -> None
  in
  match from_json with
  | Some (Some call) -> Some call
  | Some None -> None
  | None ->
      begin match parse_xml_block content with
      | Some _ as call -> call
      | None ->
          if String.length content > 0 && find_sub content "<tool_call" 0 <> None then None
          else match parse_tag_block content with
          | Some _ as call -> call
          | None ->
              if find_sub content "</" 0 <> None then None
              else parse_plain_line content
      end

let strip_blocks content open_prefix close_tag =
  let buffer = Buffer.create (String.length content) in
  let rec loop index =
    match find_sub content open_prefix index with
    | None -> Buffer.add_substring buffer content index (String.length content - index)
    | Some open_pos ->
        Buffer.add_substring buffer content index (open_pos - index);
        begin match find_sub content ">" (open_pos + String.length open_prefix) with
        | None -> ()
        | Some header_end ->
            begin match find_sub content close_tag (header_end + 1) with
            | None -> ()
            | Some close_pos -> loop (close_pos + String.length close_tag)
            end
        end
  in
  loop 0;
  Buffer.contents buffer

let strip_dotted_blocks content =
  let buffer = Buffer.create (String.length content) in
  let rec loop index =
    match find_sub content "<" index with
    | None -> Buffer.add_substring buffer content index (String.length content - index)
    | Some open_pos ->
        Buffer.add_substring buffer content index (open_pos - index);
        begin match find_sub content ">" (open_pos + 1) with
        | None -> Buffer.add_substring buffer content open_pos (String.length content - open_pos)
        | Some header_end ->
            let name = String.sub content (open_pos + 1) (header_end - open_pos - 1) in
            if valid_dotted_name name then
              begin match find_sub content ("</" ^ name ^ ">") (header_end + 1) with
              | None -> ()
              | Some close_pos -> loop (close_pos + String.length name + 3)
              end
            else begin
              Buffer.add_substring buffer content open_pos (header_end - open_pos + 1);
              loop (header_end + 1)
            end
        end
  in
  loop 0;
  Buffer.contents buffer

let collapse_newlines text =
  let buffer = Buffer.create (String.length text) in
  let rec loop index =
    if index >= String.length text then ()
    else if index + 2 < String.length text && text.[index] = '\n' &&
            text.[index + 1] = '\n' && text.[index + 2] = '\n' then begin
      Buffer.add_string buffer "\n\n";
      loop (index + 3)
    end else begin
      Buffer.add_char buffer text.[index];
      loop (index + 1)
    end
  in
  loop 0;
  Buffer.contents buffer

let parse_input_json raw =
  try
    match parse_json (String.trim raw) with
    | Object _ as value -> Some value
    | _ -> None
  with _ -> None

let strip_tool_call_markup content =
  if String.length content > max_tool then raise (Toolcall_error "content exceeds capacity");
  let result = strip_blocks content "<tool_call" "</tool_call>" in
  let result = strip_dotted_blocks result in
  let result = collapse_newlines result in
  trim result

