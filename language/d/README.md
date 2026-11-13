# PRAXO-CORE D Core

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its
native D Core: an agent loop with tool registration and dispatch, policy hooks,
typed events, memory, checkpoints, context budgets, middleware, JSON Schema
validation, and plugin manifest parsing.

The normative contract is [`spec/`](../../spec/README.md); Go remains the
reference implementation.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.4.0`
- Tier: core
- License: MIT
- Dependencies: D standard library only
- Published on DUB/code.dlang.org as `praxo-core@0.1.0`

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/d/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/d/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/d/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [DUB](https://code.dlang.org/packages/praxo-core)

## Install

```bash
dub add praxo-core
```

## Scope

The Core implements all eleven vector groups: toolcall, JSON Schema, plugin,
memory, event, stream, checkpoint, policy, context, middleware, and the agent
loop. It includes a public API snapshot and a test runner.

## Build and test

```bash
mkdir -p build
dmd -i -Isource -O -release source/conformance.d -of=build/conformance
./build/conformance
dmd -i -Isource -O -release source/tests.d -of=build/tests
./build/tests
python api-snapshot.py --check
```

## Quickstart

```d
import praxo.agent;
import praxo.models;

void main() {
    auto options = new AgentOptions(new StaticModel("hello"));
    auto result = runAgent(options, Session("demo"), "hello");
    writeln(result.output);
}
```

Tools register on the options object:

```d
auto registry = new Registry();
registry.register(new FuncTool("echo", "Echo arguments", (arguments) => arguments));
options.tools = registry;
```

## Model Adapters

- `OpenAICompatibleModel` for OpenAI, DeepSeek, Kimi/Moonshot, and other
  OpenAI-compatible endpoints.
- `AnthropicModel` for the Anthropic Messages API.
- `GeminiModel` for the Gemini generateContent API.

Each adapter accepts a `ProviderTransport` delegate for deterministic tests.

## Harmovela Event Sink

`HarmovelaSink` implements the native `EventSink` seam. It posts each event to
`POST {baseUrl}/events` with the documented envelope. Supply `transport` to run
without network access; it receives `(baseUrl, path, body, headers)` and returns
a `HarmovelaResponse`. Supply `clock` to return `(seconds, nanos)` for
deterministic ids and timestamps.

```d
import praxo.agent;
import praxo.harmovela;
import praxo.models;

auto sink = new HarmovelaSink("http://127.0.0.1:8790/aep/api");
auto options = new AgentOptions(new StaticModel("hello"));
options.events = sink;
auto result = runAgent(options, Session("demo"), "hello");
```

A 2xx status is success. Any other status throws `PraxoError` with code
`HARMOVELA_HTTP`; a missing base URL throws `HARMOVELA_URL`. The sink adds no
authentication, retries, buffering, ordering, or exactly-once delivery. Use
HTTPS and caller-side filtering for sensitive event data. The default transport
invokes `curl`; tests should inject a transport.

## OpenTelemetry Event Sink

`OtelSink` implements the native `EventSink` seam and posts OTLP/HTTP spans to a
required endpoint. Supply `transport` to receive `(endpoint, body, headers)` and
return an `OtelResponse`; supply `clock` to return nanoseconds for deterministic
ids and timestamps. Event data is excluded unless a key is listed in
`allowedDataKeys`.

A 2xx status is success. Any other status throws `PraxoError` with code
`OTEL_HTTP` and a bounded response body; a missing endpoint throws `OTEL_URL`.
Trace ids are deterministic 32-character hex values and span ids are 16-character
hex values. No OpenTelemetry SDK is required, and the sink does not add sampling,
retries, or buffering.

## Retriever

`praxo.retriever` defines `Document` (id, content, metadata, score), a
`Retriever` function alias, `FuncRetriever`, and `retrieveDocuments`. A negative
limit throws `PraxoError` with code `RETRIEVER_INVALID`. The seam does not depend
on an embedding model or vector database.

## Subagent Delegation

`praxo.delegation` defines `SubagentRequest`, `SubagentResult`, `SubagentTask`,
and a synchronous `SubagentManager`. A completed task has status `completed`; a
runner failure yields status `failed` and preserves the `PraxoError` code in
`task.error`. Empty parent session or agent ids throw `SUBAGENT_INVALID`. No
asynchronous manager or durable worker is required.

## Layout

- `source/praxo/` package modules.
- `source/conformance.d` vector runner.
- `source/tests.d` test runner.
- `api-snapshot.py` and `api/` public API snapshot.

## Release

Tag shape: `d/v0.4.0`. The tag targets `SPEC_VERSION` `0.2.0`.
