# AxisVela SDK Integration

This is a separate example module that uses real AxisVela SDKs instead of the
callback skeletons in [`../ecosystem`](../ecosystem).

It is a separate module so the MIT framework module does not depend on product
SDKs. The example still imports PRAXO-CORE through a local `replace`.

## Adapters

| Adapter | PRAXO-CORE seam | AxisVela SDK |
| --- | --- | --- |
| `noetivela.Adapter` | `model.Model` | NOETIVELA |
| `mnemovela.Store` | `memory.Store` | Mnemovela |
| `gnosivela.Retriever` | `retriever.Retriever` | GNOSIVELA |
| `aegivela.Hook` | `policy.Hook` | AEGIVELA |
| `limenora.Gateway` | `tool.Gateway` | LIMENORA |
| `rheovela.Runner` | agent session to workflow instance | RHEOVELA |
| `harmovela.Sink` | `event.Sink` | Harmovela HTTP protocol |

### NOETIVELA

`noetivela.Adapter` maps a neutral `model.Request` to a NOETIVELA
`client.Contract` and forwards policy, usage, and the governed chat response.

The NOETIVELA SDK `ChatResponse` exposes text content, not tool calls. This
adapter is therefore text-only. For agent tool calling through NOETIVELA, use a
custom HTTP adapter that preserves tool-call fields, or keep tool execution in
the product runtime.

### Mnemovela

`mnemovela.Store` records each `memory.Record` as a Mnemovela episode and maps
`search_memory` results back to records.

```go
transport := jsonrpc.New("http://localhost:8080")
store := mnemovelaadapter.Store{
    Client: mnemovela.New(transport),
    Branch: "main",
}
```

### GNOSIVELA

`gnosivela.Retriever` calls `GroundingAssemble` and maps knowledge assertions to
`retriever.Document` values.

```go
adapter := gnosivelaadapter.Retriever{
    Client:    gnosivela.New("http://localhost:8080"),
    Principal: "user:demo",
    Purpose:   "status_lookup",
    Budget:    1200,
}
```

GNOSIVELA does not yet publish a `v3` semver tag for this module path, so
`go.mod` pins a pseudo-version from `master`. Update it when a release tag is
available.

### AEGIVELA

`aegivela.Hook` evaluates actions through the AEGIVELA PEP SDK and maps the
outcome to `policy.Decision`.

```go
hook := aegivelaadapter.Hook{
    Client: pepsdk.NewClient("https://aegivela.internal:1886", http.DefaultClient),
    Route: pepsdk.Route{
        Audience:  "agent",
        Action:    "tool:invoke",
        Scope:     []string{"tool:invoke"},
        Kind:      "tool",
        Reference: "lookup",
    },
    Input: pepsdk.AuthorizationInput{
        Mode:              pepsdk.ModeSystemAPI,
        WorkloadAssertion: "...",
    },
}
```

### LIMENORA

`limenora.Gateway` maps tool names to governed outbound requests and sends them
through the LIMENORA `NetworkGateway`.

```go
gateway := limenoraadapter.Gateway{
    Client: proxyEgress,
    Tools: map[string]limenoraadapter.Route{
        "lookup": {
            URL:         "https://api.example.com/status",
            Method:      "POST",
            Description: "Look up status",
        },
    },
    Ctx: sdk.AuthzContext{
        TenantID:    "acme",
        WorkspaceID: "default",
        ActorID:     "agent-1",
    },
}
```

### RHEOVELA

`rheovela.Runner` maps an `agent.Session` to a RHEOVELA workflow instance and
advances it through stages.

```go
runner := rheovelaadapter.Runner{
    Client:    rheovela.NewClient("http://127.0.0.1:8080"),
    Workflow:  "agent",
    ProjectID: "proj",
    Actor:     "agent-1",
}

instance, err := runner.Start(ctx, session)
err = runner.Step(ctx, instance.InstanceID, "advance", "review")
audit, err := runner.Audit(ctx, instance.InstanceID)
```

### Harmovela

`harmovela.Sink` publishes lifecycle events to the Harmovela HTTP events API
without importing the heavier Harmovela module.

```go
sink := harmovelaadapter.Sink{
    BaseURL: "http://127.0.0.1:8790/aep/api",
    Source:  "praxo-core",
}

ag, err := agent.New(agent.Options{
    Model:  modelAdapter,
    Events: sink,
})
```

## Run

```bash
cd examples/ecosystem-sdk
GOWORK=off go run ./cmd/demo
```

The demo uses an in-process `httptest` NOETIVELA gateway. Replace
`sdk.New(server.URL)` with a real gateway URL for a live integration.

## Test

```bash
cd examples/ecosystem-sdk
GOWORK=off go test ./...
```
