# PRAXO-CORE Lua Core

Lua 5.4 implementation of the PRAXO-CORE agent contract. The normative
contract is [`spec/`](../../spec/README.md); Go remains the reference
implementation.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.1.0`
- Tier: core
- License: MIT
- Dependencies: Lua standard library only

## Scope

The Core implements all eleven vector groups: toolcall, JSON Schema, plugin,
memory, event, stream, checkpoint, policy, context, middleware, and the agent
loop. It includes a public API snapshot and a dependency-free test runner.

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

Tag shape: `lua/v0.1.0`. The tag targets `SPEC_VERSION` `0.2.0`.
