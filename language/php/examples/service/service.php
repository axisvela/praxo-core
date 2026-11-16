<?php

declare(strict_types=1);

require_once __DIR__ . '/authentication.php';

final class ScriptedTransport implements IntrospectionTransport
{
    /** @var list<string> */
    public array $forms = [];
    public bool $unavailable = false;

    public function __construct(private int $status, private string $body)
    {
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
