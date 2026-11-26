(** Native OCaml Core for PRAXO-CORE.

    Consumers use module [Praxo_core]. Provider adapters are transport seams;
    the caller supplies HTTP and credentials. Path checks are lexical, not OS
    containment; sessions, checkpoints, and events are not durable or exactly-once. *)

(** {2 JSON and tool-call contract} *)

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

(** Shared contract version implemented by this Core. *)
val spec_version : string
(** OCaml package version; matches [VERSION]. *)
val sdk_version : string
(** Declared event stream kinds. *)
val stream_kinds : string list
(** Parse one JSON value; raises [Json_error]; rejects trailing data; limited to 1 MiB and 64 nesting levels. *)
val parse_json : string -> json
(** Serialize a value as JSON for wire use. *)
val encode_json : json -> string
(** Structural equality; arrays ordered, object fields matched by name. *)
val json_equal : json -> json -> bool
(** Recognize one call from JSON, XML, dotted tag, or plain line; [None] when absent; raises [Toolcall_error] above 256 KiB. *)
val parse_tool_call : string -> call option
(** Parse a trimmed JSON object; [None] otherwise. *)
val parse_input_json : string -> json option
(** Remove recognized tool-call blocks, collapse blank-line runs, and trim; raises [Toolcall_error] above 256 KiB. *)
val strip_tool_call_markup : string -> string
(** Return failing JSON paths for the supported schema subset; raises [Schema_error] for an invalid schema. *)
val validate_schema : json -> json -> string list
(** [Some manifest] only when every declared field, permission, limit, and isolation rule holds; malformed input returns [None]. *)
val validate_manifest : string -> json option

(** {2 Messages, models, and options} *)

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

(** {2 Constructors and accessors} *)

(** Raise [Core_error (code, message)]. *)
val raise_core : string -> string -> 'a
(** Return a [Core_error] code, or [""] for other exceptions. *)
val error_code : exn -> string
(** Boolean field, or [None] when absent or mistyped. *)
val field_bool : string -> json -> bool option
(** Array field, or [[]] when absent or mistyped. *)
val field_array : string -> json -> json list
(** Object field, or [None] when absent or mistyped. *)
val field_object : string -> json -> json option
(** Encode a value; alias of {!encode_json}. *)
val json_text : json -> string
(** Prefix test; an empty prefix matches. *)
val starts_with : string -> string -> bool
(** Suffix test; an empty suffix matches. *)
val ends_with : string -> string -> bool
(** Content block without image URL or inline data. *)
val content_block_make : string -> string option -> content_block
(** Build a tool invocation. *)
val tool_invocation_make : string -> string -> json -> tool_invocation
(** Message with a role and plain content. *)
val text_message : string -> string -> core_message
(** Assistant message carrying optional tool calls. *)
val assistant_message : string -> tool_invocation list -> core_message
(** Tool result tied to an invocation id. *)
val tool_message : string -> string -> core_message
(** Tool description for a model request. *)
val tool_spec_make : string -> string -> core_tool_spec
(** Build a token usage value. *)
val usage_make : int -> int -> usage
(** Add two usage values. *)
val usage_add : usage -> usage -> usage
(** Build a model request. *)
val request_make : core_message list -> core_tool_spec list -> request
(** Build a model response. *)
val response_make : core_message -> usage -> response

(** {2 Provider adapters}

    Each adapter uses a caller-supplied {!transport}; no HTTP client, retry
    policy, or credential store is bundled. *)

(** Build a chat-completions request; trailing slashes trimmed; streaming sets [stream] and an SSE Accept header. *)
val openai_request : ?stream:bool -> openai_config -> request -> http_request
(** Parse a chat-completions body; malformed content raises [PROVIDER_RESPONSE]. *)
val openai_parse_response : string -> response
(** Send through the transport; non-2xx raises [PROVIDER_HTTP]. *)
val openai_generate : openai_config -> transport -> request -> response
(** Adapt OpenAI-compatible generation, including SSE, to {!model}. *)
val openai_model : openai_config -> transport -> model
(** Build an Anthropic Messages request. *)
val anthropic_request : ?stream:bool -> anthropic_config -> request -> http_request
(** Parse a Messages body; malformed content raises [PROVIDER_RESPONSE]. *)
val anthropic_parse_response : string -> response
(** Generate through the transport; non-2xx raises [PROVIDER_HTTP]. *)
val anthropic_generate : anthropic_config -> transport -> request -> response
(** Generate and reassemble Anthropic SSE, calling [on_delta] per text delta. *)
val anthropic_generate_stream : anthropic_config -> transport -> request -> (string -> unit) -> response
(** Adapt Anthropic generation to {!model}. *)
val anthropic_model : anthropic_config -> transport -> model
(** Build a Gemini generateContent request. *)
val gemini_request : ?stream:bool -> gemini_config -> request -> http_request
(** Parse a generateContent body; malformed content raises [PROVIDER_RESPONSE]. *)
val gemini_parse_response : string -> response
(** Generate through the transport; non-2xx raises [PROVIDER_HTTP]. *)
val gemini_generate : gemini_config -> transport -> request -> response
(** Generate and reassemble Gemini SSE, calling [on_delta] per text delta. *)
val gemini_generate_stream : gemini_config -> transport -> request -> (string -> unit) -> response
(** Adapt Gemini generation to {!model}. *)
val gemini_model : gemini_config -> transport -> model
(** Build a Harmovela configuration; the clock returns Unix nanoseconds. *)
val harmovela_config : string -> transport -> (unit -> int) -> harmovela_config
(** Format Unix nanoseconds as a UTC RFC 3339 timestamp. *)
val format_harmovela_timestamp : int -> string
(** Build the Harmovela envelope for an event time in nanoseconds. *)
val harmovela_envelope : harmovela_config -> core_event -> int -> json
(** POST to [base_url ^ "/events"]; non-2xx raises [HARMOVELA_HTTP]. *)
val harmovela_emit : harmovela_config -> core_event -> unit
(** Adapt a Harmovela configuration to {!sink}. *)
val harmovela_sink : harmovela_config -> sink

