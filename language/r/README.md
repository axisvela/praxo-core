# PRAXO-CORE R Core

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its
native R Core: an in-process agent loop with tools, policy, events, memory,
checkpoints, middleware, and JSON Schema validation, implemented in base R.

Use it when an existing R analysis or automation script needs a governed
model/tool loop without moving orchestration into Python. It is not an HTTP user
agent, crawler, hosted agent service, or model provider.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.11.0`
- Tier: core
- License: MIT
- Dependencies: none (base R JSON parser/serializer)

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/r/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/r/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/r/llms.md)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/r/examples): runnable language-specific examples.
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [r-universe](https://axisvela.r-universe.dev/praxocore)
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761)

## Get started

Install the published package:

```r
install.packages("praxocore", repos = "https://axisvela.r-universe.dev")
```

Then run the smallest deterministic example:

- [Consumer starter](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/consumer): explicit tool scope and a deny check.
- [Live model](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/live-model): connect an OpenAI-compatible endpoint and register `get_time`.

See the [R documentation](https://axisvela.github.io/praxo-core/languages/r/) for the full API and the
[language matrix](https://axisvela.github.io/praxo-core/languages/matrix/) for
current scope.

## Examples

Runnable examples live under [`language/r/examples`](https://github.com/axisvela/praxo-core/tree/main/language/r/examples).

| Goal | Example |
| --- | --- |
| Install and deny one unsafe call | [consumer](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/consumer) |
| Connect a real model | [live-model](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/live-model) |
| Connect MCP tools | [mcp](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/mcp) |
| Validate structured output | [structured-output](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/structured-output) |
| Stream a response | [streaming](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/streaming) |
| Add identity and policy | [identity-policy](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/identity-policy) |
| Persist checkpoints | [checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/checkpoint) |
| Run behind HTTP | [service](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/service) |
| Approve or edit a tool call | [hitl](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/hitl) |
| Resume a multi-turn session | [session-checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/session-checkpoint) |
| Retry transient failures | [retry](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/retry) |
| Add provider fallback | [provider-fallback](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/provider-fallback) |
| Observe agent events | [event-sink](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/event-sink) |

## Scope

`0.11.0` implements all eleven conformance vector groups: tool-call parsing, JSON
Schema, plugin manifests, memory, events, stream kinds, checkpoint envelopes,
path policy, context budgets, middleware, the agent loop, and human-in-the-loop
interrupt decisions. OpenAI-compatible, Harmovela, and stdio MCP adapters are
included.

## Quickstart

```r
model <- function(request) response(message(roles$assistant, "hello"))
result <- agent_run(model, "hi")
cat(result$output)
```

Tools are ordinary lists with `name`, `description`, optional `parameters`, and
an `invoke` function. Pass `session = session(id, messages = ...)` to continue a
conversation; `result$messages` contains the updated history.

See [`examples/consumer`](examples/consumer) for a deterministic allow/deny
starter and [`examples/live-model`](examples/live-model) for an OpenAI-compatible
endpoint.

## OpenAI-Compatible Adapter

`R/openaicompat.R` adds an OpenAI-compatible adapter over the native model
seam. It posts to `{base_url}/chat/completions` and maps assistant content, tool
calls, and token usage. Supply `transport` to run without network access; the
function receives `(path, payload)` and returns decoded JSON.
`openai_compatible_streaming_model()` returns a `(request, on_delta)` function
for `agent_run(streaming_model = ...)`. Supply `stream_transport` returning SSE
text, or let `curl` read the stream. Streaming tool-call fragments, usage, and
`finish_reason` are reassembled into the final response.

```r
adapter <- openai_compatible("https://api.example.com/v1", "model-id",
                             api_key = Sys.getenv("API_KEY"))
result <- openai_compatible_generate(adapter, request(
  messages = list(message(roles$user, "hi"))
))
model <- openai_compatible_model(adapter)
```

Provider HTTP failures raise `praxo_error` with code `PROVIDER_HTTP`; invalid
tool-argument JSON raises `PROVIDER_JSON`; truncated or malformed streams raise
`MODEL_STREAM`.

## Anthropic and Gemini Adapters

`R/anthropic.R` maps the Anthropic Messages API, and `R/gemini.R` maps the
Gemini generateContent API. Both accept a caller-supplied `transport` for
deterministic tests and fall back to `curl` in normal use.
`anthropic_streaming_model()` uses `stream_transport` and reassembles
`message_start`/`text_delta`/`input_json_delta`/`message_delta`/`message_stop`.

```r
claude <- anthropic(model = "claude-sonnet-4-5", api_key = Sys.getenv("ANTHROPIC_API_KEY"))
gemini_model <- gemini(model = "gemini-2.5-pro", api_key = Sys.getenv("GEMINI_API_KEY"))
```

## MCP Client

`R/mcp.R` implements the JSON-RPC 2.0 MCP client boundary over a caller-supplied
transport: `initialize` / `notifications/initialized`, paginated `tools/list`
with repeated-cursor and duplicate-name rejection, `inputSchema` preservation,
and `tools/call` structured or text content mapping. Errors use `praxo_error`
codes `MCP_PROTOCOL`, `MCP_TRANSPORT`, `MCP_HANDSHAKE`, `MCP_PAGINATION`,
`MCP_DUPLICATE_TOOL`, `MCP_TOOL_ERROR`, `MCP_RPC`, `MCP_TIMEOUT`, `MCP_CLOSED`,
and `MCP_CANCELLED`.

```r
client <- mcp_client(transport, timeout = 30)
tools <- mcp_register_tools(client)
result <- agent_run(model, "hi", tools = tools)
mcp_close(client)
```

`mcp_register_tools` returns ordinary Core tool lists, so `agent_run` still
authorizes every `tool.invoke` action and applies policy and allowlists.

Blocker: base R has no persistent bidirectional stdio child. `mcp_stdio_transport`
therefore raises `MCP_TRANSPORT` instead of silently adding a dependency. Supply
a transport backed by a package such as `processx`, or an in-memory transport for
tests. Limits: no remote transport, authentication, or sandbox isolation; MCP
output is untrusted content. Timeouts send `notifications/cancelled`, and a
caller cancellation callback sends the same notification and raises
`MCP_CANCELLED`.

## Harmovela Event Sink

`R/harmovela.R` adds a native sink that posts lifecycle events to
`{base_url}/events` as JSON envelopes with `spec_version`, `id`, `type`,
`source`, `created_at`, and a payload that merges the event data with
`session_id` and `run_id` when present.

```r
sink <- harmovela_sink("http://127.0.0.1:8790/aep/api")
agent_run(model, "hi", events = sink)
```

Supply `transport` to run without network access; it receives `(path,
envelope)` and returns `list(status, body)`. Limits: the sink adds no
authentication, retries, buffering, acknowledgements, ordering, or exactly-once
delivery. Filter sensitive event data at the caller, and use HTTPS for remote
endpoints.

## Build and test

```bat
Rscript r\conformance\run.R
Rscript r\api-snapshot.R --check
Rscript r\tests\run_tests.R
```

Local toolchain used by the repository maintainers lives at `D:\dev\R`.

## Layout

- `R/` package source.
- `conformance/run.R` vector runner.
- `api-snapshot.R` and `api/` public API snapshot.
- `tests/run_tests.R` dependency-free tests.

## Release

Tag shape: `r/v0.11.0`. The tag targets `SPEC_VERSION` `0.2.0`. r-universe
builds from the repository; CRAN submission uses `R CMD check --as-cran`. See
[PUBLISHING.md](PUBLISHING.md) and [CHANGELOG.md](CHANGELOG.md).
