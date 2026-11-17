# Julia Representative Chain

This deterministic example exercises the Go representative-chain seams:
MCP-style record, final-argument authorization, governed child delegation,
OTel/Harmovela events, and an edited denial with zero effects.

```bash
julia --project=language/julia language/julia/examples/representative-chain/chain.jl
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
