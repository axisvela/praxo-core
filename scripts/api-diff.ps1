param(
    [Parameter(Mandatory = $true)][string]$From,
    [Parameter(Mandatory = $true)][string]$To
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$fromFile = Join-Path $root "api\$From.txt"
$toFile = Join-Path $root "api\$To.txt"
if (-not (Test-Path $fromFile)) { throw "missing $fromFile; run scripts/api-snapshot.ps1 -Version $From" }
if (-not (Test-Path $toFile)) { throw "missing $toFile; run scripts/api-snapshot.ps1 -Version $To" }
git diff --no-index -- $fromFile $toFile
if ($LASTEXITCODE -eq 0) {
    Write-Output "no API changes between $From and $To"
} elseif ($LASTEXITCODE -eq 1) {
    Write-Output "API changes found between $From and $To; review before release"
} else {
    exit $LASTEXITCODE
}
