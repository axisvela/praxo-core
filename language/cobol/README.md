# COBOL Core

A native GnuCOBOL implementation, not a bridge to another Core. All 63 normative
vectors across the eleven groups pass, together with native agent, JSON,
contract-boundary, behavior, tooling, and API declaration checks. The
`cobol-conformance` remote job checks the declared scope. `cobol/v0.6.0` is the
source tag. Version `0.6.0` adds Anthropic and Gemini transport-seam model
adapters, an OTLP/HTTP OpenTelemetry sink, a retriever seam, and a synchronous
delegation seam. Earlier source adds middleware, lifecycle, cancellation,
streaming, SSE, batch tool dispatch, MCP, Harmovela, OpenAI-compatible adapters,
and human-in-the-loop interrupt decisions.

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/cobol/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/cobol/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/cobol/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: Source

## Build and Test

Use GnuCOBOL 2.0 or later and Python 3.10 or later:

```sh
python language/cobol/run-tests.py
```

Set `COBC` or pass `--compiler /path/to/cobc` when the compiler is not on PATH.
The driver builds one combined COBOL source per suite to avoid an old
GnuCOBOL multi-file code-generation issue. Generated files stay in
`language/cobol/build/`. Python only generates and launches native tests; it is not
required by a compiled Core consumer.

## Native API

| Program | Purpose |
| --- | --- |
| `praxo-run` | Agent loop with model, tool dispatcher, policy, and event callbacks |
| `praxo-anthropic` | Anthropic Messages adapter over a caller-supplied transport |
| `praxo-checkpoint` | Registered payload-type JSON envelopes |
| `praxo-context` | Token estimate and context compaction |
| `praxo-delegation` | Synchronous subagent request/result/task seam |
| `praxo-event` | Filter and multi-sink event delivery |
| `praxo-gemini` | Gemini `generateContent` adapter over a caller-supplied transport |
| `praxo-harmovela` | Harmovela event sink over a caller-supplied transport |
| `praxo-jsonschema` | Object/array schema validation |
| `praxo-schema-scalar` | Internal scalar schema checks |
| `praxo-schema-visit` | Internal recursive object/array checks |
| `praxo-memory` | In-memory session records and search |
| `praxo-middleware` | Call limits, tool selection, fallback, structured output, email redaction |
| `praxo-mcp` | MCP client over a caller-supplied transport |
| `praxo-openai` | OpenAI-compatible chat-completions adapter over a caller-supplied transport |
| `praxo-otel` | OTLP/HTTP OpenTelemetry span sink over a caller-supplied transport |
| `praxo-path-normalize` | Lexical path normalization |
| `praxo-pattern-check` | Bounded ASCII pattern matcher |
| `praxo-plugin` | Strict manifest parsing and validation |
| `praxo-policy` | Lexical path grants |
| `praxo-sse` | Server-sent-event stream parser with truncation and half-packet rejection |
| `praxo-registry` | In-memory tool registry with register/get/list/clear |
| `praxo-registry-scoped` | Same operations with caller-owned registry state (since 0.1.2) |
| `praxo-retriever` | Document callback seam over query and limit |
| `praxo-stream` | Stream-kind constants |
| `praxo-toolcall` | JSON, XML-style, dotted-tag, and plain tool-call parsing |
| `praxo-json-parse`, `praxo-json-generate`, `praxo-json-string`, `praxo-json-quote`, `praxo-json-slice`, `praxo-utf8` | Native JSON and UTF-8 utilities |

Records are declared in `language/cobol/copy/`. The agent callback interface is:

```cobol
call "praxo-run" using px-options px-session px-prompt
    px-result px-user-data
```

`px-options` names the model, tool dispatcher, policy, and event programs.
`px-user-data` is a caller-owned 4096-byte callback context. Blank callback
status means success; model/tool statuses propagate; a nonblank policy status
denies the action. The input session is not mutated, and each run uses local
history. Zero or negative `px-max-steps` selects eight steps; a nonpositive
token budget is unlimited.

