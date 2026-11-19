# PRAXO-CORE Erlang Core

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its
native Erlang Core with source tag `erlang/v0.9.0`. It passes all eleven shared
vector groups on Erlang/OTP 29 and includes the native agent loop, memory store,
checkpoint allowlist, lexical path policy, context compaction, event sinks,
middleware helpers, tool selection, and human-in-the-loop interrupt decisions.
It does not call Go or another Core.

- Implementation type: Core.
- Package version: `0.8.2`; supported `SPEC_VERSION`: `0.2.0`.
- Hex package name: `praxo_core_erlang`; OTP application name: `praxo_core`.
- The Hex package is `praxo_core_erlang@0.8.2`.
- Toolchain: Erlang/OTP 29 or newer. JSON uses the OTP `json` module.

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/erlang/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/erlang/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/erlang/llms.md)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples): runnable language-specific examples.
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [Hex](https://hex.pm/packages/praxo_core_erlang/0.8.2)
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761)

## Get started

Install the published package:

```bash
{praxo_core, "0.8.2", {pkg, praxo_core_erlang}}
```

Then run the smallest deterministic example:

- [Consumer starter](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/consumer): explicit tool scope and a deny check.
- [Live model](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/live-model): connect an OpenAI-compatible endpoint and register `get_time`.

