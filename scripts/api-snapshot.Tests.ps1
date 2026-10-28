$ErrorActionPreference = 'Stop'
$priorGoWork = $env:GOWORK
$priorExitCode = $global:LASTEXITCODE
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $temp
$baseline = Join-Path $temp 'snapshot.txt'
$script = Join-Path $PSScriptRoot 'api-snapshot.ps1'
$state = @{ Calls = 0; FailAt = 0; Empty = $false; FieldType = 'string'; ReturnType = 'string' }

function go {
    $state.Calls++
    $global:LASTEXITCODE = if ($state.Calls -eq $state.FailAt) { 23 } else { 0 }
    if ($global:LASTEXITCODE -ne 0) { return }
    if ($env:GOWORK -ne 'off') { throw 'snapshot must disable Go workspace' }
    if ($args[0] -eq 'list') {
        if (-not $state.Empty) {
            'github.com/axisvela/praxo-core/v2/pkg/example'
            'github.com/axisvela/praxo-core/v2/pkg/second'
        }
        return
    }
    'type Example struct {'
    "`tName $($state.FieldType)"
    '}'
    "func Generate() $($state.ReturnType)"
}

function Assert-SnapshotFailure([string]$Expected, [string]$Path = $baseline, [switch]$Generate) {
    $failed = $false
    try {
        if ($Generate) { & $script -OutFile $Path } else { & $script -OutFile $Path -Check }
    } catch {
        if ($_.Exception.Message -notlike "*$Expected*") { throw }
        $failed = $true
    }
    if (-not $failed) { throw "snapshot accepted $Expected" }
}

try {
    $env:GOWORK = 'preserved-workspace'
    & $script -OutFile $baseline
    if ($state.Calls -ne 3 -or $env:GOWORK -ne 'preserved-workspace') {
        throw 'snapshot generation skipped packages or did not restore GOWORK'
    }
    $original = [System.IO.File]::ReadAllText($baseline)
    $stamp = [datetime]'2001-01-01T00:00:00Z'
    [System.IO.File]::SetLastWriteTimeUtc($baseline, $stamp)
    $stamp = [System.IO.File]::GetLastWriteTimeUtc($baseline)
    & $script -OutFile $baseline -Check
    if ([System.IO.File]::GetLastWriteTimeUtc($baseline) -ne $stamp) {
        throw 'check rewrote baseline'
    }
    $state.FieldType = 'int'
    Assert-SnapshotFailure 'differs from current source'
    $state.FieldType = 'string'
    $state.ReturnType = 'bool'
    Assert-SnapshotFailure 'differs from current source'
    $state.ReturnType = 'string'
    if ([System.IO.File]::ReadAllText($baseline) -cne $original) {
        throw 'failed check changed baseline'
    }
    [System.IO.File]::WriteAllText($baseline, $original.Replace("`n", "`r`n"))
    & $script -OutFile $baseline -Check
    $missing = Join-Path $temp 'missing.txt'
    Assert-SnapshotFailure 'snapshot missing' $missing
    if (Test-Path $missing) { throw 'check generated a missing baseline' }
    foreach ($failAt in 1..3) {
        $state.Calls = 0
        $state.FailAt = $failAt
        Assert-SnapshotFailure 'failed (exit 23)' $missing -Generate
        if ($state.Calls -ne $failAt -or (Test-Path $missing)) {
            throw "generation continued or wrote output after failure $failAt"
        }
        if ($env:GOWORK -ne 'preserved-workspace') { throw 'failure did not restore GOWORK' }
    }
    $state.Calls = 0
    $state.FailAt = 0
    $state.Empty = $true
    Assert-SnapshotFailure 'no public packages' $missing -Generate
    if (Test-Path $missing) { throw 'empty package result generated a baseline' }
    Write-Output 'API snapshot check, drift, failure propagation, and environment tests passed'
} finally {
    $env:GOWORK = $priorGoWork
    $global:LASTEXITCODE = $priorExitCode
    Remove-Item -LiteralPath $temp -Recurse -Force
}
