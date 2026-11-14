# PRAXO-CORE R Core

R implementation of the PRAXO-CORE contract.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.6.1`
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

## Scope

`0.6.1` implements all eleven conformance vector groups: tool-call parsing, JSON
Schema, plugin manifests, memory, events, stream kinds, checkpoint envelopes,
path policy, context budgets, middleware, the agent loop, and human-in-the-loop
interrupt decisions. OpenAI-compatible, Harmovela, and stdio MCP adapters are
included.

## OpenAI-Compatible Adapter

`R/openaicompat.R` adds a non-streaming OpenAI-compatible adapter over the
native model seam. It posts to `{base_url}/chat/completions` and maps assistant
content, tool calls, and token usage. Supply `transport` to run without network
access; the function receives `(path, payload)` and returns decoded JSON.

```r
adapter <- openai_compatible("https://api.example.com/v1", "model-id",
                             api_key = Sys.getenv("API_KEY"))
result <- openai_compatible_generate(adapter, request(
  messages = list(message(roles$user, "hi"))
))
model <- openai_compatible_model(adapter)
```

Provider HTTP failures raise `praxo_error` with code `PROVIDER_HTTP`; invalid
tool-argument JSON raises `PROVIDER_JSON`. Streaming is not implemented.

## Anthropic and Gemini Adapters

`R/anthropic.R` maps the Anthropic Messages API, and `R/gemini.R` maps the
Gemini generateContent API. Both accept a caller-supplied `transport` for
deterministic tests and fall back to `curl` in normal use.

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

Tag shape: `r/v0.9.0`. The tag targets `SPEC_VERSION` `0.2.0`. r-universe
builds from the repository; CRAN submission uses `R CMD check --as-cran`. See
[PUBLISHING.md](PUBLISHING.md) and [CHANGELOG.md](CHANGELOG.md).
