function Test-IdentityPolicy {
    param($Principal, [string]$Tool, [string]$Tenant)
    if ($null -eq $Principal) { return $false }
    if (-not $Principal.Active) { return $false }
    if ($Principal.Role -ne 'operator') { return $false }
    if ($Principal.Tenant -ne $Tenant) { return $false }
    return $Tool -eq 'record'
}

$operator = [pscustomobject]@{ Tenant = 'acme'; Role = 'operator'; Active = $true }
if (-not (Test-IdentityPolicy -Principal $operator -Tool 'record' -Tenant 'acme')) {
    throw 'operator denied'
}
$viewer = [pscustomobject]@{ Tenant = 'acme'; Role = 'viewer'; Active = $true }
if (Test-IdentityPolicy -Principal $viewer -Tool 'record' -Tenant 'acme') {
    throw 'viewer allowed'
}
if (Test-IdentityPolicy -Principal $operator -Tool 'record' -Tenant 'other') {
    throw 'tenant mismatch allowed'
}
if (Test-IdentityPolicy -Principal $null -Tool 'record' -Tenant 'acme') {
    throw 'missing principal allowed'
}
Write-Output 'PowerShell identity policy example passed'
