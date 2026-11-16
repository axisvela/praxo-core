function New-ServicePrincipal {
    param(
        [string]$Subject,
        [string]$Tenant,
        [Int64]$Expires
    )
    [pscustomobject]@{
        Subject = $Subject
        Tenant = $Tenant
        Expires = $Expires
    }
}

function Get-ServiceBasicAuthorization {
    param(
        [string]$ClientId,
        [string]$ClientSecret
    )
    if ([string]::IsNullOrEmpty($ClientId)) {
        return $null
    }
    $raw = "${ClientId}:${ClientSecret}"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
    return 'Basic ' + [Convert]::ToBase64String($bytes)
}

function New-ServiceIntrospectionAuthenticator {
    param(
        [scriptblock]$Transport,
        [string]$Endpoint,
        [string]$ClientId = '',
        [string]$ClientSecret = '',
        [string]$TenantClaim = 'tenant'
    )
    if ([string]::IsNullOrEmpty($TenantClaim)) {
        $TenantClaim = 'tenant'
    }
    $authorization = Get-ServiceBasicAuthorization -ClientId $ClientId -ClientSecret $ClientSecret
    [pscustomobject]@{
        Transport = $Transport
        Endpoint = $Endpoint
        ClientId = $ClientId
        ClientSecret = $ClientSecret
        TenantClaim = $TenantClaim
        Authorization = $authorization
    }
}

function New-ServiceRevocationClient {
    param(
        [scriptblock]$Transport,
        [string]$Endpoint,
        [string]$ClientId = '',
        [string]$ClientSecret = ''
    )
    $authorization = Get-ServiceBasicAuthorization -ClientId $ClientId -ClientSecret $ClientSecret
    [pscustomobject]@{
        Transport = $Transport
        Endpoint = $Endpoint
        ClientId = $ClientId
        ClientSecret = $ClientSecret
        Authorization = $authorization
    }
}

function Invoke-ServiceAuthentication {
    param(
        $Authenticator,
        [string]$Authorization,
        [Nullable[Int64]]$Now = $null
    )
    if ($null -eq $Authenticator) {
        return $null
    }
    if ([string]::IsNullOrEmpty($Authorization)) {
        return $null
    }
    if (-not $Authorization.StartsWith('Bearer ')) {
        return $null
    }
    $token = $Authorization.Substring(7).Trim()
    if ([string]::IsNullOrEmpty($token)) {
        return $null
    }
    if ($null -eq $Now) {
        $nowSeconds = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
    } else {
        $nowSeconds = [int64]$Now
    }
    $form = @{
        token = $token
        client_id = $Authenticator.ClientId
        client_secret = $Authenticator.ClientSecret
    }
    try {
        $response = & $Authenticator.Transport $Authenticator.Endpoint $form $Authenticator.Authorization
    } catch {
        return $null
    }
    if ($null -eq $response) {
        return $null
    }
    try {
        $status = [int]$response.Status
    } catch {
        return $null
    }
    if ($status -ne 200) {
        return $null
    }
    try {
        $payload = $response.Body | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return $null
    }
    if ($null -eq $payload -or $payload -isnot [System.Management.Automation.PSCustomObject]) {
        return $null
    }
    $active = $payload.PSObject.Properties['active']
    if ($null -eq $active -or $active.Value -isnot [bool] -or -not $active.Value) {
        return $null
    }
    $subject = $payload.PSObject.Properties['sub']
    if ($null -eq $subject -or $subject.Value -isnot [string] -or
        [string]::IsNullOrEmpty($subject.Value)) {
        return $null
    }
    $tenant = $payload.PSObject.Properties[$Authenticator.TenantClaim]
    if ($null -eq $tenant -or $tenant.Value -isnot [string] -or
        [string]::IsNullOrEmpty($tenant.Value)) {
        return $null
    }
    $expires = $payload.PSObject.Properties['exp']
    if ($null -eq $expires -or $null -eq $expires.Value -or
        $expires.Value -is [bool] -or $expires.Value -is [string]) {
        return $null
    }
    try {
        $expiresValue = [double]$expires.Value
    } catch {
        return $null
    }
    if ([math]::Floor($expiresValue) -ne $expiresValue) {
        return $null
    }
    if ($expiresValue -le $nowSeconds) {
        return $null
    }
    New-ServicePrincipal -Subject $subject.Value -Tenant $tenant.Value -Expires ([int64]$expiresValue)
}

function Invoke-ServiceRevocation {
    param(
        $Client,
        [string]$Token
    )
    if ($null -eq $Client -or [string]::IsNullOrEmpty($Token)) {
        throw 'revocation token is required'
    }
    $form = @{
        token = $Token
        token_type_hint = 'access_token'
        client_id = $Client.ClientId
        client_secret = $Client.ClientSecret
    }
    try {
        $response = & $Client.Transport $Client.Endpoint $form $Client.Authorization
    } catch {
        throw 'token revocation failed'
    }
    if ($null -eq $response) {
        throw 'token revocation failed'
    }
    try {
        $status = [int]$response.Status
    } catch {
        throw 'token revocation failed'
    }
    if ($status -ne 200) {
        throw 'token revocation failed'
    }
    return $true
}
