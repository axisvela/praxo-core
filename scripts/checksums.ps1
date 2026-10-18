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
    $hash = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    $sums = Join-Path $dist 'SHA256SUMS'
    [System.IO.File]::WriteAllText($sums, "$hash  praxo-core-$Version.tar.gz`n", (New-Object System.Text.UTF8Encoding($false)))
    Write-Output "wrote $archive"
    Write-Output "wrote $sums"
} finally {
    Pop-Location
}
