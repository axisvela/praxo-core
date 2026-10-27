type json =
  | Object of (string * json) list
  | Array of json list
  | String of string
  | Number of float
  | Bool of bool
  | Null

type call = {
  name : string;
  input : json;
  operation : string;
  resource : string;
  risk : string;
  reason : string;
  idempotency_key : string;
}

exception Json_error of string
exception Schema_error of string
exception Toolcall_error of string

let spec_version = "0.2.0"
let sdk_version = "0.2.0"

let stream_kinds = ["values"; "updates"; "messages"; "tasks"; "debug"; "checkpoint"]
let max_json = 1048576
let max_tool = 262144
let max_depth = 64

let is_space = function ' ' | '\t' | '\n' | '\r' -> true | _ -> false
let is_digit c = c >= '0' && c <= '9'
let is_hex c = is_digit c || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')

let hex_value c =
  if is_digit c then Char.code c - Char.code '0'
  else if c >= 'a' && c <= 'f' then Char.code c - Char.code 'a' + 10
  else Char.code c - Char.code 'A' + 10

let utf8_of_codepoint cp =
  let buffer = Buffer.create 4 in
  if cp < 0 || cp > 0x10ffff || (cp >= 0xd800 && cp <= 0xdfff) then
    raise (Json_error "invalid Unicode code point");
  if cp < 0x80 then Buffer.add_char buffer (Char.chr cp)
  else if cp < 0x800 then begin
    Buffer.add_char buffer (Char.chr (0xc0 lor (cp lsr 6)));
    Buffer.add_char buffer (Char.chr (0x80 lor (cp land 0x3f)))
  end else if cp < 0x10000 then begin
    Buffer.add_char buffer (Char.chr (0xe0 lor (cp lsr 12)));
    Buffer.add_char buffer (Char.chr (0x80 lor ((cp lsr 6) land 0x3f)));
    Buffer.add_char buffer (Char.chr (0x80 lor (cp land 0x3f)))
  end else begin
    Buffer.add_char buffer (Char.chr (0xf0 lor (cp lsr 18)));
    Buffer.add_char buffer (Char.chr (0x80 lor ((cp lsr 12) land 0x3f)));
    Buffer.add_char buffer (Char.chr (0x80 lor ((cp lsr 6) land 0x3f)));
    Buffer.add_char buffer (Char.chr (0x80 lor (cp land 0x3f)))
  end;
  Buffer.contents buffer

let codepoint_count s =
  let n = String.length s in
  let rec loop i count =
    if i >= n then Some count
    else
      let b = Char.code s.[i] in
      if b < 0x80 then loop (i + 1) (count + 1)
      else
        let extra, minimum, cp0 =
          if b >= 0xc2 && b <= 0xdf then (1, 0x80, b land 0x1f)
          else if b >= 0xe0 && b <= 0xef then (2, 0x800, b land 0x0f)
          else if b >= 0xf0 && b <= 0xf4 then (3, 0x10000, b land 0x07)
          else (-1, 0, 0)
        in
        if extra < 0 || i + extra >= n then None
        else
          let ok = ref true and cp = ref cp0 in
          for j = 1 to extra do
            let c = Char.code s.[i + j] in
            if c land 0xc0 <> 0x80 then ok := false;
            cp := (!cp lsl 6) lor (c land 0x3f)
          done;
          if not !ok || !cp < minimum || !cp > 0x10ffff ||
             (!cp >= 0xd800 && !cp <= 0xdfff) then None
          else loop (i + extra + 1) (count + 1)
  in
  loop 0 0

