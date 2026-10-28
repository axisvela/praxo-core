param(
    [string]$Version,
    [string]$OutFile,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
function ConvertTo-ApiDeclarations([string]$Text) {
    $normalized = New-Object System.Collections.Generic.List[string]
    $declarations = $false
    foreach ($line in $Text.Replace("`r`n", "`n").Split("`n")) {
        if ($line.StartsWith('### ')) {
            $declarations = $false
            $normalized.Add($line)
            continue
        }
        if ($line -cmatch '^(CONSTANTS|VARIABLES|FUNCTIONS|TYPES)$') {
            $declarations = $true
        }
        if ($declarations) {
            $normalized.Add($line)
        }
    }
    return $normalized -join "`n"
}
if (-not $Version) {
    $Version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
}
if (-not $OutFile) {
    $OutFile = Join-Path $root "api\$Version.txt"
}
$priorGoWork = $env:GOWORK
$priorEncoding = [Console]::OutputEncoding
$env:GOWORK = 'off'
try {
    Push-Location $root
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
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
    $snapshot = ConvertTo-ApiDeclarations ($lines -join "`n")
    if ($Check) {
        if (-not (Test-Path -LiteralPath $OutFile -PathType Leaf)) {
            throw "API snapshot missing: $OutFile"
        }
        $baseline = ConvertTo-ApiDeclarations ([System.IO.File]::ReadAllText($OutFile))
        if ($snapshot -cne $baseline) {
            Compare-Object -ReferenceObject $baseline.Split("`n") -DifferenceObject $snapshot.Split("`n") -CaseSensitive |
                ForEach-Object { Write-Output ("{0} {1}" -f $_.SideIndicator, ($_.InputObject | ConvertTo-Json -Compress)) }
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
    [Console]::OutputEncoding = $priorEncoding
}
