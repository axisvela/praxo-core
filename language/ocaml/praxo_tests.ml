let read_file path =
  let channel = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in channel)
    (fun () -> really_input_string channel (in_channel_length channel))

let fail message = raise (Failure message)

let check condition message = if not condition then fail message

let field name = function
  | Praxo.Object fields ->
      let rec last = function
        | [] -> None
        | (key, value) :: rest ->
            begin match last rest with
            | Some _ as found -> found
            | None -> if key = name then Some value else None
            end
      in
      last fields
  | _ -> None

let string_field name value =
  match field name value with Some (Praxo.String text) -> text | _ -> fail ("missing string " ^ name)

let bool_field name value =
  match field name value with Some (Praxo.Bool flag) -> flag | _ -> fail ("missing bool " ^ name)

let array_field name value =
  match field name value with Some (Praxo.Array items) -> items | _ -> fail ("missing array " ^ name)

let path_set paths = List.sort_uniq compare paths

let test_json () =
  let node = Praxo.parse_json "{\"a\":[true,false,null,{\"b\":\"x\"}],\"n\":1.5}" in
  check (Praxo.encode_json node <> "") "encode";
  check (match Praxo.parse_json "\"\\u00e9\\ud83d\\ude00\"" with
    | Praxo.String value -> String.length value = 6
    | _ -> false) "unicode";
  (try ignore (Praxo.parse_json ""); fail "empty accepted" with Praxo.Json_error _ -> ());
  (try ignore (Praxo.parse_json "{} {}"); fail "trailing accepted" with Praxo.Json_error _ -> ());
  (try ignore (Praxo.parse_json (String.make 66 '[' ^ "0" ^ String.make 66 ']')); fail "depth accepted" with Praxo.Json_error _ -> ());
  (try ignore (Praxo.parse_json (String.make 1048577 ' ')); fail "capacity accepted" with Praxo.Json_error _ -> ());
  print_endline "test_json passed"

let test_toolcall root =
  let document = Praxo.parse_json (read_file (Filename.concat root "vectors/toolcall.json")) in
  let vectors = array_field "vectors" document in
  List.iter (fun vector ->
    let input = match field "input" vector with Some value -> value | None -> fail "input" in
    let expect = match field "expect" vector with Some value -> value | None -> fail "expect" in
    let content = string_field "content" input in
    let operation = string_field "operation" input in
    if operation = "strip" then
      let stripped = Praxo.strip_tool_call_markup content in check (stripped = string_field "text" expect) ("strip vector: " ^ stripped)
    else begin
      match Praxo.parse_tool_call content with
      | None -> check (field "nil" expect = Some (Praxo.Bool true)) "expected no call"
      | Some call ->
          check (field "nil" expect <> Some (Praxo.Bool true)) "unexpected call";
          check (call.Praxo.name = string_field "name" expect) "call name";
          check (Praxo.json_equal call.Praxo.input (match field "input" expect with Some value -> value | None -> fail "expected input")) "call input"
    end) vectors;
  (match Praxo.parse_tool_call "<a.one>{}</a.one><b.two>{bad}</b.two>" with None -> () | Some _ -> fail "invalid final block");
  (match Praxo.parse_tool_call "{\"name\":\"x\",\"input\":{},\"risk\":42}" with None -> () | Some _ -> fail "typed metadata");
  check (Praxo.strip_tool_call_markup "x.y {}" = "x.y {}") "strip preserves plain";
  (match Praxo.parse_tool_call "echo {}" with None -> () | Some _ -> fail "plain dotted");
  check (Praxo.strip_tool_call_markup "a<tool_call name=\"x\">unfinished" = "a") "unfinished block";
  print_endline "test_toolcall passed"

let test_schema root =
  let document = Praxo.parse_json (read_file (Filename.concat root "vectors/jsonschema.json")) in
  let vectors = array_field "vectors" document in
  List.iter (fun vector ->
    let input = match field "input" vector with Some value -> value | None -> fail "input" in
    let expect = match field "expect" vector with Some value -> value | None -> fail "expect" in
    let schema = match field "schema" input with Some value -> value | None -> fail "schema" in
    let data = match field "data" input with Some value -> value | None -> fail "data" in
    let paths = Praxo.validate_schema schema data in
    let valid = bool_field "valid" expect in
    check ((paths = []) = valid) "schema validity";
    if not valid then
      let expected = array_field "errorPaths" expect in
      let expected = List.map (function Praxo.String value -> value | _ -> fail "path") expected in
      check (path_set paths = path_set expected) "schema paths") vectors;
  let schema = Praxo.parse_json "{\"type\":\"string\",\"pattern\":\"^a+$\"}" in
  let data = Praxo.parse_json "\"a\\n\"" in
  check (Praxo.validate_schema schema data = ["$"]) "pattern newline";
  (try ignore (Praxo.validate_schema (Praxo.parse_json "{\"pattern\":\"(a)\"}") (Praxo.parse_json "\"a\"")); fail "unsupported pattern accepted" with Praxo.Schema_error _ -> ());
  print_endline "test_schema passed"

let test_manifest root =
  let document = Praxo.parse_json (read_file (Filename.concat root "vectors/plugin.json")) in
  let vectors = array_field "vectors" document in
  List.iter (fun vector ->
    let input = match field "input" vector with Some value -> value | None -> fail "input" in
    let expect = match field "expect" vector with Some value -> value | None -> fail "expect" in
    let raw = match field "raw" input with
      | Some (Praxo.String value) -> value
      | _ -> Praxo.encode_json (match field "manifest" input with Some value -> value | None -> fail "manifest")
    in
    match Praxo.validate_manifest raw with
    | None -> check (not (bool_field "valid" expect)) "unexpected invalid manifest"
    | Some manifest ->
        check (bool_field "valid" expect) "unexpected valid manifest";
        (match field "id" expect with Some (Praxo.String id) -> check (string_field "id" manifest = id) "manifest id" | _ -> ());
        (match field "kind" expect with Some (Praxo.String kind) -> check (string_field "kind" manifest = kind) "manifest kind" | _ -> ())) vectors;
  check (Praxo.validate_manifest "{} {}" = None) "trailing manifest";
  check (Praxo.validate_manifest "" = None) "empty manifest";
  print_endline "test_manifest passed"

let () =
  let root = if Array.length Sys.argv > 1 then Sys.argv.(1) else "../../spec" in
  test_json ();
  test_toolcall root;
  test_schema root;
  test_manifest root;
  print_endline "All declared OCaml wire vector groups passed"