(** {2 Process plugin host}

    Timeouts are seconds; the host provides framing and cancellation, not an OS
    sandbox or resource-isolation boundary. *)

type plugin_process_config = {
  process_plugin_id : string;
  process_path : string;
  process_args : string list;
  process_token : string;
  process_token_env : string;
  process_start_timeout : float;
  process_invoke_timeout : float;
}
type plugin_process_host
(** Build a process-plugin configuration; an empty token is generated. *)
val plugin_process_config_make : string -> string -> string list -> string -> plugin_process_config
(** Spawn the process, inject the token variable, and perform a control health call; the host owns its pipes. *)
val start_plugin_process : plugin_process_config -> plugin_process_host
(** Call a service method; [TIMEOUT], [NOT_ACTIVE], or the plugin error code is raised. *)
val invoke_plugin_process : plugin_process_host -> string -> string -> string -> string
(** Best-effort shutdown, then kill, reap, and close the pipes. *)
val stop_plugin_process : plugin_process_host -> unit

(** {2 Sessions, memory, checkpoints, and context} *)

(** Build a session; messages are used as supplied and not persisted. *)
val session_make : string -> core_message list -> session
(** Build a run result. *)
val run_result_make : string -> string -> int -> usage -> run_result
(** Build a memory record; an empty id is assigned by {!memory_put}. *)
val memory_record_make : string -> string -> string -> string option -> memory_record
(** Build a path grant; {!path_checker} normalizes its root. *)
val path_grant_make : string -> string -> path_grant
(** Build an authorization decision. *)
val decision_make : bool -> string -> decision
(** Build an event. *)
val event_make : string -> string -> string option -> json -> core_event
(** Build a token budget; non-positive [keep_recent] means four messages. *)
val context_budget_make : int -> int -> context_budget
(** Serialize a message in the shared wire shape. *)
val message_wire : core_message -> json
(** Send one event to a sink. *)
val emit : sink -> core_event -> unit
(** Fan out each event to every sink. *)
val multi_sink : sink list -> sink
(** Forward only listed event types; an empty list forwards all. *)
val filter_sink : sink -> string list -> sink
(** Create an in-memory store. *)
val memory_store : unit -> memory_store
(** Append a record for a session, assigning [mem-N] when the id is empty. *)
val memory_put : memory_store -> string -> memory_record -> memory_record
(** Case-insensitive substring search; empty query matches all; newest first; non-positive [limit] returns all. *)
val memory_search : memory_store -> string -> string -> int -> memory_record list
(** Create an empty checkpoint allowlist. *)
val checkpoint_allowlist : unit -> checkpoint_allowlist
(** Allow an event type; empty type raises [CHECKPOINT_ERROR]. *)
val checkpoint_register : checkpoint_allowlist -> string -> unit
(** Encode an enveloped payload; unregistered types raise [CHECKPOINT_TYPE_NOT_ALLOWED]. *)
val checkpoint_marshal : checkpoint_allowlist -> string -> json -> string
(** Decode a registered envelope; unknown types or non-objects raise [Core_error]. *)
val checkpoint_unmarshal : checkpoint_allowlist -> string -> json
(** Normalize separators and [.]/[..] lexically; lowercases on Windows; does not resolve symlinks. *)
val normalize_path : string -> string
(** Normalize grants; empty roots or unknown access raise [POLICY_ERROR]. *)
val path_checker : path_grant list -> path_checker
(** Authorize [read], [write], or [readwrite] lexically; invalid access raises [POLICY_ERROR]. *)
val path_check : path_checker -> string -> string -> decision
(** Boolean wrapper for {!path_check}; errors become [false]. *)
val path_allowed : path_checker -> string -> string -> bool
(** Approximate tokens from content and tool payload sizes; not provider billing. *)
val estimate_tokens : core_message list -> int
(** Truncate to an approximate token budget and mark shortened text. *)
val truncate_to_tokens : string -> int -> string
(** Keep system and recent messages within a budget; returns messages and whether it fit. *)
val compact_context : context_budget -> core_message list -> core_message list * bool
(** Mask email, US SSN, and 16-digit card-like patterns; best effort, not compliance. *)
val pii_redact : string -> string
(** Recursively redact strings inside a JSON value. *)
val redact_value : json -> json
(** Extract the first JSON object or array, including fenced blocks. *)
val extract_json : string -> json option
(** Build a structured-output policy with a schema and repair budget. *)
val structured_output : json -> int -> (string -> string) option -> structured_output
(** Validate text, repairing up to the configured count; [Some text]/[""] or [None]/code. *)
val structured_apply : structured_output -> string -> string option * string
(** Build mutable per-run limits; non-positive means unlimited. *)
val call_limit : int -> int -> call_limit
(** Count a model call and enforce [AGENT_MODEL_CALL_LIMIT]. *)
val call_limit_model : call_limit -> unit
(** Count a tool call and enforce [AGENT_TOOL_CALL_LIMIT]. *)
val call_limit_tool : call_limit -> unit
(** Build a tool selection. *)
val tool_selection : string list -> tool_selection
(** Keep only selected tool names. *)
val select_tools : tool_selection -> core_tool_spec list -> core_tool_spec list
(** Reject unselected calls with [AGENT_TOOL_NOT_SELECTED]. *)
val check_tool_selected : tool_selection -> string -> unit
(** Replay responses in order; exhaustion raises [MODEL_ERROR]. *)
val scripted_model : response list -> model
(** Always answer with fixed text and zero usage. *)
val static_model : string -> model
(** Always raise [MODEL_ERROR]. *)
val failing_model : unit -> model
(** Try the primary model, then the fallback on any exception. *)
val fallback_model : model -> model -> model
(** Approve a pending interrupted call. *)
val interrupt_approve : string
(** Replace arguments; edited values are reauthorized before invocation. *)
val interrupt_edit : string
(** Deny with [AGENT_APPROVAL_DENIED]. *)
val interrupt_reject : string
(** Answer without invoking the tool. *)
val interrupt_respond : string
(** Build a policy action for a hook. *)
val agent_action_make : string -> string -> string -> json -> agent_action
(** Build an interrupt request for a pending call. *)
val interrupt_make : string -> string -> tool_invocation -> interrupt
(** Build an interrupt decision; [edit] requires optional arguments. *)
val interrupt_decision_make :
  ?arguments:json -> ?response:string -> ?reason:string -> string -> interrupt_decision
