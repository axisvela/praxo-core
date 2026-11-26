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

val spec_version : string [@@ocaml.doc "Shared contract version implemented by this Core."]
val sdk_version : string [@@ocaml.doc "OCaml package version; matches [VERSION]."]
val stream_kinds : string list [@@ocaml.doc "Declared event stream kinds."]
val parse_json : string -> json [@@ocaml.doc "Parse one JSON value; raises [Json_error]; rejects trailing data; limited to 1 MiB and 64 nesting levels."]
val encode_json : json -> string [@@ocaml.doc "Serialize a value as JSON for wire use."]
val json_equal : json -> json -> bool [@@ocaml.doc "Structural equality; arrays ordered, object fields matched by name, duplicate keys by last value."]
val parse_tool_call : string -> call option [@@ocaml.doc "Recognize one call from JSON, XML, dotted tag, or plain line; [None] when absent; raises [Toolcall_error] above 256 KiB."]
val parse_input_json : string -> json option [@@ocaml.doc "Parse a trimmed JSON object; [None] otherwise."]
val strip_tool_call_markup : string -> string [@@ocaml.doc "Remove recognized tool-call blocks, collapse blank-line runs, and trim; raises [Toolcall_error] above 256 KiB."]
val validate_schema : json -> json -> string list [@@ocaml.doc "Return failing JSON paths for the supported schema subset; raises [Schema_error] for an invalid schema."]
val validate_manifest : string -> json option [@@ocaml.doc "[Some manifest] only when every declared field, permission, limit, and isolation rule holds; malformed input returns [None]."]

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

val raise_core : string -> string -> 'a [@@ocaml.doc "Raise [Core_error (code, message)]."]
val error_code : exn -> string [@@ocaml.doc "Return a [Core_error] code, or [\"\"] for other exceptions."]
val field_bool : string -> json -> bool option [@@ocaml.doc "Boolean field, or [None] when absent or mistyped."]
val field_array : string -> json -> json list [@@ocaml.doc "Array field, or [[]] when absent or mistyped."]
val field_object : string -> json -> json option [@@ocaml.doc "Object field, or [None] when absent or mistyped."]
val json_text : json -> string [@@ocaml.doc "Encode a value; alias of {!encode_json}."]
val starts_with : string -> string -> bool [@@ocaml.doc "Prefix test; an empty prefix matches."]
val ends_with : string -> string -> bool [@@ocaml.doc "Suffix test; an empty suffix matches."]
val content_block_make : string -> string option -> content_block [@@ocaml.doc "Content block without image URL or inline data."]
val tool_invocation_make : string -> string -> json -> tool_invocation [@@ocaml.doc "Build a tool invocation."]
val text_message : string -> string -> core_message [@@ocaml.doc "Message with a role and plain content."]
val assistant_message : string -> tool_invocation list -> core_message [@@ocaml.doc "Assistant message carrying optional tool calls."]
val tool_message : string -> string -> core_message [@@ocaml.doc "Tool result tied to an invocation id."]
val tool_spec_make : string -> string -> core_tool_spec [@@ocaml.doc "Tool description for a model request."]
val usage_make : int -> int -> usage [@@ocaml.doc "Build a token usage value."]
val usage_add : usage -> usage -> usage [@@ocaml.doc "Add two usage values."]
val request_make : core_message list -> core_tool_spec list -> request [@@ocaml.doc "Build a model request."]
val response_make : core_message -> usage -> response [@@ocaml.doc "Build a model response."]

(** {2 Provider adapters}

    Each adapter uses a caller-supplied {!transport}; no HTTP client, retry
    policy, or credential store is bundled. *)

