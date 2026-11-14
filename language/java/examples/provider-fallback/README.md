# Provider Fallback

This example uses published Maven `com.axisvela:praxo-core:0.7.0` to fall back to
a second model when the primary model call fails.

`AgentOptions.fallbackModel` installs a model middleware. The fallback is used
only after the primary fails; the primary remains first in the normal path.

## Run the deterministic check

No endpoint is required:

```bash
mvn -q compile exec:java
```

Expected output:

```text
provider fallback test: ok
```

## Wiring real adapters

Replace the fake models with two published adapters, for example two
`OpenAICompatibleModel` instances with different endpoint configurations. The
fallback is a resilience mechanism, not a provider SLA or a guarantee that both
providers agree on behavior.
