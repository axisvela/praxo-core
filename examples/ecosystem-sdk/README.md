# NOETIVELA SDK Integration

This is a separate example module that uses the real
[NOETIVELA Go SDK](https://github.com/axisvela/noetivela-open/tree/main/sdk/go)
instead of the callback skeletons in [`../ecosystem`](../ecosystem).

It is a separate module so the MIT framework module does not depend on a product
SDK. The example still imports PRAXO-CORE through a local `replace`.

## What It Shows

- `noetivela.Adapter` implements `model.Model` with the NOETIVELA SDK client.
- The adapter maps a neutral `model.Request` to a NOETIVELA `client.Contract`.
- It forwards policy, usage, finish reason, and the governed chat response.
- `cmd/demo` runs the adapter against an in-process `httptest` gateway and wires
  it into an agent with memory, events, and policy.

## Limitations

The NOETIVELA SDK `ChatResponse` exposes text content, not tool calls. This
adapter is therefore text-only. For agent tool calling through NOETIVELA, use a
custom HTTP adapter that preserves tool-call fields, or keep tool execution in
the product runtime.

## Run

```bash
cd examples/ecosystem-sdk
GOWORK=off go run ./cmd/demo
```

On PowerShell:

```powershell
Set-Location examples/ecosystem-sdk
$env:GOWORK = 'off'
go run ./cmd/demo
```

## Test

```bash
cd examples/ecosystem-sdk
GOWORK=off go test ./...
```

For a real gateway, replace `sdk.New(server.URL)` in the demo with
`sdk.New(os.Getenv("NOETIVELA_URL"))` and configure the contract and policy for
your deployment.