(** Defaults: no tools, eight steps, no policy or approvals. *)
val agent_options : model -> agent_options
(** Build an in-process tool; [invoke] exceptions propagate. *)
val tool_make : string -> string -> (json -> json) -> tool
(** Find the first tool by name. *)
val find_tool : tool list -> string -> tool option
(** Run the bounded loop for one prompt; requires policy and tool scope when configured; does not persist history; callback errors propagate after best-effort [run.failed]. *)
val run_agent : agent_options -> session -> string -> run_result

(** {2 MCP, OpenTelemetry, retrieval, and delegation} *)

(** Initialize over a caller transport; handshake failures raise [MCP_HANDSHAKE]/[MCP_PROTOCOL]; no subprocess or socket. *)
val mcp_client : ?client_version:string -> ?protocol_version:string -> mcp_transport -> mcp_client
(** List tools across pages, rejecting duplicate names and repeated cursors. *)
val mcp_list_tools : mcp_client -> json list
(** Call a tool; [isError] raises [MCP_TOOL_ERROR]; prefers [structuredContent]. *)
val mcp_call_tool : mcp_client -> string -> json -> json
(** Mark closed; the transport owns resource release. *)
val mcp_close : mcp_client -> unit
(** Build an OTLP/HTTP sink; endpoint, transport, and nanosecond clock are caller-owned. *)
val otel_sink_new : string -> otel_transport -> (unit -> int) -> otel_sink
(** Build an OTLP span payload; only allowlisted data keys become attributes. *)
val otel_payload : otel_sink -> core_event -> int -> json
(** Send a payload; non-2xx raises [OTEL_HTTP]. *)
val otel_emit : otel_sink -> core_event -> unit
(** Call a retriever; negative limits raise [RETRIEVER_INVALID]. *)
val retrieve_documents : retriever -> string -> int -> document list
(** Run a synchronous task; missing ids raise [SUBAGENT_INVALID]; failures become a failed task. *)
val subagent_run : subagent_runner -> subagent_request -> subagent_task
