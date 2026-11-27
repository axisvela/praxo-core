# Independent Elixir Consumer

This module uses published Hex `praxo_core` `0.11.1` and verifies an allow/deny
governed tool path without local replacements.

This is the recommended package pin, not new execution evidence. The consumer
has not been rerun against this release as part of the pin update.

```bash
mix deps.get
mix run test_starter.exs
```

For a source checkout without Hex:

```bash
elixir -pa language/elixir/build/ebin test_starter.exs
```

The starter uses a deterministic model. It does not prove live provider behavior,
authentic identity, durable approvals, or production readiness.
