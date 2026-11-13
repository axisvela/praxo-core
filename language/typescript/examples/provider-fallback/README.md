# Provider Fallback

This example uses published npm `@axisvela/praxo-core@0.5.0` to fall back to a
second model when the primary model call fails.

`AgentOptions.fallbackModel` installs a model middleware. The fallback is used
only after the primary fails; the primary remains first in the normal path.

## Run the deterministic test

No endpoint is required:

```bash
npm install
npm test
```

## Wiring real adapters

Replace the fake models in `fallback.js` with two published adapters, for
example:

```js
const primary = new OpenAICompatibleModel({ baseUrl, apiKey, model: "gpt-4o-mini" });
const fallback = new OpenAICompatibleModel({ baseUrl: fallbackUrl, apiKey: fallbackKey, model: "deepseek-chat" });
```

The fallback is a resilience mechanism, not a provider SLA or a guarantee that
both providers agree on behavior.
