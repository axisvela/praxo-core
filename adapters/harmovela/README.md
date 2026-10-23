# Harmovela Event Sink

`adapters/harmovela` publishes PRAXO-CORE lifecycle events to the Harmovela HTTP
events API. It uses the protocol directly, so it does not import the heavier
Harmovela Go module.

```bash
go get github.com/axisvela/praxo-core/adapters/harmovela@v0.1.0
```

```go
sink := harmovela.Sink{
    BaseURL: "http://127.0.0.1:8790/aep/api",
    Source:  "praxo-core",
}

ag, err := agent.New(agent.Options{
    Model:  modelAdapter,
    Events: sink,
})
```

Each event is posted to `POST {baseURL}/events` with `spec_version`, `id`,
`type`, `source`, `created_at`, and a payload containing session, run, and event
data.

## Security

- The sink does not add authentication; put it behind your trusted network
  boundary or a product-owned authenticated gateway.
- Event data may contain sensitive content. Apply caller-side filtering before
  passing events to the sink.
- Use HTTPS for remote Harmovela endpoints.

## Test

```bash
cd adapters/harmovela
GOWORK=off go test ./...
```
