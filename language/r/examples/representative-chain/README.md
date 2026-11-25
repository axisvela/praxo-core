# R Representative Chain

This deterministic example exercises the same application seams as the Go
representative chain without a live provider or network:

```text
scripted model -> MCP record tool -> final-argument authorization
               -> governed child delegation -> OTel / Harmovela events
               -> edited denial with zero effects
```

The MCP `record` tool uses a caller-owned in-memory transport (the existing
`mcp_client` seam). OTel and Harmovela sinks use their injectable `transport`
callbacks, so no HTTP request leaves the process.

## Run

From the repository root:

```powershell
D:\dev\R\bin\Rscript.exe language/r/examples/representative-chain/chain.R
```

The script sources `language/r/R/json.R`, `core.R`, `mcp.R`, `otel.R`, and
`harmovela.R` from the checkout.

## Expected output

```text
output: DONE
effects: parent=1 child=1
child calls: 2
otel spans: 7
harmovela events: 7
denied effects: 0
```

The span and event counts depend on the parent and child run lifecycle; the
exact numbers can increase if the runner emits additional lifecycle events.

## What It Proves

- the parent requests the MCP `record` tool and the final arguments are
  authorized;
- the parent delegates to a child with `record` as its only tool scope and a
  composed parent/child policy;
- the OTel and Harmovela sinks receive `run.started`, `tool.call`, and
  `run.completed` events;
- a middleware edit to `target=blocked` is reauthorized, the MCP tool is not
  invoked, and the effect count stays zero.

## Boundaries

The models, MCP server, OTel collector, and Harmovela endpoint are deterministic
in-memory fakes. This is not a live-model run and does not prove provider
behavior, remote MCP or Harmovela operation, identity, isolation, exactly-once
execution, or production readiness. The Go `language/go/examples/representative-chain` is
the real-model counterpart.