## Agent Middleware Hooks

Version `0.2.0` adds optional callback programs to `px-options`:

| Field | Callback record | Purpose |
| --- | --- | --- |
| `px-before-run-program` | `px-action`, `px-user-data`, `px-status` | First before-run hook |
| `px-before-run-program-2` | `px-action`, `px-user-data`, `px-status` | Second before-run hook |
| `px-before-tool-program` | `px-call`, `px-user-data`, `px-status` | Rewrite the tool name or input |
| `px-after-run-program` | `px-result`, `px-user-data`, `px-status` | First after-run hook |
| `px-after-run-program-2` | `px-result`, `px-user-data`, `px-status` | Second after-run hook |
| `px-allowed-tool-count`, `px-allowed-tools` | none | Final tool-name allowlist |

Before-run hooks are entered in order before `run.started`. A startup failure
runs after-run cleanup for every entered slot and returns without a run event.
`px-before-tool-program` may rewrite `px-tool-name` and `px-tool-input`; the
final name is checked against `px-allowed-tools`, and changed names or
arguments are reauthorized before the tool call. After-run hooks run in entry
order. A cleanup failure does not hide the original run error, and a cleanup
failure after success fails the run closed. After-run hooks receive the current
result record and should treat it as read-only; report cleanup failure through
the status parameter. Blank program names skip the hook, and an empty allowlist
permits every tool. These are synchronous callback programs, not concurrent
middleware.

## Cancellation

Set `px-cancel-program` to a callback that returns a nonblank status when the
run should stop. The agent checks it before model work and before and after each
tool call. A cancellation stops later effects, sets `AGENT_CANCELLED`, runs
after-run cleanup, and emits `run.failed`. Model responses already produced are
not used after cancellation.

## Streaming and SSE

Set `px-stream-program` to receive `px-stream-part` records. The agent emits a
`values` part before the step loop and a `messages` part before completing a
final answer. A nonblank stream callback status aborts the run, runs after-run
cleanup, and emits `run.failed` instead of `run.completed`.

`praxo-sse` parses OpenAI-compatible server-sent-event text. It requires a
`data: [DONE]` marker or a non-null `finish_reason`; otherwise it returns the
local `MODEL_STREAM` status. Malformed data packets, including half packets,
also return `MODEL_STREAM` rather than being ignored.

## Model Adapters

The model adapters use caller-supplied transport programs; this Core has no
bundled HTTP client or socket wrapper. The native JSON utilities parse and
generate the wire payloads.

### OpenAI-Compatible

`praxo-openai` posts an OpenAI-compatible chat-completions request to
`{base-url}/chat/completions` through `px-provider-transport-program` using
`provider-call.cpy` and `provider-options.cpy`. It maps text messages, an
optional raw tools array, and max tokens; it parses text content, tool calls, and
prompt/completion token usage. A non-2xx response returns `PROVIDER_HTTP`;
malformed JSON returns `PROVIDER_JSON`.

Limitations: the model callback still carries one role/content/call-id triple per
message and no assistant tool-call history, so the adapter receives tool
declarations only through the dedicated options record. Streaming is not
implemented.

### Anthropic Messages

`praxo-anthropic` posts to `{base-url}/messages` through
`px-anthropic-transport-program` using `anthropic-options.cpy` and
`anthropic-call.cpy`. System messages are collected into the `system` field;
user and assistant messages map to `messages`; tools are passed through as raw
Anthropic tool declarations; `auto`, `any`, a raw `tool_choice` object, or a
tool name are supported. The adapter parses text and `tool_use` content blocks
and `input_tokens`/`output_tokens` usage. `px-anthropic-version` defaults to
`2023-06-01`.

Limitations: tool declarations and assistant tool-call history are not taken
from the Core model callback. Streaming is not implemented.

### Gemini generateContent

