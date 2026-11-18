# Haskell Representative Chain

Deterministic representative chain covering MCP record, final-argument
authorization, governed child delegation, OTel/Harmovela events, and an edited
denial with zero effects.

From `language/haskell/`:

```bash
ghc -isrc examples/representative-chain/chain.hs -o build/praxo-hs-chain
./build/praxo-hs-chain
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

Deterministic models and in-memory transports only; no live provider, remote
MCP/Harmovela, identity, isolation, exactly-once, or production evidence.
