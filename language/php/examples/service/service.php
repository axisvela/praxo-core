<?php

declare(strict_types=1);

require_once __DIR__ . '/authentication.php';

final class ScriptedTransport implements IntrospectionTransport
{
    /** @var list<string> */
    public array $forms = [];
    public bool $unavailable = false;

    public function __construct(
        private int $status,
        private string $body,
        private array $getRoutes = [],
    ) {
    }

    public function getJson(string $url): array
    {
        return $this->getRoutes[$url] ?? [404, '{}'];
    }

    public function postForm(string $url, string $form, ?string $authorization): array
    {
        $this->forms[] = $form;
        if ($this->unavailable) {
            throw new AuthError('identity provider unavailable');
        }
        return [$this->status, $this->body];
    }
}

function handleRequest(string $method, string $path, ?string $principal, string $body): array
{
    if ($method === 'GET' && $path === '/healthz') {
        return [200, ['status' => 'ok']];
    }
    if ($method !== 'POST' || $path !== '/run') {
        return [404, ['error' => 'not found']];
    }
    if ($principal === null || $principal === '') {
        return [401, ['error' => 'missing X-Praxo-Principal']];
    }
    if (!str_contains($body, '"prompt"')) {
        return [400, ['error' => 'prompt is required']];
    }
    return [200, ['output' => 'hello from the service']];
}

[$status, $body] = handleRequest('GET', '/healthz', null, '');
if ($status !== 200 || $body['status'] !== 'ok') {
    throw new RuntimeException('health failed');
}
[$status] = handleRequest('POST', '/run', null, '{"prompt":"hi"}');
if ($status !== 401) {
    throw new RuntimeException('missing principal was accepted');
}
[$status, $body] = handleRequest('POST', '/run', 'user-1', '{"prompt":"hi"}');
if ($status !== 200 || $body['output'] !== 'hello from the service') {
    throw new RuntimeException('run failed');
}

$now = time();
$active = new ScriptedTransport(200, json_encode([
    'active' => true,
    'sub' => 'user-1',
    'tenant' => 'local',
    'exp' => $now + 60,
]));
$authenticator = new IntrospectionAuthenticator(
    $active,
    'https://id.example.com/introspect',
);
$principal = $authenticator->authenticate('Bearer opaque-token', $now);
if ($principal === null
    || $principal->subject !== 'user-1'
    || $principal->tenant !== 'local') {
    throw new RuntimeException('active token was rejected');
}

$inactive = new ScriptedTransport(200, json_encode(['active' => false]));
$inactiveAuth = new IntrospectionAuthenticator(
    $inactive,
    'https://id.example.com/introspect',
);
if ($inactiveAuth->authenticate('Bearer opaque-token', $now) !== null) {
    throw new RuntimeException('inactive token was accepted');
}

$missing = new ScriptedTransport(200, json_encode([
    'active' => true,
    'sub' => 'user-1',
    'tenant' => 'local',
]));
$missingAuth = new IntrospectionAuthenticator(
    $missing,
    'https://id.example.com/introspect',
);
if ($missingAuth->authenticate('Bearer opaque-token', $now) !== null) {
    throw new RuntimeException('missing expiration was accepted');
}

$unavailable = new ScriptedTransport(200, '{}');
$unavailable->unavailable = true;
$unavailableAuth = new IntrospectionAuthenticator(
    $unavailable,
    'https://id.example.com/introspect',
);
if ($unavailableAuth->authenticate('Bearer opaque-token', $now) !== null) {
    throw new RuntimeException('unavailable provider was accepted');
}

function base64Url(string $value): string
{
    return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
}

