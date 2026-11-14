# Provider Fallback

This example uses published NuGet `Praxo.Core==0.8.0` to fall back to a second
model when the primary model call fails.

`AgentOptions.FallbackModel` installs a model middleware. The fallback is used
only after the primary fails; the primary remains first in the normal path.

## Run the deterministic check

No endpoint is required:

```bash
dotnet run -- --test
```

Expected output:

```text
provider fallback test: ok
```

## Wiring real adapters

Replace the fake models in `Program.Run` with two published adapters, for
example two `OpenAiCompatibleModel` instances with different endpoint
configurations. The fallback is a resilience mechanism, not a provider SLA or a
guarantee that both providers agree on behavior.
