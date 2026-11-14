# Streaming

This example uses published NuGet `Praxo.Core==0.8.0` to consume deltas while
the agent loop keeps running normally.

Call `Agent.RunStream` with a delta callback and implement `IStreamingModel`.
The agent calls `GenerateStream`, forwards each delta, and uses the returned
`Response` as the final model response.

## Run the deterministic check

No endpoint is required:

```bash
dotnet run -- --test
```

Expected output:

```text
streaming test: ok
```

## Wiring a real adapter

Replace the fake model with a published streaming adapter, for example
`OpenAiCompatibleModel`. Keep application logic on the final result and treat
deltas as incremental display or progress signals.