let parse_json text =
  if String.length text > max_json then raise (Json_error "JSON input exceeds capacity");
  let n = String.length text in
  let pos = ref 0 in
  let error message = raise (Json_error message) in
  let skip () = while !pos < n && is_space text.[!pos] do incr pos done in
  let parse_string () =
    if !pos >= n || text.[!pos] <> '"' then error "expected string";
    incr pos;
    let buffer = Buffer.create 16 in
    let rec loop () =
      if !pos >= n then error "unterminated string";
      let c = text.[!pos] in
      incr pos;
      if c = '"' then ()
      else if c = '\\' then begin
        if !pos >= n then error "incomplete escape";
        let e = text.[!pos] in
        incr pos;
        match e with
        | '"' | '\\' | '/' -> Buffer.add_char buffer e; loop ()
        | 'b' -> Buffer.add_char buffer '\b'; loop ()
        | 'f' -> Buffer.add_char buffer '\012'; loop ()
        | 'n' -> Buffer.add_char buffer '\n'; loop ()
        | 'r' -> Buffer.add_char buffer '\r'; loop ()
        | 't' -> Buffer.add_char buffer '\t'; loop ()
        | 'u' ->
            let read_hex () =
              if !pos + 3 >= n then error "incomplete Unicode escape";
              let value = ref 0 in
              for _ = 1 to 4 do
                if not (is_hex text.[!pos]) then error "invalid Unicode escape";
                value := (!value lsl 4) lor hex_value text.[!pos];
                incr pos
              done;
              !value
            in
            let cp = read_hex () in
            if cp >= 0xd800 && cp <= 0xdbff then begin
              if !pos + 1 >= n || text.[!pos] <> '\\' || text.[!pos + 1] <> 'u' then
                error "missing low surrogate";
              pos := !pos + 2;
              let low = read_hex () in
              if low < 0xdc00 || low > 0xdfff then error "invalid low surrogate";
              Buffer.add_string buffer (utf8_of_codepoint (0x10000 + ((cp - 0xd800) lsl 10) + low - 0xdc00))
            end else if cp >= 0xdc00 && cp <= 0xdfff then
              error "unexpected low surrogate"
            else
              Buffer.add_string buffer (utf8_of_codepoint cp);
            loop ()
        | _ -> error "invalid escape"
      end
      else if Char.code c < 32 then error "control character in string"
      else begin
        Buffer.add_char buffer c;
        loop ()
      end
    in
    loop ();
    let value = Buffer.contents buffer in
    begin match codepoint_count value with None -> error "invalid UTF-8 string" | Some _ -> () end;
    value
  in
  let parse_number () =
    let start = !pos in
    if !pos < n && text.[!pos] = '-' then incr pos;
    if !pos >= n then error "invalid number";
    if text.[!pos] = '0' then incr pos
    else if text.[!pos] >= '1' && text.[!pos] <= '9' then
      while !pos < n && is_digit text.[!pos] do incr pos done
    else error "invalid number";
    if !pos < n && text.[!pos] = '.' then begin
      incr pos;
      if !pos >= n || not (is_digit text.[!pos]) then error "invalid fraction";
      while !pos < n && is_digit text.[!pos] do incr pos done
    end;
    if !pos < n && (text.[!pos] = 'e' || text.[!pos] = 'E') then begin
      incr pos;
      if !pos < n && (text.[!pos] = '+' || text.[!pos] = '-') then incr pos;
      if !pos >= n || not (is_digit text.[!pos]) then error "invalid exponent";
      while !pos < n && is_digit text.[!pos] do incr pos done
    end;
    let raw = String.sub text start (!pos - start) in
    match float_of_string_opt raw with
    | Some value when classify_float value <> FP_nan && classify_float value <> FP_infinite -> Number value
    | _ -> error "non-finite number"
  in
  let rec value depth =
    if depth > max_depth then error "JSON nesting exceeds capacity";
    skip ();
    if !pos >= n then error "expected value";
    match text.[!pos] with
    | '{' ->
        incr pos;
        skip ();
        if !pos < n && text.[!pos] = '}' then begin incr pos; Object [] end
        else begin
          let fields = ref [] in
          let rec members () =
            skip ();
            if !pos >= n || text.[!pos] <> '"' then error "expected object key";
            let key = parse_string () in
            skip ();
            if !pos >= n || text.[!pos] <> ':' then error "expected colon";
            incr pos;
            let item = value (depth + 1) in
            fields := (key, item) :: !fields;
            skip ();
            if !pos < n && text.[!pos] = ',' then begin incr pos; members () end
            else if !pos < n && text.[!pos] = '}' then incr pos
            else error "expected object separator"
          in
          members ();
          Object (List.rev !fields)
        end
    | '[' ->
        incr pos;
        skip ();
        if !pos < n && text.[!pos] = ']' then begin incr pos; Array [] end
        else begin
          let items = ref [] in
          let rec elements () =
            items := value (depth + 1) :: !items;
            skip ();
            if !pos < n && text.[!pos] = ',' then begin incr pos; elements () end
            else if !pos < n && text.[!pos] = ']' then incr pos
            else error "expected array separator"
          in
          elements ();
          Array (List.rev !items)
        end
    | '"' -> String (parse_string ())
    | 't' ->
        if !pos + 3 < n && String.sub text !pos 4 = "true" then begin pos := !pos + 4; Bool true end
        else error "invalid literal"
    | 'f' ->
        if !pos + 4 < n && String.sub text !pos 5 = "false" then begin pos := !pos + 5; Bool false end
        else error "invalid literal"
    | 'n' ->
        if !pos + 3 < n && String.sub text !pos 4 = "null" then begin pos := !pos + 4; Null end
        else error "invalid literal"
    | '-' | '0' .. '9' -> parse_number ()
    | _ -> error "invalid value"
  in
  let result = value 0 in
  skip ();
  if !pos <> n then error "trailing JSON content";
  result

