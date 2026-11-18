$ErrorActionPreference = 'Stop'
$pwsh = (Get-Process -Id $PID).Path
$consumer = Join-Path $PSScriptRoot 'consumer.ps1'

$start = [System.Diagnostics.ProcessStartInfo]::new($pwsh)
$start.UseShellExecute = $false
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$start.Environment.Remove('PRAXO_CORE_DLL') | Out-Null
$start.ArgumentList.Add('-NoProfile')
$start.ArgumentList.Add('-File')
$start.ArgumentList.Add($consumer)

$process = [System.Diagnostics.Process]::Start($start)
$stdout = $process.StandardOutput.ReadToEndAsync()
$stderr = $process.StandardError.ReadToEndAsync()
if (-not $process.WaitForExit(60000)) {
    $process.Kill($true)
    throw 'Source consumer timed out'
}
if ($process.ExitCode -ne 0 -or
    $stdout.Result -notmatch 'allow: recorded; effects=1' -or
    $stdout.Result -notmatch 'deny: policy rejected; effects=0') {
    throw "Source consumer failed: $($stdout.Result) $($stderr.Result)"
}
$process.Dispose()

$emptyModules = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
[System.IO.Directory]::CreateDirectory($emptyModules) | Out-Null
try {
    $start.Environment['PSModulePath'] = $emptyModules
    $start.ArgumentList.Add('-UseInstalledModule')
    $process = [System.Diagnostics.Process]::Start($start)
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(60000)) {
        $process.Kill($true)
        throw 'Installed consumer timed out'
    }
    if ($process.ExitCode -eq 0 -or $stderr.Result -notmatch 'Import-Module' -or
        $stdout.Result -match 'allow: recorded') {
        throw 'Missing installed package must fail without source fallback'
    }
    $process.Dispose()

    $start.Environment['PRAXO_CORE_DLL'] = 'untrusted-override.dll'
    $process = [System.Diagnostics.Process]::Start($start)
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(60000)) {
        $process.Kill($true)
        throw 'Assembly override check timed out'
    }
    if ($process.ExitCode -eq 0 -or $stderr.Result -notmatch 'Unset PRAXO_CORE_DLL') {
        throw 'Installed mode must reject an assembly override'
    }
    $process.Dispose()
} finally {
    [System.IO.Directory]::Delete($emptyModules)
}

Write-Output 'PowerShell consumer module selection: 3/3 passed'
