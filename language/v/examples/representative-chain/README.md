# V Representative Chain

This deterministic example exercises the same application seams as the Go
representative chain without a live provider:

```text
scripted model -> MCP record tool -> final-argument authorization
               -> governed child delegation -> OTel / Harmovela events
               -> edited denial with zero effects
```

## Run

```bash
v -o build/praxo-v-chain language/v/examples/representative-chain/chain.v
./build/praxo-v-chain
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

## Boundaries

The parent and child models are deterministic. The example uses in-memory MCP,
OTel, and Harmovela transports. It does not prove live provider behavior, remote
MCP or Harmovela operation, identity, isolation, exactly-once execution, or
production readiness. The Go `language/go/examples/representative-chain` is the real-model
counterpart.