`praxo-gemini` posts to `{base-url}/models/{model}:generateContent` through
`px-gemini-transport-program` using `gemini-options.cpy` and `gemini-call.cpy`.
System messages become `systemInstruction`; `assistant` maps to the Gemini
`model` role; tools are passed through as raw Gemini declarations. `auto`,
`none`, `any`, or a raw `toolConfig` object are supported. The adapter parses
text and `functionCall` parts plus `promptTokenCount`/`candidatesTokenCount`
usage. Function-call identifiers are local deterministic values because Gemini
does not return an id.

Limitations: tool declarations and assistant tool-call history are not taken
from the Core model callback. Streaming and candidate selection policies are not
implemented.

## OpenTelemetry Sink

`praxo-otel` maps one Core event to an OTLP/HTTP JSON span and posts it to the
required endpoint through `px-otel-transport-program` using `otel.cpy`,
`otel-event.cpy`, and `otel-call.cpy`. Trace and span identifiers are
deterministic hexadecimal strings (32 and 16 characters). Event data is excluded
by default; `px-otel-allowed-keys` adds `praxo.event.data.<key>` string
attributes. A 2xx status succeeds; any other status returns `OTEL_HTTP` and
stores a response body bounded to 512 bytes. A blank endpoint returns
`OTEL_URL`.

Limitations: no OpenTelemetry SDK, sampler, collector, batching, retry, or
delivery guarantee. Event data values are not redacted when allowlisted.

## Retriever

`praxo-retriever` validates a query/limit request, then calls a caller-supplied
retriever program using `retriever.cpy`. Documents carry id, content, optional
metadata JSON, and an optional score. A negative limit or blank callback returns
`RETRIEVER_INVALID`; callback statuses propagate. The seam does not define an
embedding model, vector store, ranking service, or search-quality claim.

## Synchronous Delegation

`praxo-delegation` runs a caller-supplied subagent program synchronously using
`delegation.cpy`. A valid request needs a parent session id and agent id;
otherwise it returns `SUBAGENT_INVALID`. The task starts in `running`, then
becomes `completed` or `failed`. A runner status is preserved in the task error
field, so callers can distinguish provider or policy failures. There is no
asynchronous manager, queue, wait, update, or cancel operation.

## Batch Tool Dispatch

Set `px-tool-batch-program` and `px-max-parallel-tools` to dispatch one model
response's tool calls through a caller-provided batch program using
`tool-batch.cpy`. The agent authorizes and emits `tool.call` for each final
call, passes the configured parallelism, and accepts results only in the same
call-id order. The batch program is responsible for any concurrent execution;
the native COBOL test verifies the limit and ordered results, not OS threads.
Leave the batch program blank to use the single `px-tool-program` path.

## Scoped Registry Consumption

Version `0.1.2` adds `praxo-registry-scoped` and `registry-state.cpy`. Initialize
one state record for each independent registry; keep it alive during callbacks.
The original two-parameter `praxo-registry` remains compatible and retains a
shared process-local registry. Use the scoped entry point for independent agents.

```cobol
copy "registry-state.cpy".
copy "registry.cpy".
```

```cobol
initialize px-registry-state px-registry-request
move "register" to px-reg-op
move "echo" to px-reg-name
move 4 to px-reg-name-length
move "my-echo" to px-reg-program
move 7 to px-reg-program-length
call "praxo-registry-scoped" using px-registry-state
    px-registry-request px-registry-result
```

Check `px-reg-error` after every call. `get` returns the registered callback
program; `list` returns sorted metadata for model/tool discovery. Blank names
and program fields remain accepted for compatibility with the original metadata
registry; dispatchers must reject an empty callback program before invocation.
The registry is not a model adapter or authorization boundary.

