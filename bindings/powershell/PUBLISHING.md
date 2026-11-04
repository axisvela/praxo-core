# Publishing the PowerShell Bridge

## Status

Source tag `powershell/v0.1.0` maps to module `PraxoBridge` version `0.1.0`.
The module is not yet published to the PowerShell Gallery.

## PowerShell Gallery

PowerShell Gallery uses a Microsoft account and an API key:

1. Register or sign in at <https://www.powershellgallery.com/>.
2. Create an API key for the `PraxoBridge` package.
3. Configure the GitHub environment `powershell-gallery` and repository secret
   `PSGALLERY_API_KEY`; CI publication uses
   `.github/workflows/powershell-release.yml`.
4. Publish:

```powershell
Publish-Module -Path bindings/powershell -Repository PSGallery -NuGetApiKey $env:PSGALLERY_API_KEY
```

The manifest is `PraxoBridge.psd1`; keep `ModuleVersion` aligned with the
`powershell/vX.Y.Z` tag.

Do not commit the API key.
