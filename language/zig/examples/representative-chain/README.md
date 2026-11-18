# Zig Representative Chain

Deterministic representative chain covering MCP record, final-argument
authorization, governed child delegation, OTel/Harmovela events, and an edited
denial with zero effects.

From `language/zig/`:

```bash
zig build-exe --dep praxo \
  -Mroot=examples/representative-chain/chain.zig \
  -Mpraxo=src/praxo.zig -O ReleaseSafe -femit-bin=build/praxo-zig-chain
./build/praxo-zig-chain
```

On Windows, rename or copy the emitted binary to `.exe` before running it.

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