$oidcKey = openssl_pkey_new([
    'private_key_bits' => 2048,
    'private_key_type' => OPENSSL_KEYTYPE_RSA,
]);
$oidcDetails = openssl_pkey_get_details($oidcKey);
$oidcIssuer = 'https://issuer.example.com';
$oidcJwksUrl = $oidcIssuer . '/jwks';
$oidcDiscovery = $oidcIssuer . '/.well-known/openid-configuration';
$oidcJwks = json_encode(['keys' => [[
    'kid' => 'test-key',
    'kty' => 'RSA',
    'use' => 'sig',
    'alg' => 'RS256',
    'n' => base64Url($oidcDetails['rsa']['n']),
    'e' => base64Url($oidcDetails['rsa']['e']),
]]]);
$oidcMetadata = json_encode([
    'issuer' => $oidcIssuer,
    'jwks_uri' => $oidcJwksUrl,
]);
$oidcTransport = new ScriptedTransport(200, '{}', [
    $oidcDiscovery => [200, $oidcMetadata],
    $oidcJwksUrl => [200, $oidcJwks],
]);
$oidc = new OidcAuthenticator($oidcTransport, $oidcIssuer, 'praxo-service');
$oidcClaims = static fn (string $issuer, string $audience, int $expires): array => [
    'iss' => $issuer,
    'aud' => $audience,
    'sub' => 'user-1',
    'tenant' => 'local',
    'exp' => $expires,
];
$signOidc = static function (array $claims, string $kid = 'test-key') use ($oidcKey): string {
    $header = base64Url(json_encode(['alg' => 'RS256', 'kid' => $kid, 'typ' => 'JWT']));
    $payload = base64Url(json_encode($claims));
    $input = $header . '.' . $payload;
    openssl_sign($input, $signature, $oidcKey, OPENSSL_ALGO_SHA256);
    return $input . '.' . base64Url($signature);
};
$allowed = $oidc->authenticate(
    'Bearer ' . $signOidc($oidcClaims($oidcIssuer, 'praxo-service', $now + 60)),
    $now,
);
if ($allowed === null || $allowed->subject !== 'user-1' || $allowed->tenant !== 'local') {
    throw new RuntimeException('OIDC allowed token was rejected');
}
if ($oidc->authenticate(
    'Bearer ' . $signOidc($oidcClaims($oidcIssuer, 'other-service', $now + 60)),
    $now,
) !== null) {
    throw new RuntimeException('OIDC wrong audience was accepted');
}
if ($oidc->authenticate(
    'Bearer ' . $signOidc($oidcClaims($oidcIssuer, 'praxo-service', $now - 60)),
    $now,
) !== null) {
    throw new RuntimeException('OIDC expired token was accepted');
}
if ($oidc->authenticate(
    'Bearer ' . $signOidc($oidcClaims('https://wrong.example.com', 'praxo-service', $now + 60)),
    $now,
) !== null) {
    throw new RuntimeException('OIDC wrong issuer was accepted');
}
if ($oidc->authenticate(
    'Bearer ' . $signOidc($oidcClaims($oidcIssuer, 'praxo-service', $now + 60), 'other-key'),
    $now,
) !== null) {
    throw new RuntimeException('OIDC unknown key was accepted');
}
$unavailableOidc = new OidcAuthenticator(
    new ScriptedTransport(200, '{}'),
    $oidcIssuer,
    'praxo-service',
);
if ($unavailableOidc->authenticate(
    'Bearer ' . $signOidc($oidcClaims($oidcIssuer, 'praxo-service', $now + 60)),
    $now,
) !== null) {
    throw new RuntimeException('unavailable OIDC provider was accepted');
}

$revocation = new RevocationClient(
    $active,
    'https://id.example.com/revoke',
);
$revocation->revoke('opaque-token');
$lastForm = $active->forms[count($active->forms) - 1] ?? '';
if (!str_contains($lastForm, 'token=opaque-token')) {
    throw new RuntimeException('revocation did not post the token');
}

$failedRevocation = new ScriptedTransport(503, '{}');
$failedClient = new RevocationClient(
    $failedRevocation,
    'https://id.example.com/revoke',
);
try {
    $failedClient->revoke('opaque-token');
    throw new RuntimeException('revocation failure was accepted');
} catch (AuthError) {
}

$context = new ContextAuthenticator('local');
if ($context->authenticate('user-1')?->tenant !== 'local') {
    throw new RuntimeException('context principal failed');
}

echo "PHP service example passed\n";
echo "PHP service auth tests passed\n";
