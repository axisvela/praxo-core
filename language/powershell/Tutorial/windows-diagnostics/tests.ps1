param(
    [switch]$SourceMode,
    [switch]$IncludeLocalMachine
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$script = Join-Path $PSScriptRoot 'diagnostics.ps1'
$common = @('-NoProfile', '-NonInteractive', '-File', $script)
if ($SourceMode) { $common += '-SourceMode' }

$success = @(& pwsh @common 2>&1)
if ($LASTEXITCODE -ne 0) { throw "fixture success failed: $success" }
$report = ($success -join "`n") | ConvertFrom-Json
if ($report.read_calls -ne 2) { throw "expected two reads, got $($report.read_calls)" }
if ($report.checks.Count -ne 2) { throw "expected two checks, got $($report.checks.Count)" }
if ($report.mutating_tools_registered -ne $false) { throw 'mutating tools were registered' }
Write-Output 'fixture success: passed'

$denied = @(& pwsh @common -ServiceName WinRM 2>&1)
if ($LASTEXITCODE -eq 0) { throw 'out-of-scope service was not denied' }
if (($denied -join "`n") -notmatch 'reads=0') { throw "denial produced reads: $denied" }
Write-Output 'policy denial: passed'

$failed = @(& pwsh @common -SimulateFailure 2>&1)
if ($LASTEXITCODE -eq 0) { throw 'simulated dependency failure did not fail' }
if (($failed -join "`n") -notmatch 'reads=1') { throw "failure read count mismatch: $failed" }
Write-Output 'dependency failure: passed'

if ($IncludeLocalMachine) {
    if (-not $IsWindows) { throw 'IncludeLocalMachine requires Windows' }
    $local = @(& pwsh @common -LocalMachine 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "local diagnostics failed: $local" }
    $localReport = ($local -join "`n") | ConvertFrom-Json
    if ($localReport.read_calls -ne 2) { throw 'local diagnostics did not perform two reads' }
    if (@($localReport.checks | Where-Object source -ne 'local_machine').Count -ne 0) {
        throw 'local diagnostics did not mark source=local_machine'
    }
    Write-Output 'local read-only diagnostics: passed'
}

Write-Output 'PowerShell windows-diagnostics tutorial: all checks passed'
