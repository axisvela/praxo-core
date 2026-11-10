# PRAXO-CORE Ruby Core

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This gem is its
native Ruby Core: an agent loop with tool registration and dispatch, policy
hooks, typed events, memory, checkpoints, context budgets, middleware, JSON
Schema validation, and plugin manifest parsing.

The normative contract is [`spec/`](../../spec/README.md); Go remains the
reference implementation.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.4.1`
- Tier: core
- License: MIT
- Dependencies: Ruby standard library only
- Ruby source repository: https://github.com/axisvela/praxo-core-ruby
- The latest RubyGems package is `praxo-core@0.4.1`

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/ruby/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/ruby/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/ruby/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [RubyGems](https://rubygems.org/gems/praxo-core/versions/0.4.1)

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

## Layout

- `lib/praxo/` package source.
- `conformance/run.rb` vector runner.
- `api-snapshot.rb` and `api/` public API snapshot.
- `tests/run.rb` test suite.

## Release

Tag shape: `ruby/v0.4.1`. The tag targets `SPEC_VERSION` `0.2.0`. See
[CHANGELOG.md](CHANGELOG.md) for per-release changes and compatibility notes.