let encode_json value =
  let buffer = Buffer.create 64 in
  let quote value =
    match codepoint_count value with None -> raise (Json_error "invalid UTF-8 string") | Some _ -> ();
    Buffer.add_char buffer '"';
    String.iter (fun c ->
      match c with
      | '"' -> Buffer.add_string buffer "\\\""
      | '\\' -> Buffer.add_string buffer "\\\\"
      | '\b' -> Buffer.add_string buffer "\\b"
      | '\012' -> Buffer.add_string buffer "\\f"
      | '\n' -> Buffer.add_string buffer "\\n"
      | '\r' -> Buffer.add_string buffer "\\r"
      | '\t' -> Buffer.add_string buffer "\\t"
      | _ when Char.code c < 32 -> Buffer.add_string buffer (Printf.sprintf "\\u%04x" (Char.code c))
      | _ -> Buffer.add_char buffer c) value;
    Buffer.add_char buffer '"'
  in
  let rec render depth = function
    | _ when depth > max_depth -> raise (Json_error "JSON nesting exceeds capacity")
    | Object fields ->
        Buffer.add_char buffer '{';
        List.iteri (fun index (key, item) ->
          if index > 0 then Buffer.add_char buffer ',';
          quote key;
          Buffer.add_char buffer ':';
          render (depth + 1) item) fields;
        Buffer.add_char buffer '}'
    | Array items ->
        Buffer.add_char buffer '[';
        List.iteri (fun index item ->
          if index > 0 then Buffer.add_char buffer ',';
          render (depth + 1) item) items;
        Buffer.add_char buffer ']'
    | String value -> quote value
    | Number number ->
        begin match classify_float number with
        | FP_nan | FP_infinite -> raise (Json_error "non-finite number")
        | _ -> Buffer.add_string buffer (Printf.sprintf "%.17g" number)
        end
    | Bool true -> Buffer.add_string buffer "true"
    | Bool false -> Buffer.add_string buffer "false"
    | Null -> Buffer.add_string buffer "null"
  in
  render 0 value;
  let result = Buffer.contents buffer in
  if String.length result > max_json then raise (Json_error "JSON output exceeds capacity");
  result

let rec find_last_field key = function
  | [] -> None
  | (name, value) :: rest ->
      begin match find_last_field key rest with
      | Some _ as found -> found
      | None -> if name = key then Some value else None
      end

let field key = function Object fields -> find_last_field key fields | _ -> None
let field_string key object_value =
  match field key object_value with Some (String value) -> Some value | _ -> None
let field_number key object_value =
  match field key object_value with Some (Number value) -> Some value | _ -> None

let rec json_equal left right =
  match left, right with
  | Null, Null -> true
  | Bool a, Bool b -> a = b
  | String a, String b -> a = b
  | Number a, Number b -> a = b
  | Array a, Array b ->
      List.length a = List.length b && List.for_all2 json_equal a b
  | Object a, Object b ->
      List.length a = List.length b &&
      List.for_all (fun (key, value) -> match find_last_field key b with Some other -> json_equal value other | None -> false) a
  | _ -> false

let find_sub haystack needle start =
  let h = String.length haystack and n = String.length needle in
  let rec loop i =
    if i + n > h then None
    else if String.sub haystack i n = needle then Some i
    else loop (i + 1)
  in
  if n = 0 then Some start else loop start

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
  let n = String.length content in
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
  let n = String.length content in
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

type predicate =
  | Literal of char
  | Any
  | Digit
  | Word
  | Space
  | Class of bool * (char * char) list

let pattern_supported pattern =
  let n = String.length pattern in
  n >= 2 && pattern.[0] = '^' && pattern.[n - 1] = '$' &&
  let rec check i =
    if i >= n then true
    else
      let c = pattern.[i] in
      if Char.code c < 32 || Char.code c > 126 then false
      else if c = '(' || c = ')' || c = '{' || c = '}' || c = '|' then false
      else if c = '\\' && i + 1 < n && pattern.[i + 1] >= '1' && pattern.[i + 1] <= '9' then false
      else check (i + 1)
  in
  check 0

