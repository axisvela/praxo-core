param(
    [string]$Version,
    [string]$OutFile,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $Version) {
    $Version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
}
if (-not $OutFile) {
    $OutFile = Join-Path $root "api\$Version.txt"
}
$priorGoWork = $env:GOWORK
$env:GOWORK = 'off'
try {
    Push-Location $root
    $packages = go list ./pkg/...
    if ($LASTEXITCODE -ne 0) {
        throw "go list failed (exit $LASTEXITCODE)"
    }
    if (-not $packages) {
        throw 'go list returned no public packages'
    }
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($pkg in $packages) {
        $lines.Add("### $pkg")
        $doc = go doc -short -all $pkg
        if ($LASTEXITCODE -ne 0) {
            throw "go doc $pkg failed (exit $LASTEXITCODE)"
        }
        $doc = $doc | Where-Object {
            $_ -notmatch '^    ' -and $_ -notmatch "^\t//" -and $_ -notmatch '^Package '
        }
        foreach ($line in $doc) {
            $lines.Add($line)
        }
        $lines.Add('')
    }
    $snapshot = $lines -join "`n"
    if ($Check) {
        if (-not (Test-Path -LiteralPath $OutFile -PathType Leaf)) {
            throw "API snapshot missing: $OutFile"
        }
        $baseline = [System.IO.File]::ReadAllText($OutFile).Replace("`r`n", "`n")
        if ($snapshot -cne $baseline) {
            throw "API snapshot differs from current source: $OutFile"
        }
        Write-Output "API snapshot matches current source: $OutFile"
        return
    }
    New-Item -ItemType Directory -Force (Split-Path -Parent $OutFile) | Out-Null
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($OutFile, $snapshot, $enc)
    Write-Output "wrote $OutFile"
} finally {
    Pop-Location
    $env:GOWORK = $priorGoWork
}
