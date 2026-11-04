# Publishing the PowerShell Bridge

## Status

Source tag `powershell/v0.1.0` maps to PowerShell Gallery package
`praxo-core-ps-br` version `0.1.0`. The bridge package is not yet published.

## PowerShell Gallery

1. Register or sign in at <https://www.powershellgallery.com/>.
2. Create an API key for `praxo-core-ps-br`.
3. Configure GitHub environment `powershell-gallery` and secret
   `PSGALLERY_API_KEY`.
4. Publish:

```powershell
Publish-Module -Path bindings/powershell/praxo-core-ps-br -Repository PSGallery -NuGetApiKey $env:PSGALLERY_API_KEY
```

Keep the manifest `ModuleVersion` aligned with the `powershell/vX.Y.Z` tag.
Do not commit the API key.
