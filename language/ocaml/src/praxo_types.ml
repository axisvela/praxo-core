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
let sdk_version = "0.11.1"

let stream_kinds = ["values"; "updates"; "messages"; "tasks"; "debug"; "checkpoint"]
let max_json = 1048576
let max_tool = 262144
let max_depth = 64

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
type model = {
  generate : request -> response;
  generate_stream : (request -> (string -> unit) -> response) option;
}
type http_request = {
  http_method : string;
  http_url : string;
  http_headers : (string * string) list;
  http_payload : string;
}
type http_response = {
  http_status : int;
  http_body : string;
}
type transport = http_request -> http_response
type harmovela_config = {
  harmovela_base_url : string;
  harmovela_source : string;
  harmovela_spec_version : string;
  harmovela_clock : unit -> int;
  harmovela_transport : transport;
}
type openai_config = {
  openai_base_url : string;
  openai_model : string;
  openai_api_key : string option;
  openai_tool_choice : string option;
}
type anthropic_config = {
  anthropic_base_url : string;
  anthropic_model : string;
  anthropic_api_key : string;
  anthropic_version : string;
  anthropic_max_tokens : int;
  anthropic_tool_choice : string option;
}
type gemini_config = {
  gemini_base_url : string;
  gemini_model : string;
  gemini_api_key : string;
  gemini_max_output_tokens : int;
  gemini_tool_choice : string option;
}
type agent_action = {
  action_kind : string;
  action_session_id : string;
  action_tool_name : string;
  action_arguments : json;
}
type policy_hook = agent_action -> decision
type interrupt = {
  interrupt_run_id : string;
  interrupt_session_id : string;
  interrupt_call : tool_invocation;
}
type interrupt_decision = {
  interrupt_action : string;
  interrupt_arguments : json option;
  interrupt_response : string;
  interrupt_reason : string;
}
type interrupt_handler = interrupt -> interrupt_decision
type interrupt_approval = interrupt -> bool
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
  agent_policy : (string -> bool) option;
  agent_action_policy : policy_hook option;
  agent_allowed_tools : string list;
  agent_interrupt_on : string list;
  agent_on_interrupt_decision : interrupt_handler option;
  agent_on_interrupt : interrupt_approval option;
  agent_on_delta : (string -> unit) option;
  agent_require_policy : bool;
  agent_require_tool_scope : bool;
}
type mcp_transport = string -> json -> json
type mcp_client = {
  mcp_transport : mcp_transport;
  mcp_client_version : string;
  mutable mcp_protocol_version : string;
  mutable mcp_server_info : json;
  mutable mcp_closed : bool;
}
type otel_transport = string -> string -> string -> string -> int * string
type otel_sink = {
  otel_endpoint : string;
  otel_service_name : string;
  otel_allowed_data_keys : string list;
  otel_clock : unit -> int;
  otel_transport : otel_transport;
}
type document = {
  document_id : string;
  document_content : string;
  document_metadata : (string * string) list;
  document_score : float;
}
type retriever = string -> int -> document list
type subagent_request = {
  request_parent_session_id : string;
  request_agent_id : string;
  request_prompt : string;
  request_mode : string;
}
type subagent_result = {
  result_task_id : string;
  result_agent_id : string;
  result_output : string;
}
type subagent_task = {
  task_id : string;
  task_parent_session_id : string;
  task_agent_id : string;
  task_mode : string;
  task_status : string;
  task_output : string;
  task_error : string;
  task_created_at : string;
  task_updated_at : string;
}
type subagent_runner = subagent_request -> subagent_result

exception Core_error of string * string

let raise_core code message = raise (Core_error (code, message))

let error_code = function Core_error (code, _) -> code | _ -> ""

