# PRAXO-CORE Lua Core

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This rock is its
native Lua Core: an agent loop with tool registration and dispatch, policy
hooks, typed events, memory, checkpoints, context budgets, middleware, JSON
Schema validation, plugin manifest parsing, and human-in-the-loop interrupt
decisions.

The normative contract is [`spec/`](../../spec/README.md); Go remains the
reference implementation.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.4.1`
- Tier: core
- License: MIT
- Dependencies: Lua standard library only
- LuaRocks page: `praxo-core@0.4.1-1` published with the optional
  OpenAI-compatible adapter. Releases are built and published by
  `.github/workflows/lua-release.yml`

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/lua/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/lua/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/lua/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [LuaRocks](https://luarocks.org/modules/hanhhuiwen/praxo-core)

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

## Model Adapters

- `praxo.adapters.openai_compatible` for OpenAI, DeepSeek, Kimi/Moonshot, and
  other OpenAI-compatible endpoints.
- `praxo.adapters.anthropic` for the Anthropic Messages API.
- `praxo.adapters.gemini` for the Gemini generateContent API.

Each adapter accepts an injectable `transport` function for deterministic tests.

## Harmovela Event Sink

`praxo.adapters.harmovela_sink` posts each event to `{base_url}/events`.
The old `praxo.harmovela_sink` path remains as a compatibility wrapper.

```lua
local harmovela = require("praxo.adapters.harmovela_sink")
options.events = harmovela.new({
  base_url = "http://127.0.0.1:8790/aep/api",
})
```

A 2xx status is success; any other status raises `HARMOVELA_HTTP` with the
status and a bounded body. Inject `transport` (and `clock`) to test without a
network. The sink adds no authentication, retries, buffering, ordering, or
exactly-once delivery. Use HTTPS and filter sensitive event data first.

## Layout

- `praxo/` package source.
- `conformance/run.lua` vector runner.
- `api-snapshot.py` and `api/` public API snapshot.
- `tests/run.lua` test suite.

## Release

Tag shape: `lua/v0.4.1`. The tag targets `SPEC_VERSION` `0.2.0`. See
[CHANGELOG.md](CHANGELOG.md) for per-release changes and compatibility notes.
