# Independent Lua Consumer

This module uses the published LuaRocks `praxo-core` `0.5.0-1` package and
verifies an allow/deny governed tool path without local replacements.

```bash
luarocks install praxo-core 0.5.0-1
lua test_starter.lua
```

For a source checkout without LuaRocks:

```bash
lua test_starter.lua
```

The starter uses a deterministic model. It does not prove live provider behavior,
authentic identity, durable approvals, or production readiness.
