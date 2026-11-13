# PRAXO-CORE Julia Core

Julia implementation of the PRAXO-CORE contract.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.5.0`
- Tier: core
- License: MIT
- Dependency: JSON.jl

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/julia/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/julia/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/julia/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [Julia General (pending)](https://github.com/axisvela/praxo-core-julia)

## Scope

`0.5.0` implements all eleven conformance vector groups: tool-call parsing, JSON
Schema, plugin manifests, memory, events, stream kinds, checkpoint envelopes,
path policy, context budgets, middleware, and the agent loop. Non-streaming
OpenAI-compatible, Anthropic, and Gemini model adapters, plus an OpenTelemetry
event sink, are available under `src/adapters/`.

## OpenAI-Compatible Adapter

`OpenAICompatibleModel` implements the native `AbstractModel` seam. It posts to
`{base_url}/chat/completions` and maps assistant content, tool calls, and token
usage. Supply `transport` to run without network access; it receives
`(path, payload)` and returns decoded JSON.

```julia
adapter = openai_compatible("https://api.example.com/v1", "model-id";
                            api_key = "token")
result = generate(adapter, Request([Message(Roles.USER, "hi")]))
```

Provider HTTP failures raise `PraxoError` with code `PROVIDER_HTTP`; invalid
tool-argument JSON raises `PROVIDER_JSON`. Streaming is not implemented.

## Anthropic and Gemini Adapters

`AnthropicModel` and `GeminiModel` implement the native `AbstractModel` seam for
the Messages and generateContent APIs. Both accept `transport` receiving
`(path, payload)` and return decoded JSON.

```julia
claude = anthropic("https://api.anthropic.com", "claude-sonnet-4-5"; api_key = "ak")
gemini_model = gemini("https://generativelanguage.googleapis.com", "gemini-2.5-pro"; api_key = "gk")
```

## Harmovela Event Sink

`harmovela_sink` implements the native `AbstractSink` seam. It posts each event
to `POST {base_url}/events` with the documented envelope. Supply `transport` to
run without network access; it receives `(path, body, headers)` and returns a
named tuple with `status` and `body`. Supply `clock` to return `(seconds,
nanos)` for deterministic ids and timestamps.

```julia
sink = harmovela_sink("http://127.0.0.1:8790/aep/api";
                      source = "praxo-core", spec_version = "0.2")
options = AgentOptions(model)
options.events = sink
```

A 2xx status is success. Other statuses raise `PraxoError` with code
`HARMOVELA_HTTP`; a missing base URL raises `HARMOVELA_URL`. The sink adds no
authentication, retries, buffering, ordering, or exactly-once delivery. Use
HTTPS and caller-side filtering for sensitive event data.

## OpenTelemetry Event Sink

`otel_sink` implements the native `AbstractSink` seam and posts OTLP/HTTP spans
to the caller-supplied endpoint. Supply `transport` to run without network
access; it receives `(endpoint, body, headers)` and returns a named tuple with
`status` and `body`. Supply `clock` to return `(seconds, nanos)` for
deterministic ids and timestamps.

```julia
sink = otel_sink(
    "http://127.0.0.1:4318/v1/traces";
    service_name = "praxo-core",
    allowed_data_keys = ["name"],
)
options.events = sink
```

Event data is excluded unless its keys appear in `allowed_data_keys`. Trace and
span IDs are deterministic; a missing endpoint raises `OTEL_URL`. A 2xx status
is success. Other statuses raise `PraxoError` with code `OTEL_HTTP` and a
bounded response body. No OpenTelemetry SDK is required.

## Retriever

`Document`, `Retriever`, `FuncRetriever`, and `retrieve_documents` form the
retriever seam. A retriever is a function receiving `(query, limit)` and
returning documents.

```julia
retriever = func_retriever(
    (query, limit) -> [Document("doc-1", query, Dict("source" => "test"), 0.5)],
)
documents = retrieve_documents(retriever, "query", 5)
```

A negative limit raises `PraxoError` with code `RETRIEVER_INVALID`.

## Delegation

`subagent_run` invokes a `SubagentRunner` synchronously and returns a terminal
`SubagentTask` with `completed` or `failed` status. A `PraxoError` code is
preserved in `task.error`; other failures use `SUBAGENT_ERROR`.

```julia
request = subagent_request("parent", "child", "prompt")
task = subagent_run(
    request -> subagent_result(agent_id = request.agent_id, output = "done"),
    request,
)
```

An empty parent session or agent ID raises `PraxoError` with code
`SUBAGENT_INVALID`.

## Build and test

```bash
julia --project=language/julia -e 'using Pkg; Pkg.instantiate()'
julia --project=language/julia language/julia/conformance/run.jl
julia --project=language/julia language/julia/api-snapshot.jl --check
julia --project=language/julia language/julia/test/runtests.jl
```

Local toolchain used by the repository maintainers lives at `D:\dev\julia`.

## Layout

- `src/` package source.
- `conformance/run.jl` vector runner.
- `api-snapshot.jl` and `api/` public API snapshot.
- `test/runtests.jl` Julia test suite.

## Release

Tag shape: `julia/v0.5.0`. The tag targets `SPEC_VERSION` `0.2.0`. The mirror `axisvela/praxo-core-julia` registers the package through
JuliaRegistrator; see [PUBLISHING.md](PUBLISHING.md).
