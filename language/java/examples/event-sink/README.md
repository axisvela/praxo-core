# Event Sink

This example uses published Maven `com.axisvela:praxo-core:0.7.0` to observe
agent lifecycle and tool events without coupling the agent to a logging or
telemetry backend.

`AgentOptions.events` accepts any `Sink`. `Sink.multi` fans out to several sinks,
and `Sink.filter` forwards only selected event types. The run records
`run.started`, `tool.call`, and `run.completed`; the filtered sink receives only
`tool.call`.

## Run the deterministic check

No endpoint is required:

```bash
mvn -q compile exec:java
```

Expected output:

```text
event sink test: ok
```

## Wiring real sinks

Replace the recording sinks with your application sink, for example an audit
log, metrics exporter, or the published OpenTelemetry adapter. Keep event
handling outside the model and tool implementations so the same agent can run
with different observability backends.
