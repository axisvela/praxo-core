# Provider Fallback

This example uses published crates.io `praxo-core@0.6.0` to fall back to a
second model when the primary model call fails.

`AgentOptions.fallback_model` installs a model middleware. The fallback is used
only after the primary fails; the primary remains first in the normal path.

## Run the deterministic test

No endpoint is required:

```bash
cargo run
```

Expected output:

```text
provider fallback test: ok
```

The run checks three paths: primary succeeds, primary fails and fallback
succeeds, and both fail while the primary error is preserved.

## Wiring real adapters

Replace the fake models in `src/main.rs` with real `Model` implementations, for
example two provider adapters with different endpoint configurations. The
fallback is a resilience mechanism, not a provider SLA or a guarantee that both
providers agree on behavior.
