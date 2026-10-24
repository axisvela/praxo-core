$ErrorActionPreference = 'Stop'
$priorGoWork = $env:GOWORK
$priorExitCode = $global:LASTEXITCODE
$state = @{ Calls = 0; FailAt = 0 }

function go {
    $state.Calls++
    $global:LASTEXITCODE = if ($state.Calls -eq $state.FailAt) { 23 } else { 0 }
}

try {
    foreach ($failAt in 1..10) {
        $state.Calls = 0
        $state.FailAt = $failAt
        $failed = $false
        try {
            & (Join-Path $PSScriptRoot 'release-check.ps1') -Race -Fuzz
        } catch {
            if ($_.Exception.Message -notlike '*failed (exit 23)') { throw }
            $failed = $true
        }
        if (-not $failed -or $state.Calls -ne $failAt) {
            throw "release-check did not stop at failed Go step $failAt"
        }
    }
    $state.Calls = 0
    $state.FailAt = 0
    & (Join-Path $PSScriptRoot 'release-check.ps1') -Race -Fuzz
    if ($state.Calls -ne 10) { throw 'release-check skipped a successful Go step' }
    Write-Output 'release-check failure propagation: 10 failures and success path passed'
} finally {
    $env:GOWORK = $priorGoWork
    $global:LASTEXITCODE = $priorExitCode
}