val openai_request : ?stream:bool -> openai_config -> request -> http_request [@@ocaml.doc "Build a chat-completions request; trailing slashes trimmed; streaming sets [stream] and an SSE Accept header."]
val openai_parse_response : string -> response [@@ocaml.doc "Parse a chat-completions body; malformed content raises [PROVIDER_RESPONSE]."]
val openai_generate : openai_config -> transport -> request -> response [@@ocaml.doc "Send through the transport; non-2xx raises [PROVIDER_HTTP]."]
val openai_model : openai_config -> transport -> model [@@ocaml.doc "Adapt OpenAI-compatible generation, including SSE, to {!model}."]
val anthropic_request : ?stream:bool -> anthropic_config -> request -> http_request [@@ocaml.doc "Build an Anthropic Messages request."]
val anthropic_parse_response : string -> response [@@ocaml.doc "Parse a Messages body; malformed content raises [PROVIDER_RESPONSE]."]
val anthropic_generate : anthropic_config -> transport -> request -> response [@@ocaml.doc "Generate through the transport; non-2xx raises [PROVIDER_HTTP]."]
val anthropic_generate_stream : anthropic_config -> transport -> request -> (string -> unit) -> response [@@ocaml.doc "Generate and reassemble Anthropic SSE, calling [on_delta] per text delta."]
val anthropic_model : anthropic_config -> transport -> model [@@ocaml.doc "Adapt Anthropic generation to {!model}."]
val gemini_request : ?stream:bool -> gemini_config -> request -> http_request [@@ocaml.doc "Build a Gemini generateContent request."]
val gemini_parse_response : string -> response [@@ocaml.doc "Parse a generateContent body; malformed content raises [PROVIDER_RESPONSE]."]
val gemini_generate : gemini_config -> transport -> request -> response [@@ocaml.doc "Generate through the transport; non-2xx raises [PROVIDER_HTTP]."]
val gemini_generate_stream : gemini_config -> transport -> request -> (string -> unit) -> response [@@ocaml.doc "Generate and reassemble Gemini SSE, calling [on_delta] per text delta."]
val gemini_model : gemini_config -> transport -> model [@@ocaml.doc "Adapt Gemini generation to {!model}."]
val harmovela_config : string -> transport -> (unit -> int) -> harmovela_config [@@ocaml.doc "Build a Harmovela configuration; the clock returns Unix nanoseconds."]
val format_harmovela_timestamp : int -> string [@@ocaml.doc "Format Unix nanoseconds as a UTC RFC 3339 timestamp."]
val harmovela_envelope : harmovela_config -> core_event -> int -> json [@@ocaml.doc "Build the Harmovela envelope for an event time in nanoseconds."]
val harmovela_emit : harmovela_config -> core_event -> unit [@@ocaml.doc "POST to [base_url ^ \"/events\"]; non-2xx raises [HARMOVELA_HTTP]."]
val harmovela_sink : harmovela_config -> sink [@@ocaml.doc "Adapt a Harmovela configuration to {!sink}."]

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
val plugin_process_config_make : string -> string -> string list -> string -> plugin_process_config [@@ocaml.doc "Build a process-plugin configuration; an empty token is generated."]
val start_plugin_process : plugin_process_config -> plugin_process_host [@@ocaml.doc "Spawn the process, inject the token variable, and perform a control health call; the host owns its pipes."]
val invoke_plugin_process : plugin_process_host -> string -> string -> string -> string [@@ocaml.doc "Call a service method; [TIMEOUT], [NOT_ACTIVE], or the plugin error code is raised."]
val stop_plugin_process : plugin_process_host -> unit [@@ocaml.doc "Best-effort shutdown, then kill, reap, and close the pipes."]

(** {2 Sessions, memory, checkpoints, and context} *)

