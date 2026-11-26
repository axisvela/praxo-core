# PRAXO-CORE for MATLAB

> **MATLAB runtime compatibility is unverified.** Current execution evidence is
> GNU Octave 11.3.0 only. No MATLAB release or Windows/macOS/Linux MATLAB support
> matrix has been independently validated. File Exchange compatibility labels
> are not test evidence; do not use them as a production support promise.

## Package

| Field | Value |
| --- | --- |
| Package | `PRAXO-CORE` (MATLAB toolbox) |
| Source tag | `matlab/v0.9.0` |
| File Exchange | [entry 185166](https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core) |
| Install | File Exchange Add-On, or the release ZIP / source path |
| License | MIT |
| Contract | `SPEC_VERSION` `0.2.0` |
| Documentation | https://axisvela.github.io/praxo-core/languages/matlab/ |

## Install and Quickstart

Install the toolbox from File Exchange, or unzip the release package and add the
installed toolbox to the MATLAB path. From a source checkout:

```matlab
addpath('language/matlab-octave-core');
result = praxo.agent_run('Hi', @(request) struct('content', 'hello'), {}, struct());
disp(result.output)
```

For an OpenAI-compatible endpoint, pass the adapter as the model:

```matlab
options = struct('baseUrl', 'https://api.openai.com/v1', ...
    'model', 'gpt-4o-mini', 'apiKey', getenv('PRAXO_API_KEY'));
model = @(request) praxo.openai_compatible(request, options);
result = praxo.agent_run('Hi', model, {}, struct());
```

The File Exchange ZIP contains the `+praxo` Core, `examples/`, and `Tutorial/`.

## Examples

| Theme | Example | What it shows |
| --- | --- | --- |
| Consumer | [consumer](https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/consumer) | Deterministic model, tool, and allow/deny |
| Live model | [live-model](https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/live-model) | OpenAI-compatible endpoint and `get_time` tool |
| HTTP service | [service](https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/service) | Transport-neutral request handler |
| Identity and policy | [identity-policy](https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/identity-policy) | Trusted principal and tenant checks |
| Structured output | [structured-output](https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/structured-output) | Schema validation and rejection |
| Streaming | [streaming](https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/streaming) | Accumulated output reconstruction |
| Retry | [retry](https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/retry) | Bounded transient retry |
| Provider fallback | [provider-fallback](https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/provider-fallback) | Primary failure and fallback |
| Checkpoint | [checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/checkpoint) | Allowlist round trip |
| Session checkpoint | [session-checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/session-checkpoint) | Multi-turn history recovery |
| Event sink | [event-sink](https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/event-sink) | Filtered sink composition |
| MCP | [mcp](https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/mcp) | Caller-owned MCP-shaped transport |
| HITL | [hitl](https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/hitl) | Approve, edit, reject, and respond |
| Representative chain | [representative-chain](https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/representative-chain) | MCP, delegation, OTel/Harmovela, denied edit |
| Advanced delegation | [advanced-delegation](https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/advanced-delegation) | Parent/child scope and six governance checks |

Each example directory has a README with the exact `octave-cli` or
`matlab -batch` command and expected output. Examples are currently validated
under GNU Octave; native MATLAB execution remains unverified.

## Capabilities

| Capability | Status |
| --- | --- |
| OpenAI-compatible model | native |
| Anthropic model | native |
| Gemini model | native |
| MCP | transport-neutral caller-owned client |
| Harmovela sink | native |
| OpenTelemetry sink | native transport seam |
| Retriever | native seam |
| Subagent delegation | synchronous seam |
| Memory, checkpoint, policy, HITL | native Core-local |

Native MATLAB Core implementation with source tag `matlab/v0.9.0`. It is
published on
[MATLAB File Exchange](https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core).
The shared implementation passes all eleven vector groups under GNU Octave
11.3.0 and includes the native agent loop, memory store, checkpoint allowlist,
lexical path policy, context compaction, event sinks, middleware helpers, tool
selection, an OpenTelemetry sink, a retriever seam, and synchronous subagent
delegation. It does not delegate its behavior to Go or another language Core.

