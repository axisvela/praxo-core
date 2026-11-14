# Streaming

This example uses published crates.io `praxo-core@0.8.0` to consume deltas while
the agent loop keeps running normally.

Call `Agent::run_stream` with a delta callback and configure a
`StreamingModel` in `AgentOptions.streaming_model`. The agent forwards each
delta and uses the returned `Response` as the final model response.

## Run the deterministic test

No endpoint is required:

```bash
cargo run
```

Expected output:

```text
streaming test: ok
```

## Wiring a real adapter

Replace the fake model with a published streaming adapter, for example the
OpenAI-compatible adapter. Keep application logic on the final result and treat
deltas as incremental display or progress signals.
