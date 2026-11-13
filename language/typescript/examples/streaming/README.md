# Streaming

This example uses published npm `@axisvela/praxo-core@0.5.0` to consume deltas
while the agent loop keeps running normally.

Set `AgentOptions.onDelta` and implement `generateStream` on the model. The agent
calls `generateStream` when a callback is configured, forwards each delta, and
uses the returned `Response` as the final model response.

## Run the deterministic test

No endpoint is required:

```bash
npm install
npm test
```

## Wiring a real adapter

Replace the fake model with a published streaming adapter, for example
`OpenAICompatibleModel`. Keep application logic on the final result and treat
deltas as incremental display or progress signals.
