# Publishing the PowerShell Core

## Status

Source tag `powershell/v0.9.1` maps to PowerShell Gallery package
`praxo-core-ps` version `0.9.1`. The module is a shared-runtime wrapper over
the C# Core and is published to the PowerShell Gallery. The legacy bridge
package `praxo-core-ps-br` is published separately as `0.1.0`.

Local build, wrapper tests, and the API snapshot pass for `0.9.1`. Release
workflow run 45922472866 published the module with the `powershell-gallery`
environment secret.

The PowerShell Gallery page does not render `README.md`. Its introduction and
starter links come from `Description` and `PrivateData.PSData.ReleaseNotes` in
`praxo-core-ps.psd1`. Update those fields and publish a new patch version; an
already-published version cannot be edited in place.

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