val session_make : string -> core_message list -> session [@@ocaml.doc "Build a session; messages are used as supplied and not persisted."]
val run_result_make : string -> string -> int -> usage -> run_result [@@ocaml.doc "Build a run result."]
val memory_record_make : string -> string -> string -> string option -> memory_record [@@ocaml.doc "Build a memory record; an empty id is assigned by {!memory_put}."]
val path_grant_make : string -> string -> path_grant [@@ocaml.doc "Build a path grant; {!path_checker} normalizes its root."]
val decision_make : bool -> string -> decision [@@ocaml.doc "Build an authorization decision."]
val event_make : string -> string -> string option -> json -> core_event [@@ocaml.doc "Build an event."]
val context_budget_make : int -> int -> context_budget [@@ocaml.doc "Build a token budget; non-positive [keep_recent] means four messages."]
val message_wire : core_message -> json [@@ocaml.doc "Serialize a message in the shared wire shape."]
val emit : sink -> core_event -> unit [@@ocaml.doc "Send one event to a sink."]
val multi_sink : sink list -> sink [@@ocaml.doc "Fan out each event to every sink."]
val filter_sink : sink -> string list -> sink [@@ocaml.doc "Forward only listed event types; an empty list forwards all."]
val memory_store : unit -> memory_store [@@ocaml.doc "Create an in-memory store."]
val memory_put : memory_store -> string -> memory_record -> memory_record [@@ocaml.doc "Append a record for a session, assigning [mem-N] when the id is empty."]
val memory_search : memory_store -> string -> string -> int -> memory_record list [@@ocaml.doc "Case-insensitive substring search; empty query matches all; newest first; non-positive [limit] returns all."]
val checkpoint_allowlist : unit -> checkpoint_allowlist [@@ocaml.doc "Create an empty checkpoint allowlist."]
val checkpoint_register : checkpoint_allowlist -> string -> unit [@@ocaml.doc "Allow an event type; empty type raises [CHECKPOINT_ERROR]."]
val checkpoint_marshal : checkpoint_allowlist -> string -> json -> string [@@ocaml.doc "Encode an enveloped payload; unregistered types raise [CHECKPOINT_TYPE_NOT_ALLOWED]."]
val checkpoint_unmarshal : checkpoint_allowlist -> string -> json [@@ocaml.doc "Decode a registered envelope; unknown types or non-objects raise [Core_error]."]
val normalize_path : string -> string [@@ocaml.doc "Normalize separators and [.]/[..] lexically; lowercases on Windows; does not resolve symlinks."]
val path_checker : path_grant list -> path_checker [@@ocaml.doc "Normalize grants; empty roots or unknown access raise [POLICY_ERROR]."]
val path_check : path_checker -> string -> string -> decision [@@ocaml.doc "Authorize [read], [write], or [readwrite] lexically; invalid access raises [POLICY_ERROR]."]
val path_allowed : path_checker -> string -> string -> bool [@@ocaml.doc "Boolean wrapper for {!path_check}; errors become [false]."]
val estimate_tokens : core_message list -> int [@@ocaml.doc "Approximate tokens from content and tool payload sizes; not provider billing."]
val truncate_to_tokens : string -> int -> string [@@ocaml.doc "Truncate to an approximate token budget and mark shortened text."]
val compact_context : context_budget -> core_message list -> core_message list * bool [@@ocaml.doc "Keep system and recent messages within a budget; returns messages and whether it fit."]
val pii_redact : string -> string [@@ocaml.doc "Mask email, US SSN, and 16-digit card-like patterns; best effort, not compliance."]
val redact_value : json -> json [@@ocaml.doc "Recursively redact strings inside a JSON value."]
val extract_json : string -> json option [@@ocaml.doc "Extract the first JSON object or array, including fenced blocks."]
val structured_output : json -> int -> (string -> string) option -> structured_output [@@ocaml.doc "Build a structured-output policy with a schema and repair budget."]
val structured_apply : structured_output -> string -> string option * string [@@ocaml.doc "Validate text, repairing up to the configured count; [Some text]/[\"\"] or [None]/code."]
val call_limit : int -> int -> call_limit [@@ocaml.doc "Build mutable per-run limits; non-positive means unlimited."]
val call_limit_model : call_limit -> unit [@@ocaml.doc "Count a model call and enforce [AGENT_MODEL_CALL_LIMIT]."]
val call_limit_tool : call_limit -> unit [@@ocaml.doc "Count a tool call and enforce [AGENT_TOOL_CALL_LIMIT]."]
val tool_selection : string list -> tool_selection [@@ocaml.doc "Build a tool selection."]
val select_tools : tool_selection -> core_tool_spec list -> core_tool_spec list [@@ocaml.doc "Keep only selected tool names."]
val check_tool_selected : tool_selection -> string -> unit [@@ocaml.doc "Reject unselected calls with [AGENT_TOOL_NOT_SELECTED]."]
val scripted_model : response list -> model [@@ocaml.doc "Replay responses in order; exhaustion raises [MODEL_ERROR]."]
val static_model : string -> model [@@ocaml.doc "Always answer with fixed text and zero usage."]
val failing_model : unit -> model [@@ocaml.doc "Always raise [MODEL_ERROR]."]
val fallback_model : model -> model -> model [@@ocaml.doc "Try the primary model, then the fallback on any exception."]
val interrupt_approve : string [@@ocaml.doc "Approve a pending interrupted call."]
val interrupt_edit : string [@@ocaml.doc "Replace arguments; edited values are reauthorized before invocation."]
val interrupt_reject : string [@@ocaml.doc "Deny with [AGENT_APPROVAL_DENIED]."]
val interrupt_respond : string [@@ocaml.doc "Answer without invoking the tool."]
val agent_action_make : string -> string -> string -> json -> agent_action [@@ocaml.doc "Build a policy action for a hook."]
val interrupt_make : string -> string -> tool_invocation -> interrupt [@@ocaml.doc "Build an interrupt request for a pending call."]
val interrupt_decision_make :
  ?arguments:json -> ?response:string -> ?reason:string -> string -> interrupt_decision [@@ocaml.doc "Build an interrupt decision; [edit] requires optional arguments."]
