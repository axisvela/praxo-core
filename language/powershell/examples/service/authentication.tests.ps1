$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'authentication.ps1')

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "assertion failed: $Message"
    }
}

function Reset-Transport {
    $script:calls = @()
    $script:status = 200
    $script:body = ''
    $script:throwTransport = $false
}

$script:calls = @()
$script:status = 200
$script:body = ''
$script:throwTransport = $false

$script:fakeTransport = {
    param($Url, $Form, $Authorization)
    $script:calls += [pscustomobject]@{
        Url = $Url
        Form = $Form
        Authorization = $Authorization
    }
    if ($script:throwTransport) {
        throw 'transport down'
    }
    [pscustomobject]@{ Status = $script:status; Body = $script:body }
}

$activeBody = '{"active":true,"sub":"alice","tenant":"acme","exp":200}'
$auth = New-ServiceIntrospectionAuthenticator -Transport $script:fakeTransport `
    -Endpoint 'https://issuer.example/introspect' `
    -ClientId 'client' -ClientSecret 'secret'

Reset-Transport
$script:body = $activeBody
$principal = Invoke-ServiceAuthentication -Authenticator $auth `
    -Authorization 'Bearer token-1' -Now 100
Assert-True ($null -ne $principal) 'success principal'
Assert-True ($principal.Subject -eq 'alice') 'success subject'
Assert-True ($principal.Tenant -eq 'acme') 'success tenant'
Assert-True ($principal.Expires -eq 200) 'success expiry'
Assert-True ($script:calls.Count -eq 1) 'success transport count'
$call = $script:calls[0]
Assert-True ($call.Url -eq 'https://issuer.example/introspect') 'introspection url'
Assert-True ($call.Form['token'] -eq 'token-1') 'introspection token'
Assert-True ($call.Form['client_id'] -eq 'client') 'introspection client id'
Assert-True ($call.Form['client_secret'] -eq 'secret') 'introspection client secret'
Assert-True ($call.Authorization -eq 'Basic Y2xpZW50OnNlY3JldA==') 'introspection basic auth'

$before = $script:calls.Count
Assert-True ($null -eq (Invoke-ServiceAuthentication -Authenticator $auth `
    -Authorization 'Token token-1' -Now 100)) 'wrong scheme rejected'
Assert-True ($null -eq (Invoke-ServiceAuthentication -Authenticator $auth `
    -Authorization '' -Now 100)) 'missing scheme rejected'
Assert-True ($null -eq (Invoke-ServiceAuthentication -Authenticator $auth `
    -Authorization 'Bearer    ' -Now 100)) 'empty token rejected'
Assert-True ($script:calls.Count -eq $before) 'malformed authorization avoids transport'

Reset-Transport
$script:body = '{"active":false,"sub":"alice","tenant":"acme","exp":200}'
Assert-True ($null -eq (Invoke-ServiceAuthentication -Authenticator $auth `
    -Authorization 'Bearer token-1' -Now 100)) 'inactive rejected'

Reset-Transport
$script:body = '{"active":"true","sub":"alice","tenant":"acme","exp":200}'
Assert-True ($null -eq (Invoke-ServiceAuthentication -Authenticator $auth `
    -Authorization 'Bearer token-1' -Now 100)) 'non-boolean active rejected'

Reset-Transport
$script:body = '{"active":true,"tenant":"acme","exp":200}'
Assert-True ($null -eq (Invoke-ServiceAuthentication -Authenticator $auth `
    -Authorization 'Bearer token-1' -Now 100)) 'missing subject rejected'

Reset-Transport
$script:body = '{"active":true,"sub":"","tenant":"acme","exp":200}'
Assert-True ($null -eq (Invoke-ServiceAuthentication -Authenticator $auth `
    -Authorization 'Bearer token-1' -Now 100)) 'empty subject rejected'

Reset-Transport
$script:body = '{"active":true,"sub":"alice","exp":200}'
Assert-True ($null -eq (Invoke-ServiceAuthentication -Authenticator $auth `
    -Authorization 'Bearer token-1' -Now 100)) 'missing tenant rejected'

Reset-Transport
$script:body = '{"active":true,"sub":"alice","tenant":"","exp":200}'
Assert-True ($null -eq (Invoke-ServiceAuthentication -Authenticator $auth `
    -Authorization 'Bearer token-1' -Now 100)) 'empty tenant rejected'

Reset-Transport
$script:body = '{"active":true,"sub":"alice","tenant":"acme"}'
Assert-True ($null -eq (Invoke-ServiceAuthentication -Authenticator $auth `
    -Authorization 'Bearer token-1' -Now 100)) 'missing expiry rejected'

Reset-Transport
$script:body = '{"active":true,"sub":"alice","tenant":"acme","exp":200.5}'
Assert-True ($null -eq (Invoke-ServiceAuthentication -Authenticator $auth `
    -Authorization 'Bearer token-1' -Now 100)) 'non-integer expiry rejected'

