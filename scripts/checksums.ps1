param(
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $Version) {
    $Version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
}
Push-Location $root
try {
    $dist = Join-Path $root 'dist'
    New-Item -ItemType Directory -Force $dist | Out-Null
    $archive = Join-Path $dist "praxo-core-$Version.tar.gz"
    git archive --format=tar.gz --prefix="praxo-core-$Version/" -o $archive HEAD
    $spec = (Get-Content (Join-Path $root 'spec\SPEC_VERSION') -Raw).Trim()
    & python (Join-Path $root 'scripts\release_manifest.py') `
        --root $dist `
        --version $Version `
        --tag "v$Version" `
        --sha (git rev-parse HEAD) `
        --go-version (go version) `
        --spec-version $spec `
        --sbom-scope 'root Go module dependencies only'
    if ($LASTEXITCODE -ne 0) {
        throw "release_manifest.py failed (exit $LASTEXITCODE)"
    }
    Write-Output "wrote $archive"
    Write-Output "wrote $(Join-Path $dist 'SHA256SUMS')"
} finally {
    Pop-Location
}
