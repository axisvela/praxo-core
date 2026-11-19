# PRAXO-CORE Ruby Core

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This gem is its
native Ruby Core: an agent loop with tool registration and dispatch, policy
hooks, typed events, memory, checkpoints, context budgets, middleware, JSON
Schema validation, and plugin manifest parsing.

Use it when an existing Ruby application needs a governed model/tool loop
without adding a sidecar in another language. It is not an HTTP user agent,
crawler, hosted agent service, or model provider.

The normative contract is [`spec/`](../../spec/README.md); Go remains the
reference implementation.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.8.2`
- Tier: core
- License: MIT
- Dependencies: Ruby standard library only
- Ruby source repository: https://github.com/axisvela/praxo-core-ruby
- The latest RubyGems package is `praxo-core@0.8.2`

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/ruby/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/ruby/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/ruby/llms.md)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples): runnable language-specific examples.
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [RubyGems](https://rubygems.org/gems/praxo-core/versions/0.8.2)
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761)

## Get started

Install the published package:

```bash
gem install praxo-core
```

Then run the smallest deterministic example:

- [Consumer starter](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/consumer): explicit tool scope and a deny check.
- [Live model](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/live-model): connect an OpenAI-compatible endpoint and register `get_time`.

See the [Ruby documentation](https://axisvela.github.io/praxo-core/languages/ruby/) for the full API and the
[language matrix](https://axisvela.github.io/praxo-core/languages/matrix/) for
current scope.

## Examples

Runnable examples live under [`language/ruby/examples`](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples).

| Goal | Example |
| --- | --- |
| Install and deny one unsafe call | [consumer](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/consumer) |
| Connect a real model | [live-model](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/live-model) |
| Connect MCP tools | [mcp](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/mcp) |
| Validate structured output | [structured-output](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/structured-output) |
| Stream a response | [streaming](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/streaming) |
| Add identity and policy | [identity-policy](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/identity-policy) |
| Persist checkpoints | [checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/checkpoint) |
| Run behind HTTP | [service](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/service) |
| Approve or edit a tool call | [hitl](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/hitl) |
| Resume a multi-turn session | [session-checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/session-checkpoint) |
| Retry transient failures | [retry](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/retry) |
| Add provider fallback | [provider-fallback](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/provider-fallback) |
| Observe agent events | [event-sink](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/event-sink) |

## Install

```bash
gem install praxo-core
```

## Scope

The Core implements all eleven vector groups: toolcall, JSON Schema, plugin,
memory, event, stream, checkpoint, policy, context, middleware, and the agent
loop. It also implements human-in-the-loop interrupt decisions, and includes a
public API snapshot and a dependency-free test runner.

## Build and test

```bash
ruby language/ruby/conformance/run.rb
ruby language/ruby/api-snapshot.rb --check
ruby language/ruby/tests/run.rb
```

## Quickstart

```ruby
$LOAD_PATH.unshift('language/ruby/lib')
require 'praxo'

model = Praxo::Agent::StaticModel.new('hello')
options = Praxo::Agent::AgentOptions.new(model)
result = Praxo::Agent.run_agent(
  options,
  Praxo::Models.session(id: 'demo'),
  'hello'
)
puts result.output
```

Tools register on the options object:

```ruby
registry = Praxo::Agent::ToolRegistry.new
registry.register(Praxo::Agent::FuncTool.new('echo', 'Echo arguments',
                                             ->(arguments) { arguments }))
options.tools = registry
options.max_steps = 8
```

## Agent options

`AgentOptions` supports cancellation, stream callbacks, bounded parallel tool
execution, and run-scoped call limits:

- `cancellation` accepts a proc or an object responding to `cancelled?`. The
  runner checks it before model work and before and after each tool.
- `on_stream` receives `Models::StreamPart` values for `values` and `messages`.
  A callback error aborts the run and runs after-run cleanup.
- `max_parallel_tools` starts tool invocations in threads within each batch while
  preserving result order. Tool implementations remain responsible for their own
  thread safety.
- `Middleware::CallLimit` keeps counters per run ID, so independent runs do not
  share limits.

`Praxo::SSE.parse` parses OpenAI-compatible server-sent-event text and raises
`MODEL_STREAM` for truncated streams or malformed half packets.
`Praxo::SSE.parse_response` additionally reassembles fragmented tool calls,
usage, and `finish_reason`; `OpenAICompatible#generate_stream` uses it with an
injected `stream_transport` or the built-in HTTP path. Set `on_delta` on the
agent options to use streaming.

## Model Adapters

- `Praxo::Adapters::OpenAICompatible` for OpenAI, DeepSeek, Kimi/Moonshot, and
  other OpenAI-compatible endpoints.
- `Praxo::Adapters::Anthropic` for the Anthropic Messages API, including `generate_stream` SSE reassembly.
- `Praxo::Adapters::Gemini` for the Gemini generateContent API.

Each adapter accepts a `transport` lambda for deterministic tests.

## MCP Client

`Praxo::Adapters::MCPClient` implements a stdio JSON-RPC MCP session with
initialize, paginated tool listing, tool calls, timeouts, and cancellation
notifications. Pass `reader`/`writer` to inject a deterministic transport, or
provide `command:` to start a child process with `Open3`.

## Harmovela Event Sink

`Praxo::Adapters::HarmovelaSink` posts each event to `{base_url}/events` with an
`application/json` envelope. Inject `transport` and `clock` for deterministic
tests.

```ruby
sink = Praxo::Adapters::HarmovelaSink.new(
  base_url: 'http://127.0.0.1:8790/aep/api',
  source: 'praxo-core'
)
options.events = sink
```

A 2xx response is success; any other status raises `HARMOVELA_HTTP` with the
status and a bounded body. The sink adds no authentication, retries, buffering,
ordering, or exactly-once delivery. Use HTTPS and filter sensitive event data
before emitting.

## Process plugin host

`Praxo::PluginProcessHost` speaks the framework JSON-Lines process plugin
protocol with token authentication, health handshake, invocation timeout,
cooperative cancel, and typed call errors.
## Layout

- `lib/praxo/` package source.
- `conformance/run.rb` vector runner.
- `api-snapshot.rb` and `api/` public API snapshot.
- `tests/run.rb` test suite.

## Release

Tag shape: `ruby/v0.8.2`. The tag targets `SPEC_VERSION` `0.2.0`. See
[CHANGELOG.md](CHANGELOG.md) for per-release changes and compatibility notes.
