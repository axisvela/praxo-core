# PRAXO-CORE Erlang Core

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its
native Erlang Core with source tag `erlang/v0.4.0`. It passes all eleven shared
vector groups on Erlang/OTP 29 and includes the native agent loop, memory store,
checkpoint allowlist, lexical path policy, context compaction, event sinks,
middleware helpers, tool selection, and human-in-the-loop interrupt decisions.
It does not call Go or another Core.

- Implementation type: Core.
- Package version: `0.4.0`; supported `SPEC_VERSION`: `0.2.0`.
- Hex package name: `praxo_core_erlang`; OTP application name: `praxo_core`.
- The Hex package is `praxo_core_erlang@0.4.0`; `0.3.1` and `0.2.0` remain available.
- Toolchain: Erlang/OTP 29 or newer. JSON uses the OTP `json` module.

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/erlang/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/erlang/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/erlang/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [Hex](https://hex.pm/packages/praxo_core_erlang/0.4.0)

## Install

```erlang
{deps, [{praxo_core_erlang, "0.4.0"}]}.
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

`praxo_openai_compatible` provides a non-streaming adapter over the native model
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
tool-argument JSON returns `PROVIDER_JSON`. Streaming is not implemented.

Public declarations are inventoried in [`api/0.4.0.txt`](api/0.4.0.txt).
This is a source declaration check, not a binary ABI promise. Regenerate it with
`python api-snapshot.py`.

## Anthropic and Gemini Adapters

`praxo_anthropic` and `praxo_gemini` map the native Messages and generateContent
APIs. Both accept a caller-supplied transport for deterministic tests.

```erlang
Anthropic = praxo_anthropic:new(<<"claude-sonnet-4-5">>, <<"ak">>),
Gemini = praxo_gemini:new(<<"gemini-2.5-pro">>, <<"gk">>),
```

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
