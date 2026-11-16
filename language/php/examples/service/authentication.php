<?php

declare(strict_types=1);

final class AuthenticatedPrincipal
{
    public function __construct(
        public string $subject,
        public string $tenant,
        public ?int $expires,
    ) {
    }
}

final class AuthError extends RuntimeException
{
}

interface IntrospectionTransport
{
    /** @return array{0:int,1:string} */
    public function postForm(string $url, string $form, ?string $authorization): array;
}

final class StreamTransport implements IntrospectionTransport
{
    public function postForm(string $url, string $form, ?string $authorization): array
    {
        $headers = "Content-Type: application/x-www-form-urlencoded\r\n";
        if ($authorization !== null) {
            $headers .= "Authorization: {$authorization}\r\n";
        }
        $context = stream_context_create([
            'http' => [
                'method' => 'POST',
                'header' => $headers,
                'content' => $form,
                'timeout' => 2,
                'ignore_errors' => true,
            ],
        ]);
        $body = @file_get_contents($url, false, $context);
        if ($body === false) {
            throw new AuthError('identity provider unavailable');
        }
        $status = 0;
        foreach ($http_response_header ?? [] as $line) {
            if (preg_match('#^HTTP/\S+\s+(\d{3})#', $line, $matches) === 1) {
                $status = (int) $matches[1];
            }
        }
        if ($status === 0) {
            throw new AuthError('identity provider unavailable');
        }
        return [$status, $body];
    }
}

final class ContextAuthenticator
{
    public function __construct(private string $tenant)
    {
    }

    public function authenticate(
        ?string $principal,
        ?string $authorization = null,
        ?int $now = null,
    ): ?AuthenticatedPrincipal {
        if ($principal === null || $principal === '') {
            return null;
        }
        return new AuthenticatedPrincipal($principal, $this->tenant, null);
    }
}

final class IntrospectionAuthenticator
{
    public function __construct(
        private IntrospectionTransport $transport,
        private string $endpoint,
        private string $clientId = '',
        private string $clientSecret = '',
        private string $tenantClaim = 'tenant',
    ) {
        if ($this->tenantClaim === '') {
            $this->tenantClaim = 'tenant';
        }
    }

    public function authenticate(
        ?string $authorization,
        ?int $now = null,
    ): ?AuthenticatedPrincipal {
        if ($authorization === null
            || !str_starts_with($authorization, 'Bearer ')) {
            return null;
        }
        $token = trim(substr($authorization, 7));
        if ($token === '') {
            return null;
        }
        $now ??= time();
        try {
            [$status, $body] = $this->transport->postForm(
                $this->endpoint,
                http_build_query([
                    'token' => $token,
                    'client_id' => $this->clientId,
                    'client_secret' => $this->clientSecret,
                ]),
                $this->basicAuth(),
            );
        } catch (AuthError) {
            return null;
        }
        if ($status !== 200) {
            return null;
        }
        $payload = json_decode($body, true);
        if (!is_array($payload) || ($payload['active'] ?? false) !== true) {
            return null;
        }
        $subject = $payload['sub'] ?? null;
        $tenant = $payload[$this->tenantClaim] ?? null;
        $expires = $payload['exp'] ?? null;
        if (!is_string($subject) || $subject === ''
            || !is_string($tenant) || $tenant === ''
            || !is_int($expires) || $expires <= $now) {
            return null;
        }
        return new AuthenticatedPrincipal($subject, $tenant, $expires);
    }

    private function basicAuth(): ?string
    {
        if ($this->clientId === '') {
            return null;
        }
        $raw = "{$this->clientId}:{$this->clientSecret}";
        return 'Basic ' . base64_encode($raw);
    }
}

final class RevocationClient
{
    public function __construct(
        private IntrospectionTransport $transport,
        private string $endpoint,
        private string $clientId = '',
        private string $clientSecret = '',
    ) {
    }

    public function revoke(string $token): bool
    {
        if ($token === '') {
            throw new AuthError('revocation token is required');
        }
        try {
            [$status] = $this->transport->postForm(
                $this->endpoint,
                http_build_query([
                    'token' => $token,
                    'token_type_hint' => 'access_token',
                    'client_id' => $this->clientId,
                    'client_secret' => $this->clientSecret,
                ]),
                $this->basicAuth(),
            );
        } catch (AuthError $error) {
            throw new AuthError('token revocation failed', 0, $error);
        }
        if ($status !== 200) {
            throw new AuthError('token revocation failed');
        }
        return true;
    }

    private function basicAuth(): ?string
    {
        if ($this->clientId === '') {
            return null;
        }
        $raw = "{$this->clientId}:{$this->clientSecret}";
        return 'Basic ' . base64_encode($raw);
    }
}
