# Ecosystem Adapter Skeletons

These adapters show how AxisVela components plug into PRAXO-CORE's interfaces.
Each adapter accepts a callback, so product code can supply its own client
without adding product dependencies to the framework. These skeletons
intentionally do not import ecosystem SDKs. For a real SDK-backed adapter, see
[`../ecosystem-sdk`](../ecosystem-sdk) (NOETIVELA).

| Adapter | PRAXO-CORE seam | Ecosystem component |
| --- | --- | --- |
| `Model`, `Provider` | `model.Model`, `model.Provider` | model providers, including NOETIVELA |
| `Memory` | `memory.Store` | Mnemovela |
| `Events` | `event.Sink` | Harmovela / Argus Trace |
| `Retriever` | `retriever.Retriever` | GNOSIVELA / Mnemovela |
| `Policy` | `policy.Hook` | AEGIVELA / Archon Guard |
| `Sandbox`, `Interpreter` | `sandbox.Sandbox`, `sandbox.Interpreter` | Vulcan Forge |
| `Gateway` | `tool.Gateway` | Janus Gateway |

For NOETIVELA, wrap its Go SDK in `Model.GenerateFunc` or `Provider.ChatFunc`.
Map the neutral `model.Request` to a NOETIVELA Inference Contract inside the
adapter; the framework does not add NOETIVELA-specific fields.

Unconfigured callbacks return `ErrNotConfigured`. The skeleton contains no
network code, credentials, or product imports.

Run the tests with:

```bash
GOWORK=off go test ./examples/ecosystem
```

Run the end-to-end wiring demo:

```bash
GOWORK=off go run ./examples/ecosystem/cmd/demo
```