MATLAB and Octave share the implementation in
`language/matlab-octave-core/+praxo`. The Octave package root and source tag
live in `language/octave` (`octave/v0.9.0`). Local validation uses GNU Octave
11.3.0, including the shared service-auth test; native MATLAB compatibility is a
target, not yet independently verified. The source tag does not imply production
readiness or a delivery date.

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/matlab/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/matlab/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/matlab/llms.md)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples): runnable language-specific examples.
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [MATLAB File Exchange](https://www.mathworks.com/matlabcentral/fileexchange/185166-praxo-core)
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761) · [LinkedIn](https://www.linkedin.com/company/axisvela/) · [Facebook](https://www.facebook.com/profile.php?id=61596905732406) · [YouTube](https://www.youtube.com/@axisvela) · [Discord](https://discord.com/channels/1575163993767809064/1575164343148875977) · [GitHub Discussions](https://github.com/axisvela/praxo-core/discussions) · [GitHub Issues](https://github.com/axisvela/praxo-core/issues) · [Documentation](https://axisvela.github.io/praxo-core/) · [Architect](https://axisvela.architect.pub)

## Run the Checks

With Python 3.10+ and an Octave CLI available, from the repository root:

```bash
python language/matlab/run-tests.py
python language/matlab/api-snapshot.py --check
```

Set `OCTAVE` or pass `--octave /path/to/octave-cli` to select the interpreter.
Python only launches the native tests and checks the source API inventory.
The implementation and tests run in Octave, not Python. The runner covers all
eleven shared vector groups and verifies each fixture's group and
`SPEC_VERSION` before running it, then runs the HITL and session-checkpoint
example self-checks.

## API

Add `language/matlab` to the interpreter path and call:

```matlab
node = praxo.parse_json('{"name":"echo","input":{"text":"hi"}}');
raw = praxo.encode_json(node);
call = praxo.parse_tool_call(raw);
paths = praxo.validate_schema(praxo.parse_json('{"type":"string"}'), node);
[valid, manifest] = praxo.validate_manifest('{}');
result = praxo.agent_run('hello', @(request) struct('content', 'hello'), {}, struct());
```

JSON nodes have `kind` and `value` fields. Objects use an N-by-2 cell array of
original keys and typed values; arrays use cells; `null` is a distinct kind.
This avoids host JSON decoders conflating null, empty arrays, and singleton
arrays or rewriting object keys. JSON strings are represented as UTF-8 bytes
in character vectors; MATLAB's character model has not yet been validated.

## OpenAI-Compatible Adapter

`praxo.openai_compatible(request, options)` posts to
`{baseUrl}/chat/completions`, maps assistant content, tool calls, usage, and
finish reason, and parses call arguments into typed JSON objects. Set
`options.transport` to a function handle returning `status` and `body` for
deterministic tests. The default transport uses `webwrite`. Missing base URLs
and non-2xx responses raise `praxo:provider` with a `PROVIDER_HTTP` code;
invalid tool arguments use `PROVIDER_JSON`. Set `request.onDelta` to use
streaming: the adapter adds `"stream": true`, parses SSE, reassembles content,
fragmented tool calls, usage, and `finish_reason`, and calls the delta callback.
Inject `stream_transport` returning raw SSE text, or use the `webwrite` text
response path.

```matlab
options = struct('baseUrl', 'https://api.openai.com/v1', ...
    'model', 'gpt-4o-mini', 'apiKey', getenv('PRAXO_API_KEY'));
model = @(request) praxo.openai_compatible(request, options);
result = praxo.agent_run('Hi', model, {}, struct());
```

## Agent Loop

`praxo.agent_run(prompt, model, tools, options)` accepts a character-vector
prompt, a model function handle, a cell array of tool structs, and an options
struct. The model receives a struct with `messages` and `tools` cell arrays and
returns a struct with character-vector `content`, optional `toolCalls` cell
array, and optional nonnegative integer `inputTokens` and `outputTokens`.
Each call has character-vector `id` and `name`, and `arguments` as a typed JSON
object node. Each tool has a unique `name`, optional `description`, and an
`invoke` function handle receiving the arguments node and returning a JSON node.
The tool result is JSON-encoded and added to subsequent model messages with its
`toolCallId`. Calls run sequentially. Callback exceptions fail the run.

Set `options.messages` (or `options.history`) to a cell array of prior messages
to continue a session; `result.messages` always contains the full updated
history, including the prompt and assistant/tool turns. The legacy call shape is
unchanged.

Options `maxSteps` and `maxTokens` default to 8 and 0 respectively; zero tokens
means unlimited, and steps must be positive. The result contains `output`,
`steps`, token counts, `runId`, `sessionId`, ordered event names,
`toolInvocations`, `messages`, `errorCode`, and `errorMessage`. An empty
`errorCode` indicates success. Budget failures use `AGENT_MAX_STEPS` or
`AGENT_MAX_TOKENS`; missing tools use `TOOL_NOT_FOUND`, while invalid or failing
model and tool callbacks use local `MODEL_ERROR` and `TOOL_ERROR`. Invalid
configuration raises `praxo:agent`. Events are recorded rather than streamed.
Token budgets depend on counts reported by the model, and are checked before
accepting its message.

HITL options are `interruptOn` (a tool-name cell array or character vector),
`onInterruptDecision`, and `onInterrupt`. The decision callback receives an
interrupt struct with `runId`, `sessionId`, and `call`, and returns a struct with
`action` set to `approve`, `edit`, `reject`, or `respond`; `edit` supplies an
`arguments` JSON node, `reject` may supply a `reason`, and `respond` supplies a
`response` string. Edited arguments are reauthorized before invocation. Missing
handlers return `AGENT_INTERRUPT_UNHANDLED`, rejected calls return
`AGENT_APPROVAL_DENIED`, and malformed decisions return
`AGENT_INTERRUPT_DECISION_INVALID`. The boolean `onInterrupt` callback is used
only when `onInterruptDecision` is absent.

Local parity inventory: `agent.Agent.Run` maps partially to `praxo.agent_run`
(P2); the callback API and loop cover the shared agent-loop vectors, not the
full reference agent surface. HITL and session-history options are Core-local
extensions; the shared parity inventory remains unchanged.

## Anthropic and Gemini Adapters

praxo.anthropic_compatible(request, options) and
praxo.gemini_compatible(request, options) map the native Messages and
generateContent APIs. Both accept an injected transport for deterministic
tests; set `request.onDelta` to reassemble Anthropic SSE.

## Harmovela Event Sink

```matlab
sink = praxo.harmovela_sink('http://127.0.0.1:8790/aep/api');
event = praxo.event('tool.call', 's1', 'run-1', ...
    praxo.json_make_object({'name', praxo.json_make_string('echo')}));
sink = praxo.harmovela_emit(sink, event);
```

`praxo.harmovela_emit` posts to `{baseURL}/events` with
`content-type: application/json` and the documented `spec_version`, `id`,
`type`, `source`, `created_at`, and merged `payload` envelope. Pass a transport
function handle and a clock function handle to `praxo.harmovela_sink` for
deterministic tests without network access. A 2xx status is success; any other
status raises `praxo:harmovela` with the status and a bounded response body.

The sink adds no authentication, retries, buffering, ordering, or
exactly-once-delivery guarantee. Apply caller-side filtering because event data
may contain sensitive content, and use HTTPS for remote endpoints. The default
transport uses the runtime HTTP client and cannot report the exact status of a
thrown non-2xx response.

## OpenTelemetry Event Sink

```matlab
sink = praxo.otel_sink('http://127.0.0.1:4318/v1/traces', ...
    'praxo-core', {'tool_name'});
event = praxo.event('tool.call', 's1', 'run-1', ...
    praxo.json_make_object({'tool_name', praxo.json_make_string('echo')}));
sink = praxo.otel_emit(sink, event);
```

`praxo.otel_emit` posts OTLP/HTTP spans to the required endpoint with
`content-type: application/json`. Event data is excluded unless its keys appear
in the explicit allowlist passed to `praxo.otel_sink`. Trace and span IDs are
deterministic 32- and 16-character hexadecimal values derived from the event and
clock. Pass a transport function handle receiving `(method, url, headers, body)`
and a clock function handle for deterministic tests without network access. A
2xx status is success; any other status raises `praxo:otel` with an `OTEL_HTTP`
code and a body bounded to 512 characters. No OpenTelemetry SDK is required.

The sink adds no sampling, collector, authentication, retries, buffering,
ordering, or delivery guarantee. Use HTTPS for remote endpoints and allowlist
only the event data keys that may leave the process.

## Retriever

`praxo.document(id, content, metadata, score)` builds a document, and
`praxo.retrieve_documents(retriever, query, limit)` invokes a retriever function
handle with the query and limit. A negative limit raises `praxo:retriever` with
a `RETRIEVER_INVALID` code without invoking the retriever.

```matlab
retriever = @(query, limit) {praxo.document('doc-1', query, struct(), 0.5)};
documents = praxo.retrieve_documents(retriever, 'hello', 3);
```

The seam does not define an embedding model, vector store, ranking service, or
search quality.

## Subagent Delegation

`praxo.subagent_request`, `praxo.subagent_result`, `praxo.subagent_task`, and
`praxo.subagent_run` form a synchronous delegation seam. The runner receives the
request and returns a result; the task status is terminal `completed` or
`failed`. A runner error is preserved as the task error code when it starts with
an uppercase code and a colon, otherwise the task uses `SUBAGENT_ERROR`. An empty
parent session ID or agent ID raises `praxo:delegation` with `SUBAGENT_INVALID`.

```matlab
request = praxo.subagent_request('parent', 'child', 'look up');
runner = @(req) praxo.subagent_result('task-1', req.agentId, 'done');
task = praxo.subagent_run(runner, request);
```

No asynchronous manager, remote worker, or durable scheduling is provided.

## Current Limits

- Numbers are finite double-precision values; large integers and decimal
  spellings may lose precision. Do not use these codecs for values requiring
  exact numeric preservation. Invalid UTF-8, malformed escapes, trailing data,
  and nonfinite numbers are rejected.
- JSON input and output are bounded to 1,048,576 characters and nesting to 64.
  The tool-call helpers reject inputs over 262,144 characters.
- Tool calls cover canonical JSON, XML-style, dotted tags and plain dotted
  lines. Other reference formats such as DSML, invoke, todo and skill-install
  are not implemented. Parsed governance metadata is returned under `metadata`;
  generated call IDs are not provided. Markup stripping is not an authorization
  control or security sanitizer.
- Schema patterns accept a limited anchored ASCII subset, not full RE2.
  Unsupported patterns fail explicitly with `praxo:schema`; pattern input is
  bounded. Unknown JSON Schema keywords follow the documented subset behavior.
- Manifest validation rejects duplicate and unknown fields and validates
  declarations. It does not verify signatures, establish trust, execute
  plugins, or enforce OS sandboxing. Duplicate-field rejection is stricter than
  the Go JSON decoder.
- Core-local errors are not new shared wire error codes. Neither passing all
  eleven vector groups nor an Octave test implies full Framework or Go feature
  parity.

The source is MIT; see [LICENSE](LICENSE). Octave is a separate GPL-licensed
interpreter and test tool, not a package dependency or code copied into this
implementation. MATLAB is a separate proprietary runtime.

See [language policy](../../docs/contributing/language-policy.md),
[parity inventory](../../spec/parity/matlab.md), and
[implementation support](../../docs/languages/support.md).

## Tutorials and Reference Applications

- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the reference-application portfolio.
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and application paths.
- [Reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio) ([中文](https://axisvela.github.io/praxo-core/zh-CN/project/roadmap/)).
- Language tutorials: [language/matlab/Tutorial](https://github.com/axisvela/praxo-core/tree/main/language/matlab/Tutorial).

## Community

- X: <https://x.com/axisvela>
- Weibo: <https://weibo.com/u/1936025761>
- LinkedIn: <https://www.linkedin.com/company/axisvela/>
- Facebook: <https://www.facebook.com/profile.php?id=61596905732406>
- YouTube: <https://www.youtube.com/@axisvela>
- Discord: <https://discord.com/channels/1575163993767809064/1575164343148875977>
- GitHub Discussions: <https://github.com/axisvela/praxo-core/discussions>
- GitHub Issues: <https://github.com/axisvela/praxo-core/issues>
- Documentation: <https://axisvela.github.io/praxo-core/>
- Architect: <https://axisvela.architect.pub>

