# PRAXO-CORE Lua Core

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This rock is its
native Lua Core: an agent loop with tool registration and dispatch, policy
hooks, typed events, memory, checkpoints, context budgets, middleware, JSON
Schema validation, plugin manifest parsing, and human-in-the-loop interrupt
decisions.

The normative contract is [`spec/`](../../spec/README.md); Go remains the
reference implementation.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.4.0`
- Tier: core
- License: MIT
- Dependencies: Lua standard library only
- LuaRocks page: `praxo-core@0.1.0-1` (registry install failed); split repo
  `axisvela/praxo-core-lua` and rock revision `0.1.0-2` fix pending upload

## Install

```bash
luarocks install praxo-core
```

## Scope

The Core implements all eleven vector groups: toolcall, JSON Schema, plugin,
memory, event, stream, checkpoint, policy, context, middleware, and the agent
loop. It includes a public API snapshot and a dependency-free test runner.

Optional agent options add cancellation, stream callbacks, and caller-provided
batch tool dispatch. `batch_invoke` receives the prepared calls and the maximum
parallelism and returns results in order; the Core itself does not create
threads. `praxo.sse.parse` rejects truncated and half-packet streams.

## Build and test

```bash
lua language/lua/conformance/run.lua
python language/lua/api-snapshot.py --check
lua language/lua/tests/run.lua
```

## Quickstart

```lua
package.path = "language/lua/?.lua;lua/?/init.lua;" .. package.path
local agent = require("praxo.agent")
local models = require("praxo.models")

local model = agent.static_model("hello")
local options = agent.agent_options(model)
local result = agent.run_agent(options, models.session({ id = "demo" }), "hello")
print(result.output)
```

Tools register on the options object:

```lua
local registry = agent.tool_registry()
agent.register_tool(registry, agent.func_tool("echo", "Echo arguments", function(arguments)
  return arguments
end))
options.tools = registry
options.max_steps = 8
```

## Layout

- `praxo/` package source.
- `conformance/run.lua` vector runner.
- `api-snapshot.py` and `api/` public API snapshot.
- `tests/run.lua` test suite.

## Release

Tag shape: `lua/v0.4.0`. The tag targets `SPEC_VERSION` `0.2.0`. See
[CHANGELOG.md](CHANGELOG.md) for per-release changes and compatibility notes.
