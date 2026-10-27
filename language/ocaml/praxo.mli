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

val spec_version : string
val sdk_version : string
val parse_json : string -> json
val encode_json : json -> string
val json_equal : json -> json -> bool
val parse_tool_call : string -> call option
val strip_tool_call_markup : string -> string
val validate_schema : json -> json -> string list
val validate_manifest : string -> json option
