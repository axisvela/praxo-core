# PRAXO-CORE Ruby Core

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This gem is its
native Ruby Core: an agent loop with tool registration and dispatch, policy
hooks, typed events, memory, checkpoints, context budgets, middleware, JSON
Schema validation, and plugin manifest parsing.

The normative contract is [`spec/`](../../spec/README.md); Go remains the
reference implementation.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.1.0`
- Tier: core
- License: MIT
- Dependencies: Ruby standard library only
- Published on RubyGems as `praxo-core@0.1.0`

## Install

```bash
gem install praxo-core
```

## Scope

The Core implements all eleven vector groups: toolcall, JSON Schema, plugin,
memory, event, stream, checkpoint, policy, context, middleware, and the agent
loop. It includes a public API snapshot and a dependency-free test runner.

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

## Layout

- `lib/praxo/` package source.
- `conformance/run.rb` vector runner.
- `api-snapshot.rb` and `api/` public API snapshot.
- `tests/run.rb` test suite.

## Release

Tag shape: `ruby/v0.1.0`. The tag targets `SPEC_VERSION` `0.2.0`.
