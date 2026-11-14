<?php

declare(strict_types=1);

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

echo "PHP service example passed\n";
