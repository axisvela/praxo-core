open Praxo_types
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
      let keys =
        List.sort_uniq compare
          (List.map fst a @ List.map fst b) in
      List.for_all (fun key ->
        match find_last_field key a, find_last_field key b with
        | Some left, Some right -> json_equal left right
        | None, None -> true
        | _ -> false) keys
  | _ -> false

let find_sub haystack needle start =
  let h = String.length haystack and n = String.length needle in
  let rec loop i =
    if i + n > h then None
    else if String.sub haystack i n = needle then Some i
    else loop (i + 1)
  in
  if n = 0 then Some start else loop start

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