Reset-Transport
$script:body = '{"active":true,"sub":"alice","tenant":"acme","exp":"200"}'
Assert-True ($null -eq (Invoke-ServiceAuthentication -Authenticator $auth `
    -Authorization 'Bearer token-1' -Now 100)) 'string expiry rejected'

Reset-Transport
$script:body = '{"active":true,"sub":"alice","tenant":"acme","exp":100}'
Assert-True ($null -eq (Invoke-ServiceAuthentication -Authenticator $auth `
    -Authorization 'Bearer token-1' -Now 100)) 'expired token rejected'

Reset-Transport
$script:body = 'not json'
Assert-True ($null -eq (Invoke-ServiceAuthentication -Authenticator $auth `
    -Authorization 'Bearer token-1' -Now 100)) 'malformed json rejected'

Reset-Transport
$script:body = $activeBody
$script:status = 401
Assert-True ($null -eq (Invoke-ServiceAuthentication -Authenticator $auth `
    -Authorization 'Bearer token-1' -Now 100)) 'non-200 rejected'

Reset-Transport
$script:body = $activeBody
$script:throwTransport = $true
Assert-True ($null -eq (Invoke-ServiceAuthentication -Authenticator $auth `
    -Authorization 'Bearer token-1' -Now 100)) 'transport error rejected'

$custom = New-ServiceIntrospectionAuthenticator -Transport $script:fakeTransport `
    -Endpoint 'https://issuer.example/introspect' `
    -ClientId 'client' -ClientSecret 'secret' -TenantClaim 'workspace'
Reset-Transport
$script:body = '{"active":true,"sub":"alice","workspace":"team-a","exp":200}'
$customPrincipal = Invoke-ServiceAuthentication -Authenticator $custom `
    -Authorization 'Bearer token-1' -Now 100
Assert-True ($null -ne $customPrincipal) 'custom tenant principal'
Assert-True ($customPrincipal.Tenant -eq 'team-a') 'custom tenant claim'

$anonymous = New-ServiceIntrospectionAuthenticator -Transport $script:fakeTransport `
    -Endpoint 'https://issuer.example/introspect'
Reset-Transport
$script:body = $activeBody
$anonymousPrincipal = Invoke-ServiceAuthentication -Authenticator $anonymous `
    -Authorization 'Bearer token-1' -Now 100
Assert-True ($null -ne $anonymousPrincipal) 'anonymous client principal'
$anonymousCall = $script:calls[0]
Assert-True ($null -eq $anonymousCall.Authorization) 'anonymous client omits basic auth'
Assert-True ($anonymousCall.Form['client_id'] -eq '') 'anonymous client id'
Assert-True ($anonymousCall.Form['client_secret'] -eq '') 'anonymous client secret'

$revocation = New-ServiceRevocationClient -Transport $script:fakeTransport `
    -Endpoint 'https://issuer.example/revoke' `
    -ClientId 'client' -ClientSecret 'secret'
Reset-Transport
Assert-True (Invoke-ServiceRevocation -Client $revocation -Token 'token-2') `
    'revocation success'
$revokeCall = $script:calls[0]
Assert-True ($revokeCall.Url -eq 'https://issuer.example/revoke') 'revocation url'
Assert-True ($revokeCall.Form['token'] -eq 'token-2') 'revocation token'
Assert-True ($revokeCall.Form['token_type_hint'] -eq 'access_token') 'revocation hint'
Assert-True ($revokeCall.Authorization -eq 'Basic Y2xpZW50OnNlY3JldA==') `
    'revocation basic auth'

Reset-Transport
$script:status = 400
$thrown = $false
try {
    Invoke-ServiceRevocation -Client $revocation -Token 'token-2' | Out-Null
} catch {
    $thrown = $true
}
Assert-True $thrown 'revocation non-200 rejected'

Reset-Transport
$script:throwTransport = $true
$thrown = $false
try {
    Invoke-ServiceRevocation -Client $revocation -Token 'token-2' | Out-Null
} catch {
    $thrown = $true
}
Assert-True $thrown 'revocation transport error rejected'

Reset-Transport
$thrown = $false
try {
    Invoke-ServiceRevocation -Client $revocation -Token '' | Out-Null
} catch {
    $thrown = $true
}
Assert-True $thrown 'empty revocation token rejected'
Assert-True ($script:calls.Count -eq 0) 'empty revocation avoids transport'

$anonymousRevocation = New-ServiceRevocationClient -Transport $script:fakeTransport `
    -Endpoint 'https://issuer.example/revoke'
Reset-Transport
Invoke-ServiceRevocation -Client $anonymousRevocation -Token 'token-3' | Out-Null
Assert-True ($null -eq $script:calls[0].Authorization) `
    'revocation without client id omits basic auth'

Write-Output 'PowerShell service authentication tests passed'
