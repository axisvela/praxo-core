param(
    [string]$Out = 'dist/sbom.json'
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command cyclonedx-gomod -ErrorAction SilentlyContinue)) {
    throw 'cyclonedx-gomod is not installed: go install github.com/CycloneDX/cyclonedx-gomod/cmd/cyclonedx-gomod@latest'
}
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    New-Item -ItemType Directory -Force (Split-Path -Parent (Join-Path $root $Out)) | Out-Null
    cyclonedx-gomod mod -json -output $Out
    Write-Output "wrote $Out"
} finally {
    Pop-Location
}
