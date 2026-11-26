# Rust Representative Chain

This deterministic example exercises the same application seams as the Go
representative chain without a live provider or network:

```text
scripted model -> MCP record tool -> final-argument authorization
               -> governed child delegation -> OTel / Harmovela events
               -> edited denial with zero effects
```

The MCP `record` tool uses the `McpHttpTransport` seam with an in-process
transport. OTel and Harmovela sinks use injected `Transport` implementations
that only decode the request bodies in memory.

## Run

From this directory:

```bash
cargo run --offline
```

The crate uses published crates.io `praxo-core@0.11.0` from the local cargo cache.

## Expected output

```text
output: DONE
effects: {"child": 1, "parent": 1}
child calls: 2
otel spans: 8
harmovela events: 8
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
