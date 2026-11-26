open Praxo_types
open Praxo_json
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
  with _ -> None
[@@warning "-8-11"]

