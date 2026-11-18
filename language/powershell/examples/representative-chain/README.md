# PowerShell Representative Chain

Deterministic representative chain covering MCP record, final-argument
authorization, governed child delegation, OTel/Harmovela events, and an edited
denial with zero effects.

From `language/powershell/`:

```powershell
pwsh -NoProfile -File examples/representative-chain/chain.ps1
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

The script uses an in-memory MCP transport, deterministic parent/child models,
and a C# interop fixture for the PowerShell wrapper. The parent/child policy and
edited denial are application-owned; the Core does not inherit authority
automatically.
