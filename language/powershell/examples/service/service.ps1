function Invoke-Handler {
    param([string]$Method, [string]$Path, [string]$Principal, [string]$Body)
    if ($Method -eq 'GET' -and $Path -eq '/healthz') {
        return [pscustomobject]@{ Status = 200; Body = '{"status":"ok"}' }
    }
    if ($Method -ne 'POST' -or $Path -ne '/run') {
        return [pscustomobject]@{ Status = 404; Body = '{"error":"not found"}' }
    }
    if ([string]::IsNullOrEmpty($Principal)) {
        return [pscustomobject]@{ Status = 401; Body = '{"error":"missing X-Praxo-Principal"}' }
    }
    if (-not $Body.Contains('"prompt"')) {
        return [pscustomobject]@{ Status = 400; Body = '{"error":"prompt is required"}' }
    }
    [pscustomobject]@{ Status = 200; Body = '{"output":"hello from the service"}' }
}

if ((Invoke-Handler -Method 'GET' -Path '/healthz' -Principal '' -Body '').Status -ne 200) {
    throw 'health failed'
}
if ((Invoke-Handler -Method 'POST' -Path '/run' -Principal '' -Body '{"prompt":"hi"}').Status -ne 401) {
    throw 'missing principal accepted'
}
if ((Invoke-Handler -Method 'POST' -Path '/run' -Principal 'user-1' -Body '{"prompt":"hi"}').Status -ne 200) {
    throw 'run failed'
}
Write-Output 'PowerShell service example passed'
