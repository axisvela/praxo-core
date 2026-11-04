# Publishing the PowerShell Bridge

## Status

Source tag `powershell/v0.1.0` maps to PowerShell Gallery package
`praxo-core-ps-br` version `0.1.0`. The bridge package is not yet published.

## Bundled binaries

The release workflow builds `cmd/praxo-bridge` for:

- `linux-x64`
- `linux-arm64`
- `win-x64`
- `osx-x64`
- `osx-arm64`

and places each binary under `bin/<rid>/` in the module. The module resolves the
current platform at import time. Set `PRAXO_BRIDGE_BIN` to override it.

## Build

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o bindings/powershell/praxo-core-ps-br/bin/linux-x64/praxo-bridge ./cmd/praxo-bridge
pwsh -NoProfile -Command "Import-Module ./bindings/powershell/praxo-core-ps-br/praxo-core-ps-br.psm1; Invoke-PraxoBridge -Arguments @('version')"
```

CI publication uses `.github/workflows/powershell-bridge-release.yml`.

## PowerShell Gallery

1. Register or sign in at <https://www.powershellgallery.com/>.
2. Create an API key for `praxo-core-ps-br`.
3. Configure GitHub environment `powershell-gallery` and secret
   `PSGALLERY_API_KEY`.
4. Publish:

```powershell
Publish-Module -Path bindings/powershell/praxo-core-ps-br -Repository PSGallery -NuGetApiKey $env:PSGALLERY_API_KEY
```

Keep the manifest `ModuleVersion` aligned with the `powershell/vX.Y.Z` source
tag and future `powershell-br/vX.Y.Z` bridge tags. Do not commit the API key.
