# Independent Elixir Consumer

This module uses published Hex `praxo_core` `0.4.0` and verifies an allow/deny
governed tool path without local replacements.

```bash
mix deps.get
mix run -r starter.exs -e "ConsumerStarter.run()"
```

For a source checkout without Hex:

```bash
elixir -pa language/elixir/build/ebin test_starter.exs
```

The starter uses a deterministic model. It does not prove live provider behavior,
authentic identity, durable approvals, or production readiness.
