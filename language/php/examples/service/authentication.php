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
    public function getJson(string $url): array;

    /** @return array{0:int,1:string} */
    public function postForm(string $url, string $form, ?string $authorization): array;
}

final class StreamTransport implements IntrospectionTransport
{
    public function getJson(string $url): array
    {
        $context = stream_context_create([
            'http' => [
                'method' => 'GET',
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

final class OidcAuthenticator
{
    private const CACHE_SECONDS = 300;

    /** @var array<string, array<string, mixed>>|null */
    private ?array $keys = null;
    private int $keysAt = 0;
    /** @var array<string, mixed>|null */
    private ?array $metadata = null;
    private int $metadataAt = 0;

    public function __construct(
        private IntrospectionTransport $transport,
        private string $issuer,
        private string $audience,
        private string $jwksUrl = '',
        private string $discoveryUrl = '',
        private string $tenantClaim = 'tenant',
    ) {
        $this->issuer = rtrim($issuer, '/');
        if ($this->issuer === '') {
            throw new InvalidArgumentException('issuer is required');
        }
        if ($audience === '') {
            throw new InvalidArgumentException('audience is required');
        }
        $this->tenantClaim = $tenantClaim === '' ? 'tenant' : $tenantClaim;
    }

    public function authenticate(
        ?string $authorization,
        ?int $now = null,
    ): ?AuthenticatedPrincipal {
        if ($authorization === null
            || !str_starts_with($authorization, 'Bearer ')) {
            return null;
        }
        $parts = explode('.', trim(substr($authorization, 7)));
        if (count($parts) !== 3) {
            return null;
        }
        $now ??= time();
        try {
            $header = json_decode(self::base64UrlDecode($parts[0]), true);
            $claims = json_decode(self::base64UrlDecode($parts[1]), true);
            if (!is_array($header) || !is_array($claims)) {
                return null;
            }
            $algorithm = $header['alg'] ?? null;
            $kid = $header['kid'] ?? null;
            $digest = match ($algorithm) {
                'RS256' => OPENSSL_ALGO_SHA256,
                'RS384' => OPENSSL_ALGO_SHA384,
                'RS512' => OPENSSL_ALGO_SHA512,
                default => null,
            };
            if ($digest === null || !is_string($kid) || $kid === '') {
                return null;
            }
            $issuer = $claims['iss'] ?? null;
            if (!is_string($issuer) || rtrim($issuer, '/') !== $this->issuer) {
                return null;
            }
            if (!self::audienceMatches($claims['aud'] ?? null, $this->audience)) {
                return null;
            }
            $expires = $claims['exp'] ?? null;
            if (!is_int($expires) || $expires <= $now) {
                return null;
            }
            $notBefore = $claims['nbf'] ?? null;
            if ($notBefore !== null && (!is_int($notBefore) || $notBefore > $now)) {
                return null;
            }
            $subject = $claims['sub'] ?? null;
            $tenant = $claims[$this->tenantClaim] ?? null;
            if (!is_string($subject) || $subject === ''
                || !is_string($tenant) || $tenant === '') {
                return null;
            }
            $key = $this->findKey($kid, $algorithm, false);
            $key ??= $this->findKey($kid, $algorithm, true);
            if ($key === null) {
                return null;
            }
            $signature = self::base64UrlDecode($parts[2]);
            if (openssl_verify(
                $parts[0] . '.' . $parts[1],
                $signature,
                $this->publicKeyPem($key),
                $digest,
            ) !== 1) {
                return null;
            }
            return new AuthenticatedPrincipal($subject, $tenant, $expires);
        } catch (Throwable) {
            return null;
        }
    }

    /** @return array<string, mixed>|null */
    private function findKey(string $kid, string $algorithm, bool $refresh): ?array
    {
        $now = time();
        if ($this->keys === null || $refresh || $now - $this->keysAt > self::CACHE_SECONDS) {
            $url = $this->jwksUrl;
            if ($url === '') {
                $url = $this->metadata()['jwks_uri'] ?? '';
            }
            if (!is_string($url) || $url === '') {
                throw new AuthError('identity provider JWKS is not configured');
            }
            $body = $this->fetchJson($url);
            $items = $body['keys'] ?? null;
            if (!is_array($items)) {
                throw new AuthError('invalid JWKS');
            }
            $keys = [];
            foreach ($items as $item) {
                if (!is_array($item)) {
                    continue;
                }
                $itemKid = $item['kid'] ?? null;
                if (is_string($itemKid) && $itemKid !== '') {
                    $keys[$itemKid] = $item;
                }
            }
            $this->keys = $keys;
            $this->keysAt = $now;
        }
        $key = $this->keys[$kid] ?? null;
        if (!is_array($key) || ($key['kty'] ?? null) !== 'RSA'
            || (isset($key['use']) && $key['use'] !== 'sig')
            || (isset($key['alg']) && $key['alg'] !== $algorithm)) {
            return null;
        }
        return $key;
    }

    /** @return array<string, mixed> */
    private function metadata(): array
    {
        $now = time();
        if ($this->metadata !== null
            && $now - $this->metadataAt <= self::CACHE_SECONDS) {
            return $this->metadata;
        }
        $url = $this->discoveryUrl !== ''
            ? $this->discoveryUrl
            : $this->issuer . '/.well-known/openid-configuration';
        $body = $this->fetchJson($url);
        $issuer = $body['issuer'] ?? null;
        if (!is_string($issuer) || rtrim($issuer, '/') !== $this->issuer) {
            throw new AuthError('invalid provider issuer');
        }
        $this->metadata = $body;
        $this->metadataAt = $now;
        return $body;
    }

    /** @return array<string, mixed> */
    private function fetchJson(string $url): array
    {
        [$status, $body] = $this->transport->getJson($url);
        if ($status !== 200) {
            throw new AuthError('identity provider unavailable');
        }
        $decoded = json_decode($body, true);
        if (!is_array($decoded)) {
            throw new AuthError('invalid provider response');
        }
        return $decoded;
    }

    /** @param array<string, mixed> $key */
    private function publicKeyPem(array $key): string
    {
        $modulus = self::base64UrlDecode((string) ($key['n'] ?? ''));
        $exponent = self::base64UrlDecode((string) ($key['e'] ?? ''));
        $rsa = self::derSequence(self::derInteger($modulus) . self::derInteger($exponent));
        $algorithm = self::derSequence(
            hex2bin('06092a864886f70d010101') . "\x05\x00"
        );
        $spki = self::derSequence($algorithm . self::derBitString($rsa));
        return "-----BEGIN PUBLIC KEY-----\n"
            . chunk_split(base64_encode($spki), 64, "\n")
            . "-----END PUBLIC KEY-----\n";
    }

    private static function derInteger(string $value): string
    {
        $value = ltrim($value, "\x00");
        if ($value === '' || (ord($value[0]) & 0x80) !== 0) {
            $value = "\x00" . $value;
        }
        return "\x02" . self::derLength(strlen($value)) . $value;
    }

    private static function derBitString(string $value): string
    {
        return "\x03" . self::derLength(strlen($value) + 1) . "\x00" . $value;
    }

    private static function derSequence(string $value): string
    {
        return "\x30" . self::derLength(strlen($value)) . $value;
    }

    private static function derLength(int $length): string
    {
        if ($length < 128) {
            return chr($length);
        }
        $bytes = '';
        while ($length > 0) {
            $bytes = chr($length & 0xff) . $bytes;
            $length >>= 8;
        }
        return chr(0x80 | strlen($bytes)) . $bytes;
    }

    private static function audienceMatches(mixed $value, string $expected): bool
    {
        if (is_string($value)) {
            return $value === $expected;
        }
        return is_array($value) && in_array($expected, $value, true);
    }

    private static function base64UrlDecode(string $value): string
    {
        $text = strtr($value, '-_', '+/');
        $text .= str_repeat('=', (4 - strlen($text) % 4) % 4);
        $decoded = base64_decode($text, true);
        if ($decoded === false) {
            throw new AuthError('invalid token encoding');
        }
        return $decoded;
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