See the [Erlang documentation](https://axisvela.github.io/praxo-core/languages/erlang/) for the full API and the
[language matrix](https://axisvela.github.io/praxo-core/languages/matrix/) for
current scope.

## Examples

Runnable examples live under [`language/erlang/examples`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples).

| Goal | Example |
| --- | --- |
| Install and deny one unsafe call | [consumer](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/consumer) |
| Connect a real model | [live-model](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/live-model) |
| Connect MCP tools | [mcp](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/mcp) |
| Validate structured output | [structured-output](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/structured-output) |
| Stream a response | [streaming](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/streaming) |
| Add identity and policy | [identity-policy](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/identity-policy) |
| Persist checkpoints | [checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/checkpoint) |
| Run behind HTTP | [service](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/service) |
| Approve or edit a tool call | [hitl](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/hitl) |
| Resume a multi-turn session | [session-checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/session-checkpoint) |
| Retry transient failures | [retry](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/retry) |
| Add provider fallback | [provider-fallback](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/provider-fallback) |
| Observe agent events | [event-sink](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/event-sink) |

## Install

```erlang
{deps, [{praxo_core, "0.8.2", {pkg, praxo_core_erlang}}]}.
```

- Local gate: eleven vector groups, native regression tests, API snapshot, and
  parity inventory.

## Build and Test

From the repository root:

```bash
python language/erlang/run-tests.py
python language/erlang/api-snapshot.py --check
```

Set `ERLC` and `ERL` to select the compiler and runtime. The Python runner only
launches `erlc`, `erl`, and the API checks; the implementation and tests are
Erlang. Build output stays under `language/erlang/build/ebin/`.

To build manually from `language/erlang/`:

```bash
erlc -I src -o build/ebin src/*.erl conformance/*.erl tests/*.erl
erl -noshell -pa build/ebin -eval "praxo_conformance:main()." -s init stop
erl -noshell -pa build/ebin -eval "praxo_tests:run()." -s init stop
```

## Usage

```erlang
Model = praxo_agent:static_model(<<"hello">>),
Options = praxo_agent:new_agent_options(Model),
{ok, Result, _Options} =
    praxo_agent:run_agent(Options, praxo_models:session(<<"demo">>), <<"hello">>),
io:format("~s~n", [maps:get(output, Result)]).
```

## OpenAI-Compatible Adapter

`praxo_openai_compatible` provides an adapter over the native model
seam. It posts to `{base_url}/chat/completions` and maps assistant content, tool
calls, and token usage. Inject `transport` to run without network access; it
receives `(Path, Payload)` and returns `{ok, DecodedJson}`.

```erlang
Adapter = praxo_openai_compatible:new(
    <<"https://api.example.com/v1">>, <<"model-id">>,
    #{api_key => <<"token">>}),
Request = praxo_models:request([praxo_models:message(<<"user">>, <<"hi">>)]),
{ok, Response, _} = praxo_openai_compatible:generate(Adapter, Request),
Model = praxo_openai_compatible:model(Adapter).
```

Provider HTTP failures return `{error, <<"PROVIDER_HTTP">>, Adapter}`; invalid
tool-argument JSON returns `PROVIDER_JSON`.

`streaming_model/1` returns a model map with `generate` and `stream` entries.
`generate_stream/3` sets `stream: true`, parses SSE through
`praxo_sse:parse_response/2`, reassembles content, fragmented tool calls, usage,
and `finish_reason`, and invokes the delta callback. Inject `stream_transport`
returning raw SSE text to run without network access; the bundled `httpc` path
buffers the complete response body. Set `on_delta` in the agent options to use
the streaming path.

Public declarations are inventoried in [`api/0.4.0.txt`](api/0.4.0.txt).
This is a source declaration check, not a binary ABI promise. Regenerate it with
`python api-snapshot.py`.

## Anthropic and Gemini Adapters

`praxo_anthropic` maps the native Messages API with `streaming_model/1` SSE\nreassembly. `praxo_gemini` maps generateContent
APIs. Both accept a caller-supplied transport for deterministic tests.

```erlang
Anthropic = praxo_anthropic:new(<<"claude-sonnet-4-5">>, <<"ak">>),
Gemini = praxo_gemini:new(<<"gemini-2.5-pro">>, <<"gk">>),
```

## MCP Client

praxo_mcp implements a stdio JSON-RPC MCP session with initialize, paginated
tool listing, tool calls, timeouts, cancellation notifications, and an
injectable transport for deterministic tests.

## Harmovela Event Sink

`praxo_harmovela` posts each event to `{base_url}/events`.

```erlang
Sink = praxo_harmovela:new(<<"http://127.0.0.1:8790/aep/api">>),
Event = praxo_models:event(<<"tool.call">>, <<"s1">>, <<"run-1">>, #{<<"name">> => <<"echo">>}),
ok = praxo_harmovela:emit(Sink, Event).
```

The returned map is also a `praxo_sink` sink, so `events => Sink` works with the
agent loop. Inject `transport` (and `clock`) in the options map to test without
a network. A 2xx status returns `ok`; other statuses return
`{error, {http_status, Status, BoundedBody}}` from `praxo_harmovela:emit/2`.
The sink adds no authentication, retries, buffering, ordering, or exactly-once
delivery. Use HTTPS and filter sensitive event data first.

## Process plugin host

`praxo_plugin_process` speaks the framework JSON-Lines process plugin protocol
with token authentication, health handshake, invocation timeout, cooperative
cancel, and typed call errors.
## Current Limits

- The verified target is Erlang/OTP 29. Older releases without the `json`
  module are not supported.
- No HTTP streaming runtime, plugin host, or persistent session store is
  provided. The loop is synchronous; tool batches can execute in spawned
  processes when `max_parallel_tools` is greater than one.
- Optional `cancellation`, `on_stream`, and `max_parallel_tools` agent options
  add cooperative cancellation, stream parts, and bounded parallel tool
  execution. `praxo_sse:parse/1` rejects truncated and half-packet streams.
- PII redaction, structured output, per-run call limits, and tool selection are
  opt-in and integrated into the agent loop.
- Path checks are lexical and do not resolve symlinks or reparse points; they
  are not an OS containment boundary.
- Model and tool callbacks are caller-supplied functions. Callback exceptions
  are not converted to contract errors.
- Core-local errors and exception terms are not new shared wire error codes.
  Passing the vectors does not establish full Core parity or production
  readiness.

The source is MIT; see [LICENSE](LICENSE). Erlang/OTP is a separate toolchain,
not vendored code.

See [CHANGELOG.md](CHANGELOG.md) for per-release changes and compatibility notes.

See [language policy](../../docs/contributing/language-policy.md),
[parity inventory](../../spec/parity/erlang.md),
[SETUP.md](SETUP.md), and
[implementation support](../../docs/languages/support.md).
