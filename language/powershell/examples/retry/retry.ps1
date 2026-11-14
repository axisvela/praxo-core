function Invoke-Retry {
    param([int]$Failures, [int]$MaxAttempts = 3)
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        if ($attempt -gt $Failures) {
            return @{ Output = 'status: green'; Calls = $attempt }
        }
    }
    return @{ Code = 'MODEL_UNAVAILABLE'; Calls = $MaxAttempts }
}

$recovered = Invoke-Retry -Failures 2
if ($recovered.Output -ne 'status: green' -or $recovered.Calls -ne 3) {
    throw 'transient retry failed'
}
$exhausted = Invoke-Retry -Failures 3
if ($exhausted.Code -ne 'MODEL_UNAVAILABLE' -or $exhausted.Calls -ne 3) {
    throw 'exhausted retry failed'
}
Write-Output 'PowerShell retry example passed'
