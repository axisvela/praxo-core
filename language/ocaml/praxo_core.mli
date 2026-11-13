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
val stream_kinds : string list
val parse_json : string -> json
val encode_json : json -> string
val json_equal : json -> json -> bool
val parse_tool_call : string -> call option
val parse_input_json : string -> json option
val strip_tool_call_markup : string -> string
val validate_schema : json -> json -> string list
val validate_manifest : string -> json option

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

val raise_core : string -> string -> 'a
val error_code : exn -> string
val field_bool : string -> json -> bool option
val field_array : string -> json -> json list
val field_object : string -> json -> json option
val json_text : json -> string
val starts_with : string -> string -> bool
val ends_with : string -> string -> bool
val content_block_make : string -> string option -> content_block
val tool_invocation_make : string -> string -> json -> tool_invocation
val text_message : string -> string -> core_message
val assistant_message : string -> tool_invocation list -> core_message
val tool_message : string -> string -> core_message
val tool_spec_make : string -> string -> core_tool_spec
val usage_make : int -> int -> usage
val usage_add : usage -> usage -> usage
val request_make : core_message list -> core_tool_spec list -> request
val response_make : core_message -> usage -> response
val openai_request : openai_config -> request -> http_request
val openai_parse_response : string -> response
val openai_generate : openai_config -> transport -> request -> response
val openai_model : openai_config -> transport -> model
val anthropic_request : anthropic_config -> request -> http_request
val anthropic_parse_response : string -> response
val anthropic_generate : anthropic_config -> transport -> request -> response
val anthropic_model : anthropic_config -> transport -> model
val gemini_request : gemini_config -> request -> http_request
val gemini_parse_response : string -> response
val gemini_generate : gemini_config -> transport -> request -> response
val gemini_model : gemini_config -> transport -> model
val harmovela_config : string -> transport -> (unit -> int) -> harmovela_config
val format_harmovela_timestamp : int -> string
val harmovela_envelope : harmovela_config -> core_event -> int -> json
val harmovela_emit : harmovela_config -> core_event -> unit
val harmovela_sink : harmovela_config -> sink
val session_make : string -> core_message list -> session
val run_result_make : string -> string -> int -> usage -> run_result
val memory_record_make : string -> string -> string -> string option -> memory_record
val path_grant_make : string -> string -> path_grant
val decision_make : bool -> string -> decision
val event_make : string -> string -> string option -> json -> core_event
val context_budget_make : int -> int -> context_budget
val message_wire : core_message -> json
val emit : sink -> core_event -> unit
val multi_sink : sink list -> sink
val filter_sink : sink -> string list -> sink
val memory_store : unit -> memory_store
val memory_put : memory_store -> string -> memory_record -> memory_record
val memory_search : memory_store -> string -> string -> int -> memory_record list
val checkpoint_allowlist : unit -> checkpoint_allowlist
val checkpoint_register : checkpoint_allowlist -> string -> unit
val checkpoint_marshal : checkpoint_allowlist -> string -> json -> string
val checkpoint_unmarshal : checkpoint_allowlist -> string -> json
val normalize_path : string -> string
val path_checker : path_grant list -> path_checker
val path_check : path_checker -> string -> string -> decision
val path_allowed : path_checker -> string -> string -> bool
val estimate_tokens : core_message list -> int
val truncate_to_tokens : string -> int -> string
val compact_context : context_budget -> core_message list -> core_message list * bool
val pii_redact : string -> string
val redact_value : json -> json
val extract_json : string -> json option
val structured_output : json -> int -> (string -> string) option -> structured_output
val structured_apply : structured_output -> string -> string option * string
val call_limit : int -> int -> call_limit
val call_limit_model : call_limit -> unit
val call_limit_tool : call_limit -> unit
val tool_selection : string list -> tool_selection
val select_tools : tool_selection -> core_tool_spec list -> core_tool_spec list
val check_tool_selected : tool_selection -> string -> unit
val scripted_model : response list -> model
val static_model : string -> model
val failing_model : unit -> model
val fallback_model : model -> model -> model
val agent_options : model -> agent_options
val tool_make : string -> string -> (json -> json) -> tool
val find_tool : tool list -> string -> tool option
val run_agent : agent_options -> session -> string -> run_result

val mcp_client : ?client_version:string -> ?protocol_version:string -> mcp_transport -> mcp_client
val mcp_list_tools : mcp_client -> json list
val mcp_call_tool : mcp_client -> string -> json -> json
val mcp_close : mcp_client -> unit

val otel_sink_new : string -> otel_transport -> (unit -> int) -> otel_sink
val otel_payload : otel_sink -> core_event -> int -> json
val otel_emit : otel_sink -> core_event -> unit
val retrieve_documents : retriever -> string -> int -> document list
val subagent_run : subagent_runner -> subagent_request -> subagent_task
