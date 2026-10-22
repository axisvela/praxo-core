# OpenTelemetry Event Sink

`adapters/otel` maps `pkg/event` events to OpenTelemetry spans. It is an
optional module; the core framework does not depend on the OpenTelemetry SDK.

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
- `praxo.event.data.<key>`

## Test

```bash
cd adapters/otel
GOWORK=off go test ./...
```
