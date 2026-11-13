# PRAXO-CORE for V

V is a native Core implementation with source tag `v/v0.4.7`. It passes all
eleven shared vector groups with `V 0.5.2` and includes the native
agent loop, context compaction, memory store, path policy, checkpoint
allowlist, and tool-call parsing. Tool selection, PII redaction, structured
output, and call limits are opt-in in the agent. Vector
coverage does not establish full Core parity or production readiness.

The Core does not call Go or another language runtime. It includes non-streaming
OpenAI-compatible, Anthropic, and Gemini model adapters, an OpenTelemetry event
sink, a retriever seam, and synchronous subagent delegation; plugin hosts remain
outside the declared Core scope.

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/v/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/v/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/v/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [VPM (pending)](https://github.com/axisvela/praxo-core-v)

## Build And Test

From the repository root with V and a C compiler on `PATH`:

```bash
python language/v/api-snapshot.py --check
v -cc tcc -gc none -o build/praxo-v-conformance language/v/conformance/run.v
./build/praxo-v-conformance
v -cc tcc -gc none -o build/praxo-v-tests language/v/tests/run.v
./build/praxo-v-tests
```

On Windows use `build\praxo-v-conformance.exe` and
`build\praxo-v-tests.exe`. The `-path` flag is not needed: the compiler
resolves `import praxo` from the language tree.

The complete local environment procedure, including manual V installation,
is in [SETUP.md](SETUP.md).

## API

```v
import praxo

call := praxo.parse_tool_call('<tool_call name="echo">{"text":"hi"}</tool_call>') or {
	panic(err)
}
assert call.name == 'echo'

schema := praxo.parse_json('{"type":"string","pattern":"^a+$"}') or { panic(err) }
assert praxo.validate_schema(schema, praxo.parse_json('"aaa"') or { panic(err) }).len == 0
```

Public declarations are inventoried in [`api/0.4.0.txt`](api/0.4.0.txt).

## OpenAI-Compatible Adapter

`openai_compatible` and `openai_compatible_with_options` build a non-streaming
adapter over the native model seam. It posts to `{base_url}/chat/completions`
and maps assistant content, tool calls, and token usage. Supply `transport` to
run without network access; it receives `(base_url, api_key, path, payload)` and
returns decoded JSON.

```v
adapter := praxo.openai_compatible_with_options('https://api.example.com/v1',
	'model-id', praxo.OpenAIOptions{api_key: 'token'})
result := adapter.generate(praxo.Request{
	messages: [praxo.message(praxo.role_user, 'hi')]
}) or { panic(err) }
model := praxo.openai_compatible_model(adapter)
```

Provider HTTP failures return code `PROVIDER_HTTP`; invalid tool-argument JSON
returns `PROVIDER_JSON`. Streaming is not implemented.

## Anthropic and Gemini Adapters

`anthropic_compatible` posts to `{base_url}/v1/messages` with `x-api-key` and
`anthropic-version`. `gemini_compatible` posts to
`{base_url}/v1beta/models/{model}:generateContent` with `x-goog-api-key`. Both
map system messages, tools, tool calls, tool results, and token usage over the
injected `ProviderTransport`; it receives `(base_url, path, payload, headers)`
and returns decoded JSON. Streaming is not implemented.

```v
claude := praxo.anthropic_compatible_with_options('https://api.anthropic.com',
	'claude-sonnet-4-5', praxo.AnthropicOptions{api_key: 'token'})
gemini := praxo.gemini_compatible_with_options(
	'https://generativelanguage.googleapis.com', 'gemini-2.5-pro',
	praxo.GeminiOptions{api_key: 'token'})
```

Supply a model callback to receive each request and return a response or an
error. The callback can inspect the conversation and tool results on each step;
callback-backed models also work with `fallback_model`.

Set `options.tool_selection = praxo.tool_selection(['echo'])` to advertise and
allow only the named tools. An empty selection denies all tools. Without a
selection, all configured tools remain available. A request for an unselected
tool fails with `AGENT_TOOL_NOT_SELECTED` before the tool is invoked.

Set `options.pii_redaction = true` to redact the existing email, SSN,
credit-card, and US-style phone patterns in model-bound message content and text blocks, and in
tool results recursively. This does not redact tool arguments, events, final
output, block image/data fields, or arbitrary PII; it is not a complete privacy
boundary. The original session messages are not modified.

Set `options.structured_output = praxo.structured_output(schema, max_repairs, repairer)`
to validate the final output with the existing schema helper. A successful repair
becomes the output; invalid output fails with `AGENT_STRUCTURED_OUTPUT`.
Set `options.model_call_limit` and `options.tool_call_limit` to positive values
to bound calls per run. Nonpositive values are unlimited. The next invocation
is blocked with `AGENT_MODEL_CALL_LIMIT` or `AGENT_TOOL_CALL_LIMIT`; counters
are independent for each run. All these options are disabled by default.

```v
fn generate(req praxo.Request) !praxo.Response {
    return praxo.response(praxo.message_assistant('Hello', []praxo.ToolCall{}), praxo.usage(0, 0))
}

options := praxo.agent_options(praxo.callback_model(generate))
result := praxo.run_agent(options, praxo.session('s1', []praxo.Message{}), 'Hi') or { panic(err) }
```

## Harmovela Event Sink

`harmovela_sink` returns a `&Sink` that posts each event to
`POST {base_url}/events` with the documented envelope. `new_harmovela_sink`
exposes the native sink with an error-returning `emit` for direct use. Supply
`transport` to run without network access; it receives `(base_url, path, body,
headers)` and returns a `HarmovelaResponse`. Supply `clock` to return Unix
nanoseconds for deterministic ids and timestamps.

```v
sink := praxo.harmovela_sink('http://127.0.0.1:8790/aep/api',
	praxo.HarmovelaOptions{source: 'praxo-core', spec_version: '0.2'})
mut options := praxo.agent_options(model)
options.events = sink
result := praxo.run_agent(options, praxo.session('s1', []praxo.Message{}), 'hi') or {
	panic(err)
}
```

A 2xx status is success. Other statuses return `HARMOVELA_HTTP`; a missing base
URL returns `HARMOVELA_URL`. When wrapped as a `&Sink`, the last transport error
is stored in `last_error`. The sink adds no authentication, retries, buffering,
ordering, or exactly-once delivery. Use HTTPS and caller-side filtering for
sensitive event data.

## OpenTelemetry Event Sink

`otel_sink` returns a `&Sink` that posts each event as OTLP/HTTP JSON spans.
`new_otel_sink` exposes the native sink with an error-returning `emit` for direct
use. The endpoint is required; a missing endpoint returns `OTEL_URL`. Supply
`transport` to run without network access; it receives `(endpoint, body,
headers)` and returns an `OtelResponse`. Supply `clock` to return Unix
nanoseconds for deterministic ids and timestamps.

Event data is excluded by default. Only keys listed in `allowed_data_keys` are
copied to span attributes. Trace and span ids are deterministic 32- and 16-
character hexadecimal strings derived from the event and clock value.

```v
sink := praxo.otel_sink('https://otel.example.com/v1/traces',
	praxo.OtelOptions{allowed_data_keys: ['tool_name']})
mut options := praxo.agent_options(model)
options.events = sink
result := praxo.run_agent(options, praxo.session('s1', []praxo.Message{}), 'hi') or {
	panic(err)
}
```

A 2xx status is success. Other statuses return `OTEL_HTTP` with a response body
bounded to 512 characters. The sink adds no OpenTelemetry SDK, sampler,
collector, authentication, retries, buffering, or delivery guarantee.

## Retriever Seam

`Document`, `Retriever`, and `FuncRetriever` define a query-and-limit retrieval
seam. `retrieve_documents` validates the limit and invokes the supplied
function. A negative limit returns `RETRIEVER_INVALID`. The seam does not define
an embedding model, vector store, ranking service, or search quality.

```v
retriever := praxo.func_retriever(fn (query string, limit int) ![]praxo.Document {
	return [praxo.document('doc-1', query)]
})
documents := praxo.retrieve_documents(retriever.retrieve, 'hello', 3) or {
	panic(err)
}
```

## Synchronous Subagent Delegation

`subagent_manager` wraps a `SubagentRunner` function. `SubagentManager.run`
builds a `SubagentRequest`, invokes the runner synchronously, and returns a
terminal `SubagentTask` in `completed` or `failed` state. Runner errors are
preserved as the task error code; other errors become `SUBAGENT_ERROR`. An empty
parent session id or agent id returns `SUBAGENT_INVALID`. No asynchronous
manager, remote worker, or durable scheduling is provided.

```v
runner := fn (request praxo.SubagentRequest) !praxo.SubagentResult {
	return praxo.subagent_result('task-1', request.agent_id, 'done')
}
manager := praxo.subagent_manager(runner)
task := manager.run(praxo.subagent_request('parent', 'child', 'look up')) or {
	panic(err)
}
```

## Current Limits

- Verified with `V 0.5.2` and the bundled `tcc` on Windows. Other V releases,
  and `gcc` are not verified; Linux CI runs the same suite.
- JSON is decoded with `x.json2`. Invalid JSON and trailing data are rejected;
  duplicate object keys are not a declared vector and should not be treated as
  a security boundary.
- Tool calls cover canonical JSON, XML-style, dotted tags, and dotted plain
  lines. Generated call IDs are not provided. Markup stripping is not an
  authorization control or sanitizer.
- Run IDs combine nanosecond time with a random suffix. They are not a
  guaranteed global identifier.
- Schema patterns use the V `regex` module. Unsupported patterns are reported
  as schema errors rather than silently accepted.
- Path checks are lexical and confined by separator boundaries. They do not
  resolve symlinks or replace operating-system sandboxing.
- Streaming wire encodings and plugin hosts are not part of this Core.

The source is MIT; see [LICENSE](LICENSE). V and its bundled toolchain are
separate projects, not vendored code.

## Distribution

The VPM mirror is `axisvela/praxo-core-v` with package name `praxo-core` and
plain tag `0.1.2`. Imports still use `import praxo`. VPM submission is pending;
see [PUBLISHING.md](PUBLISHING.md).

See [language policy](../../docs/contributing/language-policy.md),
[parity inventory](../../spec/parity/v.md), and
[implementation support](../../docs/languages/support.md).
