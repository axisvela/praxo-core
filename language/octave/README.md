# PRAXO-CORE for GNU Octave

Native Octave Core for the PRAXO-CORE agent framework. This is the independent
Octave package root and source tag `octave/v0.5.0`; it shares the implementation
in `language/matlab-octave-core/+praxo` with the MATLAB package. It passes all
eleven shared vector groups under GNU Octave 11.3.0 and includes the native agent
loop, memory store, checkpoint allowlist, lexical path policy, context
compaction, event sinks, middleware helpers, tool selection, an OpenTelemetry
transport-seam sink, a retriever seam, and synchronous subagent delegation. It
does not delegate behavior to Go or another language Core.

MATLAB is a separate Core target in `language/matlab`; Octave package
publication does not claim MATLAB runtime verification.

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/octave/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/octave/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/octave/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [Octave Packages](https://github.com/axisvela/praxo-core/releases/download/octave/v0.2.1/praxo-core-0.2.1.tar.gz)
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761)

## Install

```octave
pkg install https://github.com/axisvela/praxo-core/releases/download/octave/v0.2.1/praxo-core-0.2.1.tar.gz
pkg load praxo-core
```

After the Octave Packages entry is merged:

```octave
pkg install -forge praxo-core
pkg load praxo-core
```

## Run the Checks

With Python 3.10+ and an Octave CLI available, from the repository root:

```bash
python language/octave/run-tests.py
python language/octave/api-snapshot.py --check
```

Set `OCTAVE` or pass `--octave /path/to/octave-cli` to select the interpreter.
Python only launches the native tests and checks the source API inventory. The
implementation and tests run in Octave, not Python. The runner covers all eleven
shared vector groups and verifies each fixture's group and `SPEC_VERSION` before
running it.

The Octave package archive is built with:

```bash
python language/octave/build_octave_package.py
```

It contains `DESCRIPTION`, `inst/+praxo`, `LICENSE`, and `README.md`.

## API

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
in character vectors.

## OpenAI-Compatible Adapter

`praxo.openai_compatible(request, options)` posts to
`{baseUrl}/chat/completions`, maps assistant content, tool calls, usage, and
finish reason, and parses call arguments into typed JSON objects. Set
`options.transport` to a function handle returning `status` and `body` for
deterministic tests. The default transport uses `webwrite`. Missing base URLs
and non-2xx responses raise `praxo:provider` with a `PROVIDER_HTTP` code;
invalid tool arguments use `PROVIDER_JSON`. Streaming is not implemented.

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

Options `maxSteps` and `maxTokens` default to 8 and 0 respectively; zero tokens
means unlimited, and steps must be positive. The result contains `output`,
`steps`, token counts, ordered event names, `toolInvocations`, `messages`,
`errorCode`, and `errorMessage`. An empty `errorCode` indicates success.
Budget failures use `AGENT_MAX_STEPS` or `AGENT_MAX_TOKENS`; missing tools use
`TOOL_NOT_FOUND`, while invalid or failing model and tool callbacks use local
`MODEL_ERROR` and `TOOL_ERROR`. Invalid configuration raises `praxo:agent`.

## Anthropic and Gemini Adapters

praxo.anthropic_compatible(request, options) and
praxo.gemini_compatible(request, options) map the native Messages and
generateContent APIs. Both accept an injected 	ransport for deterministic
tests.

## Harmovela Event Sink

```octave
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

## OpenTelemetry Sink

```octave
clock = @() struct('epochNanos', '1794294000000000000', ...
    'createdAt', '2026-11-10T07:00:00.000000000Z');
sink = praxo.otel_sink('http://127.0.0.1:4318/v1/traces', ...
    'praxo-core', {'name'}, transport, clock);
sink = praxo.otel_emit(sink, event);
```

`praxo.otel_emit` maps a Core event to one OTLP/HTTP span with deterministic
32-character trace and 16-character span IDs. The endpoint is required. Event
data is excluded unless a key is listed explicitly in the allowlist. A 2xx
status is success; other statuses raise `praxo:otel` with an `OTEL_HTTP` code
and a bounded response body. A missing endpoint raises `OTEL_URL`. The sink uses
no OpenTelemetry SDK and adds no collector, sampler, exporter, or retry
behavior.

## Retriever

```octave
document = praxo.document('doc-1', 'hello', struct('source', 'test'), 0.5);
retriever = praxo.func_retriever(@(query, limit) {document});
documents = praxo.retriever_retrieve(retriever, 'hello', 3);
```

Documents are structs with `id`, `content`, `metadata`, and `score`; use
`praxo.document_wire` for a typed JSON node. The retriever seam accepts a
function handle receiving a query and limit. A negative or invalid limit raises
`praxo:retriever` with `RETRIEVER_INVALID`. The seam does not define embeddings,
vector storage, ranking quality, or a production search service.

## Subagent Delegation

```octave
request = praxo.subagent_request('parent', 'child', 'look up', 'fork');
task = praxo.subagent_run( ...
    @(req) praxo.subagent_result('done', 'task-1', 'child'), request);
```

`praxo.subagent_run` executes a caller-supplied child runner synchronously and
returns a task in the terminal `completed` or `failed` state. A failed task
preserves the runner's error code. An empty parent session or agent ID raises
`praxo:delegation` with `SUBAGENT_INVALID`. The seam provides no asynchronous
queue, remote worker, cancellation, update, or exactly-once guarantee.

## Current Limits

- Numbers are finite double-precision values; large integers and decimal
  spellings may lose precision.
- JSON input and output are bounded to 1,048,576 characters and nesting to 64.
  The tool-call helpers reject inputs over 262,144 characters.
- Tool calls cover canonical JSON, XML-style, dotted tags and plain dotted
  lines. Other reference formats such as DSML, invoke, todo and skill-install
  are not implemented. Parsed governance metadata is returned under `metadata`;
  generated call IDs are not provided.
- Schema patterns accept a limited anchored ASCII subset, not full RE2.
  Unsupported patterns fail explicitly with `praxo:schema`.
- Manifest validation rejects duplicate and unknown fields and validates
  declarations. It does not verify signatures, establish trust, execute
  plugins, or enforce OS sandboxing.
- Core-local errors are not new shared wire error codes. Passing all eleven
  vector groups does not imply full Framework or Go feature parity.

The source is MIT; see [LICENSE](LICENSE). Octave is a separate GPL-licensed
interpreter and test tool, not a package dependency or copied code.

See [language policy](../../docs/contributing/language-policy.md),
[parity inventory](../../spec/parity/octave.md), and
[implementation support](../../docs/languages/support.md).
