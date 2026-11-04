# Publishing the PowerShell Core

## Status

Source tag `powershell/v0.2.0` maps to PowerShell Gallery package
`praxo-core-ps` version `0.2.0`. The module is a shared-runtime wrapper over the
C# Core and is not yet published.

## Build

```bash
dotnet build language/csharp/Praxo.Core/Praxo.Core.csproj -c Release
pwsh -NoProfile -File language/powershell/tests/run.ps1
pwsh -NoProfile -File language/powershell/api-snapshot.ps1 -Check
```

The release workflow copies `Praxo.Core.dll` into `praxo-core-ps/` before
packaging.

## PowerShell Gallery

1. Register or sign in at <https://www.powershellgallery.com/>.
2. Create an API key for `praxo-core-ps`.
3. Configure GitHub environment `powershell-gallery` and secret
   `PSGALLERY_API_KEY`.
4. Publish:

```powershell
Publish-Module -Path language/powershell/praxo-core-ps -Repository PSGallery -NuGetApiKey $env:PSGALLERY_API_KEY
```

Keep `praxo-core-ps.psd1` and `VERSION` aligned with the `powershell/vX.Y.Z`
tag. Do not commit the API key.
