# Independent Lua Consumer

This module uses the published LuaRocks `praxo-core` `0.9.1-1` package and
verifies an allow/deny governed tool path without local replacements.

This is the recommended package pin, not new execution evidence. The consumer
has not been rerun against this release as part of the pin update.

```bash
luarocks install praxo-core 0.9.1-1
lua test_starter.lua
```

For a source checkout without LuaRocks:

```bash
lua test_starter.lua
```

The starter uses a deterministic model. It does not prove live provider behavior,
authentic identity, durable approvals, or production readiness.
