# Independent Lua Consumer

Use the published LuaRocks `praxo-core` `0.6.0-1` package in your own application
with Lua 5.4. No PRAXO-CORE source checkout, API key, model service, or AxisVela
product is required. Installation needs LuaRocks access or a cached rock.

This is an extended-language starter. It demonstrates the allow/deny path but is
not one of the four pilot languages that carry the governed negative matrix.

## Choose the Boundary

This is a fit for an embedded model/tool loop with explicit tool scope and
policy. Your application still owns model access, authentic identity, persistent
approvals, external effects, and isolation. It is not a hosted agent platform,
durable graph engine, or sandbox service. See [when not to use Core](when-not-to-use.md).

## Install in a New Application

```sh
luarocks install praxo-core 0.6.0-1
```

Do not add the repository `language/lua` directory to `package.path`, and do not
use a local rockspec or checkout for acceptance. The starter adds a source
fallback only so this repository can run the same file without LuaRocks; a real
consumer should install the rock.

## Application Source

Use the following as `starter.lua`, rendered from the
[tested source](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-lua/starter.lua).

<!-- lua-consumer-source: starter.lua -->

## Acceptance Tests

Use the following as `test_starter.lua`, rendered from the
[tested source](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-lua/test_starter.lua).

<!-- lua-consumer-source: test_starter.lua -->

## Verify

```sh
luarocks install praxo-core 0.6.0-1
lua test_starter.lua
```

Expected program output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The model is a deterministic fixture, not an LLM. `allowed_tools` limits the tool
name; Policy also checks the target argument. A denied private target raises
`AGENT_POLICY_DENIED` and must not increment the in-memory counter. Keep these
tests when replacing the fixture with a real adapter.

## Scope

This starter establishes only the stated rock and fixture behavior. It does not
add the governed negative matrix, prove authentic identity, provide durable
approvals, reconcile effects, or establish isolation. Continue with the
[Lua implementation guide](../languages/lua/index.md) and the
[security model](../security/index.md).