let compile_pattern pattern =
  let body = String.sub pattern 1 (String.length pattern - 2) in
  let n = String.length body in
  let rec atom i =
    if i >= n then raise (Schema_error "unsupported pattern")
    else match body.[i] with
    | '.' -> (Any, i + 1)
    | '\\' when i + 1 < n ->
        begin match body.[i + 1] with
        | 'd' -> (Digit, i + 2)
        | 'w' -> (Word, i + 2)
        | 's' -> (Space, i + 2)
        | c when List.mem c ['.'; '^'; '$'; '['; ']'; '('; ')'; '{'; '}'; '|'; '*'; '+'; '?'; '\\'; '-'] ->
            (Literal c, i + 2)
        | _ -> raise (Schema_error "unsupported pattern")
        end
    | '[' ->
        let negate = i + 1 < n && body.[i + 1] = '^' in
        let start = if negate then i + 2 else i + 1 in
        let rec ranges j acc =
          if j >= n then raise (Schema_error "unsupported pattern")
          else if body.[j] = ']' then (List.rev acc, j + 1)
          else if j + 2 < n && body.[j + 1] = '-' && body.[j + 2] <> ']' then
            if body.[j] > body.[j + 2] then raise (Schema_error "unsupported pattern")
            else ranges (j + 3) ((body.[j], body.[j + 2]) :: acc)
          else ranges (j + 1) ((body.[j], body.[j]) :: acc)
        in
        let ranges, next = ranges start [] in
        (Class (negate, ranges), next)
    | c when List.mem c ['('; ')'; '{'; '}'; '|'; '*'; '+'; '?'; '\\'] -> raise (Schema_error "unsupported pattern")
    | c -> (Literal c, i + 1)
  in
  let rec tokens i acc =
    if i >= n then List.rev acc
    else
      let predicate, next = atom i in
      let quantifier, next =
        if next < n && List.mem body.[next] ['*'; '+'; '?'] then (body.[next], next + 1)
        else ('1', next)
      in
      tokens next ((predicate, quantifier) :: acc)
  in
  tokens 0 []