`tests/registry-agent.cob` is an executable consumer fixture over the actual
`praxo-run`: a model callback lists tools, a dispatcher looks up the program,
and two agents using the same tool name reach different callbacks through two
independent state records. It also verifies policy denial and missing tools
produce no tool effects. Its state pointer in `px-user-data` is process-local,
not serializable or safe to accept from an untrusted caller. The standard test
driver runs this fixture alongside `tests/registry.cob` capacity/isolation tests.
This is deterministic native integration evidence, not production validation.

## Scope and Limits

The agent API is wire-shaped but not a full Go model surface: it carries text
messages, one tool-call list per response, and callback events. It does not carry
full assistant tool-call history, so model adapters receive tool declarations
through their own options records. Provider adapters are transport seams, not
bundled HTTP clients. Stream parts are synchronous callback notifications, and
the SSE parser consumes text; there is no HTTP/provider client. Cancellation is
cooperative through `px-cancel-program`, not thread interruption. Batch tool
concurrency is caller-provided; the agent does not create OS threads. The OTel,
retriever, and delegation adapters are local seams over caller-supplied
transports or callbacks; they add no collector, vector store, durable worker, or
concurrency guarantee.

JSON inputs are limited to 32768 bytes, 512 nodes, and 64 nested containers.
Strings preserve trailing spaces and embedded NUL bytes. Invalid UTF-8, lone
surrogates, malformed numbers, and trailing data are rejected. Duplicate object
keys are retained; lookup uses the last value. Generated JSON is limited to
16384 bytes. JSON utilities return local `JSON_INVALID` and `JSON_CAPACITY`
statuses, not new wire error codes.

Checkpoint allowlists wrap JSON values only; they do not instantiate arbitrary
native types. Plugin parsing validates the top-level and entrypoint field sets,
required launch targets, protocol, isolation, capabilities (including
non-adjacent duplicates), and basic identity/version syntax. It does not yet
execute plugins, verify signatures, or fully validate permissions, limits,
health, SBOM, and signature contents.

Schema validation covers the vector-defined object, array, string, number,
integer, boolean, enum, length, pattern, and numeric-bound behavior. Numeric
bounds use finite floating-point conversion, so very large integers are not
arbitrary precision. Patterns are a bounded ASCII subset: literals, dot,
classes/ranges, anchors, and `*`, `+`, `?`. Groups, alternation, counted
repetition, Unicode pattern matching, and unsupported escapes return
`SCHEMA_PATTERN_UNSUPPORTED` instead of accepting data.

Path policy is lexical normalization, not OS confinement. It rejects UNC,
drive-relative, and traversal-outside-root paths in the exercised cases but
does not resolve symlinks, reparse points, filesystem case rules, or races. Do
not use it as a sandbox. Email redaction covers only email addresses, not other
PII classes. Memory search uses ASCII case folding and lexical ordering of
canonical UTC timestamps. The tool registry stores up to 32 entries, replaces
duplicate names, and lists entries sorted by name; it has no concurrency
semantics.

## Gates

`api/0.6.0.txt` inventories public copybook records, module program IDs,
and linkage parameters. `api-snapshot.py --check` runs in the test driver;
regenerate intentionally with `--update`. Tooling tests check fixture
determinism, assertion polarity, snapshot sensitivity, and the middleware,
cancellation, streaming, SSE, and batch-dispatch declarations. The
`cobol-conformance` CI job runs all of these plus the native agent, behavior,
SSE, JSON, contract, model-adapter, telemetry, retriever, and delegation
programs.

`cobol/v0.6.0` is the source tag. `api/0.1.1.txt`, `api/0.1.2.txt`, and
`api/0.2.0.txt` remain immutable previous declaration snapshots;
`api/0.4.0.txt` adds the cancellation, stream, SSE, and batch records;
`api/0.5.0.txt` adds the MCP, Harmovela, and OpenAI-compatible records;
`api/0.6.0.txt` adds the Anthropic, Gemini, OTel, retriever, and delegation
records. `spec/parity/cobol.md` records partial surfaces. The Core sources are
MIT-licensed; GnuCOBOL and its runtime are separately licensed external
toolchain dependencies.
