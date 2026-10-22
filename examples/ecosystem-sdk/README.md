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
