# OpenTelemetry Event Sink

`adapters/otel` maps `pkg/event` events to OpenTelemetry spans. It is an
optional module; the core framework does not depend on the OpenTelemetry SDK.

```bash
go get github.com/axisvela/praxo-core/adapters/otel@v0.2.0
```

```go
provider := sdktrace.NewTracerProvider(
    sdktrace.WithBatcher(exporter),
)
defer provider.Shutdown(ctx)

ag, err := agent.New(agent.Options{
    Model:  modelAdapter,
    Events: otelsink.New(provider),
})
```

Each event becomes a `praxo.<event.type>` span with attributes:

- `praxo.event.type`
- `praxo.session.id`
- `praxo.run.id`
- `praxo.event.at`

`Event.Data` is excluded by default. To export selected fields, configure the
sink before sharing it with an agent:

```go
sink := otelsink.New(provider)
sink.AllowedDataKeys = []string{"tool"}
```

Only present, explicitly allowed keys become `praxo.event.data.<key>`
attributes. This allowlist does not redact selected values: do not select
arguments, results, credentials, or other sensitive content without a separate
redaction policy. Session/run identifiers and event types are still exported;
use opaque identifiers and restrict access to your telemetry backend.

Event spans inherit the parent span from the context passed to `Emit`. Each
span represents one emitted event, not the duration of a complete agent run.
See the [event and OpenTelemetry schema](https://github.com/axisvela/praxo-core/blob/main/docs/reference/events.md)
for the stable event names, payloads, and compatibility rules.

This default differs from the published `v0.1.0`, which exports all event data.
The safer behavior is introduced in v0.2.0. Users upgrading from v0.1.0 must
explicitly select any event data fields they still want exported.

## Test

```bash
cd adapters/otel
GOWORK=off go test ./...
```
