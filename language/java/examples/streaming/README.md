# Streaming

This example uses published Maven `com.axisvela:praxo-core:0.7.0` to consume
deltas while the agent loop keeps running normally.

Set `AgentOptions.onDelta` and implement `StreamingModel`. The agent calls
`generateStream` when a callback is configured, forwards each delta, and uses
the returned `Response` as the final model response.

## Run the deterministic check

No endpoint is required:

```bash
mvn -q compile exec:java
```

Expected output:

```text
streaming test: ok
```

## Wiring a real adapter

Replace the fake model with a published streaming adapter. Keep application
logic on the final result and treat deltas as incremental display or progress
signals.
