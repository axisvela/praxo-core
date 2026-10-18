param(
    [string]$Version,
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $Version) {
    $Version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
}
if (-not $OutFile) {
    $OutFile = Join-Path $root "api\$Version.txt"
}
$env:GOWORK = 'off'
try {
    Push-Location $root
    $packages = go list ./pkg/...
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($pkg in $packages) {
        $lines.Add("### $pkg")
        $doc = go doc -short -all $pkg | Where-Object {
            $_ -notmatch '^    ' -and $_ -notmatch "^\t//" -and $_ -notmatch '^Package '
        }
        foreach ($line in $doc) {
            $lines.Add($line)
        }
        $lines.Add('')
    }
    New-Item -ItemType Directory -Force (Split-Path -Parent $OutFile) | Out-Null
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($OutFile, ($lines -join "`n"), $enc)
    Write-Output "wrote $OutFile"
} finally {
    Pop-Location
    Remove-Item Env:GOWORK -ErrorAction SilentlyContinue
}
