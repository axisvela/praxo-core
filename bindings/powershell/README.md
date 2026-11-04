# PowerShell Bridge

Bridge package `praxo-core-ps-br`, a thin wrapper over `praxo-bridge` following
`spec/bridge.md`.

```powershell
Import-Module ./bindings/powershell/praxo-core-ps-br/praxo-core-ps-br.psm1
'{"content":"{\"name\":\"echo\",\"input\":{}}"}'
    | Invoke-PraxoBridge -Arguments @('toolcall', 'parse')
    | ConvertFrom-Json
```

Set `PRAXO_BRIDGE_BIN` to use a prebuilt binary. Otherwise the module runs
`go run ./cmd/praxo-bridge`.

The module preserves stdout JSON and throws when the bridge exits non-zero.