let predicate_matches predicate c =
  match predicate with
  | Literal expected -> c = expected
  | Any -> c <> '\n'
  | Digit -> c >= '0' && c <= '9'
  | Word -> (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || is_digit c || c = '_'
  | Space -> is_space c
  | Class (negate, ranges) ->
      let found = List.exists (fun (low, high) -> c >= low && c <= high) ranges in
      found <> negate

let pattern_matches pattern input =
  if not (pattern_supported pattern) then raise (Schema_error "unsupported pattern");
  if String.length input > 4096 then raise (Schema_error "pattern input exceeds limit");
  let tokens = compile_pattern pattern in
  let unique values = List.sort_uniq compare values in
  let one predicate position =
    if position < String.length input && predicate_matches predicate input.[position]
    then [position + 1] else []
  in
  let closure predicate start =
    let rec loop position acc =
      let next = one predicate position in
      match next with
      | [] -> List.rev acc
      | [next] when next > position && not (List.mem next acc) -> loop next (next :: acc)
      | _ -> List.rev acc
    in
    loop start (start :: [])
  in
  let step predicate quantifier positions =
    List.concat_map (fun position ->
      match quantifier with
      | '1' -> one predicate position
      | '?' -> position :: one predicate position
      | '*' -> closure predicate position
      | '+' -> List.filter (fun p -> p > position) (closure predicate position)
      | _ -> raise (Schema_error "unsupported pattern")) positions
    |> unique
  in
  let positions = List.fold_left (fun positions (predicate, quantifier) -> step predicate quantifier positions) [0] tokens in
  List.mem (String.length input) positions

let add_path paths path = paths @ [path]

let rec check_schema_shape schema depth =
  if depth > max_depth then raise (Schema_error "schema nesting exceeds capacity");
  match schema with
  | Object fields ->
      begin match find_last_field "type" fields with
      | None -> ()
      | Some (String kind) when List.mem kind [""; "object"; "array"; "string"; "number"; "integer"; "boolean"] -> ()
      | _ -> raise (Schema_error "invalid schema type")
      end;
      begin match find_last_field "properties" fields with
      | None -> ()
      | Some (Object properties) -> List.iter (fun (_, value) -> check_schema_shape value (depth + 1)) properties
      | _ -> raise (Schema_error "invalid properties")
      end;
      begin match find_last_field "items" fields with
      | None -> ()
      | Some value -> check_schema_shape value (depth + 1)
      end;
      begin match find_last_field "required" fields with
      | None -> ()
      | Some (Array values) ->
          if not (List.for_all (function String _ -> true | _ -> false) values) then
            raise (Schema_error "invalid required")
      | _ -> raise (Schema_error "invalid required")
      end;
      begin match find_last_field "enum" fields with
      | None | Some (Array _) -> ()
      | _ -> raise (Schema_error "invalid enum")
      end;
      List.iter (fun name ->
        match find_last_field name fields with
        | None -> ()
        | Some (Number value) when Float.is_integer value && value >= 0.0 -> ()
        | _ -> raise (Schema_error "invalid length")) ["minLength"; "maxLength"];
      List.iter (fun name ->
        match find_last_field name fields with
        | None | Some (Number _) -> ()
        | _ -> raise (Schema_error "invalid bound")) ["minimum"; "maximum"];
      begin match find_last_field "pattern" fields with
      | None -> ()
      | Some (String pattern) -> if not (pattern_supported pattern) then raise (Schema_error "unsupported pattern")
      | _ -> raise (Schema_error "invalid pattern")
      end;
      begin match find_last_field "description" fields with
      | None | Some (String _) -> ()
      | _ -> raise (Schema_error "invalid description")
      end
  | _ -> raise (Schema_error "schema must be an object")

let rec validate_node schema data path depth =
  if depth > max_depth then raise (Schema_error "schema nesting exceeds capacity");
  match schema with
  | Object fields ->
      begin match data with
      | Null ->
          begin match find_last_field "type" fields with
          | Some (String kind) when kind <> "" -> [path]
          | _ -> []
          end
      | _ ->
          let kind = match find_last_field "type" fields with Some (String kind) -> kind | _ -> "" in
          if kind = "" then []
          else if kind = "object" then
            begin match data with
            | Object values ->
                let required_errors =
                  match find_last_field "required" fields with
                  | Some (Array names) ->
                      List.filter_map (function
                        | String name -> if find_last_field name values = None then Some (path ^ "." ^ name) else None
                        | _ -> None) names
                  | _ -> []
                in
                let property_errors =
                  match find_last_field "properties" fields with
                  | Some (Object properties) ->
                      List.concat_map (fun (name, property_schema) ->
                        match find_last_field name values with
                        | Some value -> validate_node property_schema value (path ^ "." ^ name) (depth + 1)
                        | None -> []) properties
                  | _ -> []
                in
                required_errors @ property_errors
            | _ -> [path]
            end
          else if kind = "array" then
            begin match data with
            | Array values ->
                begin match find_last_field "items" fields with
                | Some item_schema ->
                    List.concat (List.mapi (fun index value -> validate_node item_schema value (Printf.sprintf "%s[%d]" path index) (depth + 1)) values)
                | None -> []
                end
            | _ -> [path]
            end
          else if kind = "string" then
            begin match data with
            | String value ->
                let length = match codepoint_count value with Some count -> count | None -> raise (Schema_error "invalid UTF-8 data") in
                let bounds =
                  let check name condition =
                    match find_last_field name fields with
                    | Some (Number limit) when limit > 0.0 && condition (float_of_int length) limit -> [path]
                    | _ -> []
                  in
                  check "minLength" (fun actual limit -> actual < limit) @
                  check "maxLength" (fun actual limit -> actual > limit)
                in
                let pattern =
                  match find_last_field "pattern" fields with
                  | Some (String pattern) -> if pattern_matches pattern value then [] else [path]
                  | _ -> []
                in
                let enum =
                  match find_last_field "enum" fields with
                  | Some (Array choices) -> if List.exists (fun choice -> json_equal choice data) choices then [] else [path]
                  | _ -> []
                in
                bounds @ pattern @ enum
            | _ -> [path]
            end
          else if kind = "number" || kind = "integer" then
            begin match data with
            | Number number when kind = "integer" && not (Float.is_integer number) -> [path]
            | Number number ->
                let enum =
                  match find_last_field "enum" fields with
                  | Some (Array choices) -> if List.exists (fun choice -> json_equal choice data) choices then [] else [path]
                  | _ -> []
                in
                let minimum =
                  match find_last_field "minimum" fields with
                  | Some (Number limit) when limit <> 0.0 && number < limit -> [path]
                  | _ -> []
                in
                let maximum =
                  match find_last_field "maximum" fields with
                  | Some (Number limit) when limit <> 0.0 && number > limit -> [path]
                  | _ -> []
                in
                enum @ minimum @ maximum
            | _ -> [path]
            end
          else if kind = "boolean" then
            begin match data with
            | Bool _ ->
                begin match find_last_field "enum" fields with
                | Some (Array choices) -> if List.exists (fun choice -> json_equal choice data) choices then [] else [path]
                | _ -> []
                end
            | _ -> [path]
            end
          else [path]
      end
  | _ -> raise (Schema_error "schema must be an object")

let validate_schema schema data =
  check_schema_shape schema 0;
  validate_node schema data "$" 0

let valid_env_name value =
  let n = String.length value in
  n > 0 &&
  let first = value.[0] in
  ((first >= 'A' && first <= 'Z') || (first >= 'a' && first <= 'z') || first = '_') &&
  String.for_all (fun c ->
    (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || is_digit c || c = '_') value

let relative_path value =
  let n = String.length value in
  n > 0 && value.[0] <> '/' && value.[0] <> '\\' &&
  not (n >= 2 && value.[1] = ':') &&
  let normalized = String.map (fun c -> if c = '\\' then '/' else c) value in
  not (List.exists (fun part -> part = "..") (String.split_on_char '/' normalized))

let has_only_fields fields allowed =
  List.for_all (fun (name, _) -> List.mem name allowed) fields &&
  let names = List.map fst fields in
  List.length names = List.length (List.sort_uniq compare names)

let reverse_dns value =
  let labels = String.split_on_char '.' value in
  List.length labels >= 2 && List.for_all (fun label ->
    let n = String.length label in
    n > 0 && label.[0] <> '-' && label.[n - 1] <> '-' &&
    String.for_all (fun c -> (c >= 'a' && c <= 'z') || is_digit c || c = '-') label) labels

let semver value =
  let valid_identifier text =
    text <> "" && String.for_all (fun c ->
      (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || is_digit c || c = '.' || c = '-') text
  in
  let base, metadata =
    match String.index_opt value '+' with
    | Some index -> (String.sub value 0 index, Some (String.sub value (index + 1) (String.length value - index - 1)))
    | None -> (value, None)
  in
  let main, prerelease =
    match String.index_opt base '-' with
    | Some index -> (String.sub base 0 index, Some (String.sub base (index + 1) (String.length base - index - 1)))
    | None -> (base, None)
  in
  let numbers = String.split_on_char '.' main in
  List.length numbers = 3 &&
  List.for_all (fun part ->
    part <> "" && String.for_all is_digit part &&
    (part = "0" || part.[0] <> '0')) numbers &&
  (match prerelease with None -> true | Some text -> valid_identifier text) &&
  (match metadata with None -> true | Some text -> valid_identifier text)

let validate_manifest raw =
  let schema_fields = ["schemaVersion"; "id"; "version"; "kind"; "entrypoint"; "protocol"; "capabilities"; "permissions"; "limits"; "health"; "isolation"; "signature"; "sbom"] in
  let required_fields = ["schemaVersion"; "id"; "version"; "kind"; "entrypoint"; "protocol"; "capabilities"; "permissions"; "limits"; "health"; "isolation"] in
  try
    match parse_json raw with
    | Object fields ->
        if not (has_only_fields fields schema_fields) then None
        else if not (List.for_all (fun name -> find_last_field name fields <> None) required_fields) then None
        else if not (match find_last_field "schemaVersion" fields with Some (Number value) -> value = 1.0 | _ -> false) then None
        else match field_string "id" (Object fields), field_string "version" (Object fields), field_string "kind" (Object fields), field_string "protocol" (Object fields) with
        | Some id, Some version, Some kind, Some protocol ->
            if not (reverse_dns id) || not (semver version) ||
               not (List.mem kind ["tool.provider.v1"; "model.provider.v1"; "policy.provider.v1"; "memory.provider.v1"; "sandbox.provider.v1"]) ||
               protocol <> "jsonrpc-2" then None
            else match find_last_field "entrypoint" fields with
            | Some (Object entry) ->
                if not (has_only_fields entry ["type"; "command"; "module"; "image"; "args"; "dir"]) then None
                else match field_string "type" (Object entry) with
                | Some entry_type when List.mem entry_type ["process"; "wasm"; "container"] ->
                    let target = match entry_type with "process" -> "command" | "wasm" -> "module" | _ -> "image" in
                    if not (match field_string target (Object entry) with Some value -> value <> "" | None -> false) then None
                    else if not (List.for_all (fun name -> match find_last_field name entry with None | Some (String _) -> true | _ -> false) ["command"; "module"; "image"; "dir"]) then None
                    else if not (match find_last_field "args" entry with None -> true | Some (Array values) -> List.for_all (function String _ -> true | _ -> false) values | _ -> false) then None
                    else if not (match field_string "isolation" (Object fields) with Some isolation -> isolation = entry_type | None -> false) then None
                    else match find_last_field "capabilities" fields with
                    | Some (Array capabilities) ->
                        let names = List.filter_map (function String name -> Some name | _ -> None) capabilities in
                        if List.length names <> List.length capabilities || List.exists ((=) "") names || List.length names <> List.length (List.sort_uniq compare names) then None
                        else match find_last_field "permissions" fields with
                        | Some (Object permissions) ->
                            if not (has_only_fields permissions ["filesystem"; "network"; "env"]) then None
                            else if not (match find_last_field "filesystem" permissions with
                              | None -> true
                              | Some (Array items) -> List.for_all (function
                                  | Object item -> has_only_fields item ["path"; "mode"] &&
                                      (match field_string "path" (Object item), field_string "mode" (Object item) with
                                       | Some path, Some mode -> relative_path path && List.mem mode ["read"; "write"; "readwrite"]
                                       | _ -> false)
                                  | _ -> false) items
                              | _ -> false) then None
                            else if not (match find_last_field "network" permissions with
                              | None -> true
                              | Some (Array items) -> List.for_all (function
                                  | Object item -> has_only_fields item ["host"; "port"] &&
                                      (match field_string "host" (Object item), field_number "port" (Object item) with
                                       | Some host, Some port -> host <> "" && Float.is_integer port && port >= 1.0 && port <= 65535.0
                                       | _ -> false)
                                  | _ -> false) items
                              | _ -> false) then None
                            else if not (match find_last_field "env" permissions with
                              | None -> true
                              | Some (Array items) -> List.for_all (function String name -> valid_env_name name | _ -> false) items
                              | _ -> false) then None
                            else match find_last_field "limits" fields with
                            | Some (Object limits) ->
                                if not (has_only_fields limits ["memoryMB"; "cpuMillis"; "timeoutMs"; "maxInflight"]) then None
                                else if not (List.for_all (fun name -> match find_last_field name limits with None -> true | Some (Number value) -> Float.is_integer value && value >= 0.0 | _ -> false) ["memoryMB"; "cpuMillis"; "timeoutMs"; "maxInflight"]) then None
                                else match find_last_field "health" fields with
                                | Some (Object health) ->
                                    if not (has_only_fields health ["method"; "intervalMs"]) then None
                                    else
                                      let method_value = match find_last_field "method" health with Some (String value) -> Some value | _ -> None in
                                      let interval = match find_last_field "intervalMs" health with Some (Number value) -> Some value | _ -> None in
                                      if (match interval with Some value -> value < 0.0 || not (Float.is_integer value) | None -> false) then None
                                      else if (match interval, method_value with Some value, _ when value > 0.0 -> method_value = None | _ -> false) then None
                                      else if not (match find_last_field "signature" fields with
                                        | None -> true
                                        | Some (Object signature) -> has_only_fields signature ["algorithm"; "keyId"] &&
                                            (match field_string "algorithm" (Object signature), field_string "keyId" (Object signature) with Some algorithm, Some key -> algorithm <> "" && key <> "" | _ -> false)
                                        | _ -> false) then None
                                      else if not (match find_last_field "sbom" fields with
                                        | None -> true
                                        | Some (String path) -> path = "" || relative_path path
                                        | _ -> false) then None
                                      else Some (Object fields)
                                | _ -> None
                            | _ -> None
                        | _ -> None
                    | _ -> None
                | _ -> None
            | _ -> None
        | _ -> None
    | _ -> None
  with _ -> None
type content_block = {
  block_type : string;
  block_text : string option;
  block_image_url : string option;
  block_data : string option;
}

type tool_invocation = {
  invocation_id : string;
  invocation_name : string;
  invocation_arguments : json;
}

type core_message = {
  message_role : string;
  message_content : string;
  message_blocks : content_block list;
  message_calls : tool_invocation list;
  message_tool_id : string option;
}

type core_tool_spec = { spec_name : string; spec_description : string }
type usage = { input_tokens : int; output_tokens : int }
type request = { request_messages : core_message list; request_tools : core_tool_spec list }
type response = { response_message : core_message; response_usage : usage }
type session = { session_id : string; session_messages : core_message list }
type run_result = {
  result_run_id : string;
  result_output : string;
  result_steps : int;
  result_usage : usage;
}
type memory_record = {
  record_id : string;
  record_frame : string;
  record_content : string;
  record_created_at : string option;
}
type path_grant = { grant_root : string; grant_access : string }
type decision = { decision_allowed : bool; decision_reason : string }
type core_event = {
  event_type : string;
  event_session_id : string;
  event_run_id : string option;
  event_data : json;
}
type context_budget = { budget_max_tokens : int; budget_keep_recent : int }
type sink = core_event -> unit
type memory_store = {
  records : (string, memory_record list ref) Hashtbl.t;
  mutable sequence : int;
}
type checkpoint_allowlist = (string, unit) Hashtbl.t
type path_checker = path_grant list
type call_limit = {
  model_limit : int;
  tool_limit : int;
  mutable models_called : int;
  mutable tools_called : int;
}
type tool_selection = string list
type structured_output = {
  output_schema : json;
  max_repairs : int;
  repairer : (string -> string) option;
}
type tool = {
  tool_name : string;
  tool_description : string;
  tool_invoke : json -> json;
}
type model = { generate : request -> response }
type agent_options = {
  agent_model : model;
  agent_tools : tool list;
  agent_tool_selection : tool_selection option;
  agent_pii : bool;
  agent_structured_output : structured_output option;
  agent_call_limit : call_limit option;
  agent_events : sink option;
  agent_system_prompt : string;
  agent_max_steps : int;
  agent_max_tokens : int;
  agent_session_id : string;
}

exception Core_error of string * string

let raise_core code message = raise (Core_error (code, message))

let error_code = function Core_error (code, _) -> code | _ -> ""

let field_bool key object_value =
  match field key object_value with Some (Bool value) -> Some value | _ -> None

let field_array key object_value =
  match field key object_value with Some (Array values) -> values | _ -> []

let field_object key object_value =
  match field key object_value with Some (Object fields) -> Some (Object fields) | _ -> None

let json_text value = encode_json value

let starts_with prefix text =
  let n = String.length prefix in
  String.length text >= n && String.sub text 0 n = prefix

let ends_with suffix text =
  let n = String.length suffix and m = String.length text in
  m >= n && String.sub text (m - n) n = suffix

let content_block_make kind text = {
  block_type = kind;
  block_text = text;
  block_image_url = None;
  block_data = None;
}

let tool_invocation_make id name arguments = {
  invocation_id = id;
  invocation_name = name;
  invocation_arguments = arguments;
}

let text_message role content = {
  message_role = role;
  message_content = content;
  message_blocks = [];
  message_calls = [];
  message_tool_id = None;
}

let assistant_message content calls = {
  message_role = "assistant";
  message_content = content;
  message_blocks = [];
  message_calls = calls;
  message_tool_id = None;
}

let tool_message content tool_id = {
  message_role = "tool";
  message_content = content;
  message_blocks = [];
  message_calls = [];
  message_tool_id = Some tool_id;
}

let tool_spec_make name description = { spec_name = name; spec_description = description }
let usage_make input_tokens output_tokens = { input_tokens; output_tokens }
let usage_add left right = usage_make
  (left.input_tokens + right.input_tokens)
  (left.output_tokens + right.output_tokens)

let request_make messages tools = { request_messages = messages; request_tools = tools }
let response_make message usage_value = { response_message = message; response_usage = usage_value }
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

let path_within root target = root = target || starts_with (root ^ "/") target

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

let is_email_local character =
  (character >= 'a' && character <= 'z') || (character >= 'A' && character <= 'Z') ||
  (character >= '0' && character <= '9') || List.mem character ['.'; '_'; '%'; '+'; '-']

let is_domain_character character =
  (character >= 'a' && character <= 'z') || (character >= 'A' && character <= 'Z') ||
  (character >= '0' && character <= '9') || List.mem character ['.'; '-']

let is_alpha character = (character >= 'a' && character <= 'z') || (character >= 'A' && character <= 'Z')
let is_digit_char character = character >= '0' && character <= '9'

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
    else if i + 11 <= String.length first && is_digit_char first.[i] && is_digit_char first.[i+1] &&
            is_digit_char first.[i+2] && first.[i+3] = '-' && is_digit_char first.[i+4] &&
            is_digit_char first.[i+5] && first.[i+6] = '-' && is_digit_char first.[i+7] &&
            is_digit_char first.[i+8] && is_digit_char first.[i+9] && is_digit_char first.[i+10] then begin
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
        if !index >= String.length second || not (is_digit_char second.[!index]) then valid := false
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
  { generate = fun _ ->
      if !index >= List.length responses then raise_core "MODEL_ERROR" "script exhausted";
      let response = List.nth responses !index in
      incr index;
      response }

let static_model content = {
  generate = fun _ -> response_make (assistant_message content []) (usage_make 0 0);
}

let failing_model () = {
  generate = fun _ -> raise_core "MODEL_ERROR" "primary model failed";
}

let fallback_model primary fallback = {
  generate = fun request -> try primary.generate request with _ -> fallback.generate request;
}

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
  try
    emit_event "run.started" Null;
    let total = ref (usage_make 0 0) in
    let step = ref 0 in
    let result = ref None in
    while !result = None do
      if !step >= max_steps then raise_core "AGENT_MAX_STEPS" "maximum steps exceeded";
      incr step;
      let specs =
        let specs = List.map (fun tool -> tool_spec_make tool.tool_name tool.tool_description) options.agent_tools in
        match options.agent_tool_selection with
        | None -> specs
        | Some selection -> select_tools selection specs
      in
      (match options.agent_call_limit with Some limit -> call_limit_model limit | None -> ());
      let request_messages = if options.agent_pii then List.map redact_message !messages else !messages in
      let response = options.agent_model.generate (request_make request_messages specs) in
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
      end else
        List.iter (fun call ->
          (match options.agent_tool_selection with
           | None -> ()
           | Some selection -> check_tool_selected selection call.invocation_name);
          match find_tool options.agent_tools call.invocation_name with
          | None -> raise_core "TOOL_NOT_FOUND" ("tool not found: " ^ call.invocation_name)
          | Some tool ->
              (match options.agent_call_limit with Some limit -> call_limit_tool limit | None -> ());
              emit_event "tool.call" (Object [
                ("name", String call.invocation_name);
                ("arguments", call.invocation_arguments)]);
              let value = tool.tool_invoke call.invocation_arguments in
              let value = if options.agent_pii then redact_value value else value in
              messages := !messages @ [tool_message (encode_json value) call.invocation_id]
        ) response.response_message.message_calls
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
