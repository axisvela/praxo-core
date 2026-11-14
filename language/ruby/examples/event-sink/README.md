# Event Sink

This example uses the Ruby Core SDK to observe agent lifecycle and tool events
without coupling the agent to a logging or telemetry backend.

`AgentOptions.events` accepts any object with `emit(event)`. `MultiSink` fans out
to several sinks, and `FilterSink` forwards only selected event types. The run
records `run.started`, `tool.call`, and `run.completed`; the filtered sink
receives only `tool.call`.

## Run the deterministic test

No endpoint is required:

```bash
ruby -I language/ruby/lib language/ruby/examples/event-sink/test_event_sink.rb
```

## Wiring real sinks

Replace the recording sinks with your application sink, for example an audit
log, metrics exporter, or the published OpenTelemetry adapter. Keep event
handling outside the model and tool implementations so the same agent can run
with different observability backends.
