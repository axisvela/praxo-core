# Delphi / Free Pascal Representative Chain

Deterministic representative chain covering MCP record, final-argument
authorization, governed child delegation, OTel/Harmovela events, and an edited
denial with zero effects.

From `language/delphi/`:

```bash
fpc -Mobjfpc -Scghi -O2 -Fu. -FEbuild examples/representative-chain/chain.pas
./build/chain
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

Validated with Free Pascal 3.2.2 on Windows i386. Commercial Delphi
compatibility is not established. The example is a short-lived process and
relies on process exit for finalization; it is not a long-running service
lifecycle sample.
