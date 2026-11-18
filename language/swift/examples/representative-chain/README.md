# Swift Representative Chain

This deterministic example exercises the same application seams as the Go and
Python representative chains without a live provider:

```text
scripted model -> MCP record tool -> final-argument authorization
               -> governed child delegation -> OTel / Harmovela events
               -> edited denial with zero effects
```

It uses an in-memory MCP transport, deterministic parent/child models, the OTel
and Harmovela sinks with in-memory transports, and an explicit parent/child
policy composition.

## Run

```bash
swift run --package-path language/swift praxo-representative-chain-example
```

Expected output:

```text
output: DONE
effects: parent=1 child=1
child calls: 2
otel spans: 10
harmovela events: 10
denied effects: 0
```

The OTel and Harmovela counts depend on the transport seam and may be lower
when individual events are sampled or omitted; the example requires at least
three event classes.

## What It Proves

- the parent requests the MCP `record` tool and the final arguments are
  authorized;
- the parent delegates to a child with `record` as its only tool scope and a
  composed parent/child policy;
- OTel and Harmovela sinks receive the lifecycle and tool events;
- a HITL edit to `target=blocked` is reauthorized, the MCP tool is not called,
  and the effect count stays zero.

## Boundaries

The parent and child models are deterministic. This is not a live-model run and
does not prove provider behavior, remote MCP or Harmovela operation, identity,
isolation, exactly-once execution, or production readiness. The Go
`examples/representative-chain` is the real-model counterpart.
