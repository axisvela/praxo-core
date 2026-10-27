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
let sdk_version = "0.1.0"
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
