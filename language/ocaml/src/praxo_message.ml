open Praxo_types
open Praxo_json
let field_bool key object_value =
  match field key object_value with Some (Bool value) -> Some value | _ -> None

let field_array key object_value =
  match field key object_value with Some (Array values) -> values | _ -> []

let field_object key object_value =
  match field key object_value with Some (Object fields) -> Some (Object fields) | _ -> None

let json_text value = encode_json value

let starts_with prefix text = String.starts_with ~prefix text
let ends_with suffix text = String.ends_with ~suffix text

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

let assistant_message content calls =
  { (text_message "assistant" content) with message_calls = calls }

let tool_message content tool_id =
  { (text_message "tool" content) with message_tool_id = Some tool_id }

let tool_spec_make name description = { spec_name = name; spec_description = description }
let usage_make input_tokens output_tokens = { input_tokens; output_tokens }
let usage_add left right = usage_make
  (left.input_tokens + right.input_tokens)
  (left.output_tokens + right.output_tokens)

let request_make messages tools = { request_messages = messages; request_tools = tools }
let response_make message usage_value = { response_message = message; response_usage = usage_value }