val agent_options : model -> agent_options [@@ocaml.doc "Defaults: no tools, eight steps, no policy or approvals."]
val tool_make : string -> string -> (json -> json) -> tool [@@ocaml.doc "Build an in-process tool; [invoke] exceptions propagate."]
val find_tool : tool list -> string -> tool option [@@ocaml.doc "Find the first tool by name."]
val run_agent : agent_options -> session -> string -> run_result [@@ocaml.doc "Run the bounded loop for one prompt; requires policy and tool scope when configured; does not persist history; callback errors propagate after best-effort [run.failed]."]

(** {2 MCP, OpenTelemetry, retrieval, and delegation} *)

val mcp_client : ?client_version:string -> ?protocol_version:string -> mcp_transport -> mcp_client [@@ocaml.doc "Initialize over a caller transport; handshake failures raise [MCP_HANDSHAKE]/[MCP_PROTOCOL]; no subprocess or socket."]
val mcp_list_tools : mcp_client -> json list [@@ocaml.doc "List tools across pages, rejecting duplicate names and repeated cursors."]
val mcp_call_tool : mcp_client -> string -> json -> json [@@ocaml.doc "Call a tool; [isError] raises [MCP_TOOL_ERROR]; prefers [structuredContent]."]
val mcp_close : mcp_client -> unit [@@ocaml.doc "Mark closed; later list/call operations raise [MCP_CLOSED]. The transport owns resource release."]
val otel_sink_new : string -> otel_transport -> (unit -> int) -> otel_sink [@@ocaml.doc "Build an OTLP/HTTP sink; endpoint, transport, and nanosecond clock are caller-owned."]
val otel_payload : otel_sink -> core_event -> int -> json [@@ocaml.doc "Build an OTLP span payload; only allowlisted data keys become attributes."]
val otel_emit : otel_sink -> core_event -> unit [@@ocaml.doc "Send a payload; non-2xx raises [OTEL_HTTP]."]
val retrieve_documents : retriever -> string -> int -> document list [@@ocaml.doc "Call a retriever; negative limits raise [RETRIEVER_INVALID]."]
val subagent_run : subagent_runner -> subagent_request -> subagent_task [@@ocaml.doc "Run a synchronous task; missing ids raise [SUBAGENT_INVALID]; failures become a failed task."]
