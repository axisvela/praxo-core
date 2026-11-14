function Invoke-Fallback {
    param([bool]$PrimaryFails, [bool]$FallbackFails)
    if (-not $PrimaryFails) { return 'primary' }
    if (-not $FallbackFails) { return 'fallback' }
    return 'MODEL_UNAVAILABLE'
}

if ((Invoke-Fallback -PrimaryFails $false -FallbackFails $false) -ne 'primary') {
    throw 'primary path failed'
}
if ((Invoke-Fallback -PrimaryFails $true -FallbackFails $false) -ne 'fallback') {
    throw 'fallback path failed'
}
if ((Invoke-Fallback -PrimaryFails $true -FallbackFails $true) -ne 'MODEL_UNAVAILABLE') {
    throw 'both-failure path failed'
}
Write-Output 'PowerShell provider fallback example passed'
