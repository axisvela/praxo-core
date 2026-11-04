# PowerShell Bridge

Bridge package `praxo-core-ps-br`, a thin wrapper over `praxo-bridge` following
`spec/bridge.md`.

```powershell
Install-Module praxo-core-ps-br -Scope CurrentUser
'{"content":"{\"name\":\"echo\",\"input\":{}}"}'
    | Invoke-PraxoBridge -Arguments @('toolcall', 'parse')
    | ConvertFrom-Json
```

The module ships `cmd/praxo-bridge` binaries for Linux, Windows, and macOS
under `bin/<rid>/`. Set `PRAXO_BRIDGE_BIN` to override the bundled binary.
From a source checkout without a bundled binary, the module falls back to
`go run ./cmd/praxo-bridge`.

The module preserves stdout JSON and throws when the bridge exits non-zero.
