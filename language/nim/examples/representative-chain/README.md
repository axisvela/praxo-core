# Nim Representative Chain

This deterministic example exercises the same application seams as the Go
representative chain without a live provider:

```text
scripted model -> MCP record tool -> final-argument authorization
               -> governed child delegation -> OTel / Harmovela events
               -> edited denial with zero effects
```

## Run

```bash
nim c --path:language/nim/src --hints:off \
  -o:build/praxo-nim-chain language/nim/examples/representative-chain/chain.nim
./build/praxo-nim-chain
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

The models and transports are deterministic. This does not prove live provider,
remote MCP/Harmovela, identity, isolation, exactly-once execution, or production
readiness.
