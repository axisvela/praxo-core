open Praxo_types
open Praxo_json
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
  let atom i =
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

