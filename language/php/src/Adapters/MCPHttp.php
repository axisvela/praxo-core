<?php

declare(strict_types=1);

namespace Praxo\Core\Adapters;

use Praxo\Core\PraxoException;

class HttpMCPTransport implements MCPTransport
{
    private string $sessionId = '';
    private string $protocolVersion;
    private int $nextId = 0;
    private bool $closed = false;

    /**
     * @param array<string, string> $headers
     */
    public function __construct(
        private readonly string $endpoint,
        private readonly array $headers = [],
        string $protocolVersion = '2025-03-26',
    ) {
        $parts = parse_url($endpoint);
        $scheme = is_array($parts) ? ($parts['scheme'] ?? '') : '';
        $host = is_array($parts) ? ($parts['host'] ?? '') : '';
        if ($scheme !== 'http' && $scheme !== 'https') {
            throw new PraxoException('MCP_TRANSPORT', 'mcp: invalid HTTP endpoint');
        }
        if ($scheme === 'http' && !self::isLoopback($host)) {
            throw new PraxoException('MCP_TRANSPORT', 'mcp: HTTP endpoint must use HTTPS');
        }
        $this->protocolVersion = $protocolVersion;
    }

    public function request(string $method, array $params, float $timeout): array
    {
        if ($this->closed) {
            throw new PraxoException('MCP_CLOSED', 'mcp: client is closed');
        }
        $this->nextId++;
        $message = [
            'jsonrpc' => '2.0',
            'id' => $this->nextId,
            'method' => $method,
            'params' => $params,
        ];
        $response = $this->post($message, $timeout);
        if (isset($response['error'])) {
            $detail = is_array($response['error'])
                ? (string) ($response['error']['message'] ?? 'JSON-RPC error')
                : 'JSON-RPC error';
            throw new PraxoException('MCP_RPC', "mcp: {$method} failed: {$detail}");
        }
        $result = $response['result'] ?? [];
        if (!is_array($result)) {
            throw new PraxoException('MCP_PROTOCOL', "mcp: {$method} result must be an object");
        }
        return $result;
    }

    public function notify(string $method, array $params): void
    {
        if ($this->closed) {
            return;
        }
        $this->post([
            'jsonrpc' => '2.0',
            'method' => $method,
            'params' => $params,
        ], 5.0);
    }

    public function close(): void
    {
        if ($this->closed) {
            return;
        }
        $this->closed = true;
        if ($this->sessionId !== '') {
            try {
                $this->send('DELETE', null, $this->headersFor(), 5.0);
            } catch (\Throwable) {
                // Session termination is best-effort.
            }
        }
    }

    /** @param array<string, mixed> $message */
    private function post(array $message, float $timeout): array
    {
        $body = json_encode(
            $message,
            JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE
        );
        [$status, $headers, $raw] = $this->send(
            'POST',
            $body === false ? '{}' : $body,
            $this->headersFor(),
            $timeout
        );
        $session = self::header($headers, 'mcp-session-id');
        if ($session !== '') {
            $this->sessionId = $session;
        }
        if ($status === 202 || $status === 204 || trim($raw) === '') {
            return [];
        }
        if ($status < 200 || $status >= 300) {
            throw new PraxoException(
                'MCP_TRANSPORT',
                "mcp: HTTP {$status}: " . substr($raw, 0, 512)
            );
        }
        $contentType = self::header($headers, 'content-type');
        $decoded = str_contains(strtolower($contentType), 'text/event-stream')
            ? $this->parseSse($raw, $message['id'] ?? null)
            : $this->parseJson($raw, $message['id'] ?? null);
        if (
            isset($decoded['result'])
            && is_array($decoded['result'])
            && !empty($decoded['result']['protocolVersion'])
        ) {
            $this->protocolVersion = (string) $decoded['result']['protocolVersion'];
        }
        return $decoded;
    }

    /** @return array<string, string> */
    private function headersFor(): array
    {
        $headers = [
            'Content-Type' => 'application/json',
            'Accept' => 'application/json, text/event-stream',
            'MCP-Protocol-Version' => $this->protocolVersion,
        ];
        if ($this->sessionId !== '') {
            $headers['MCP-Session-Id'] = $this->sessionId;
        }
        return array_merge($headers, $this->headers);
    }

    /**
     * @param array<string, string> $headers
     * @return array{0: int, 1: array<string, string>, 2: string}
     */
    protected function send(
        string $method,
        ?string $body,
        array $headers,
        float $timeout,
    ): array {
        $lines = [];
        foreach ($headers as $key => $value) {
            $lines[] = "{$key}: {$value}";
        }
        $context = stream_context_create([
            'http' => [
                'method' => $method,
                'header' => implode("\r\n", $lines),
                'content' => $body ?? '',
                'timeout' => $timeout,
                'ignore_errors' => true,
            ],
        ]);
        $raw = @file_get_contents($this->endpoint, false, $context);
        $responseLines = function_exists('http_get_last_response_headers')
            ? (http_get_last_response_headers() ?? [])
            : ($http_response_header ?? []);
        $statusLine = $responseLines[0] ?? '';
        preg_match('/\s(\d{3})\s/', $statusLine, $match);
        $status = (int) ($match[1] ?? 0);
        $responseHeaders = [];
        foreach ($responseLines as $line) {
            $separator = strpos($line, ':');
            if ($separator === false) {
                continue;
            }
            $responseHeaders[strtolower(trim(substr($line, 0, $separator)))] =
                trim(substr($line, $separator + 1));
        }
        if ($raw === false) {
            throw new PraxoException('MCP_TRANSPORT', 'mcp: HTTP transport failed');
        }
        return [$status, $responseHeaders, $raw];
    }

    /** @param array<string, string> $headers */
    private static function header(array $headers, string $name): string
    {
        return $headers[strtolower($name)] ?? '';
    }

    private function parseJson(string $raw, int|string|null $id): array
    {
        $decoded = json_decode($raw, true);
        if (!is_array($decoded)) {
            throw new PraxoException('MCP_PROTOCOL', 'mcp: server sent invalid JSON');
        }
        if (array_is_list($decoded)) {
            return $this->selectMessage($decoded, $id);
        }
        return $decoded;
    }

    private function parseSse(string $raw, int|string|null $id): array
    {
        $messages = [];
        $data = [];
        foreach (preg_split('/\r\n|\n|\r/', $raw) as $line) {
            if ($line === '') {
                if ($data !== []) {
                    $messages[] = $this->decodeMessage(implode("\n", $data));
                    $data = [];
                }
                continue;
            }
            if (str_starts_with($line, ':')) {
                continue;
            }
            if (str_starts_with($line, 'data:')) {
                $data[] = ltrim(substr($line, 5));
            }
        }
        if ($data !== []) {
            $messages[] = $this->decodeMessage(implode("\n", $data));
        }
        return $this->selectMessage($messages, $id);
    }

    private function decodeMessage(string $text): array
    {
        $decoded = json_decode($text, true);
        if (!is_array($decoded)) {
            throw new PraxoException('MCP_PROTOCOL', 'mcp: server sent invalid SSE JSON');
        }
        return $decoded;
    }

    /** @param list<array<string, mixed>> $messages */
    private function selectMessage(array $messages, int|string|null $id): array
    {
        if ($id !== null) {
            foreach ($messages as $message) {
                if (($message['id'] ?? null) === $id) {
                    return $message;
                }
            }
        }
        if ($messages === []) {
            throw new PraxoException('MCP_PROTOCOL', 'mcp: response contained no message');
        }
        return $messages[0];
    }

    private static function isLoopback(string $host): bool
    {
        return in_array(strtolower($host), ['localhost', '127.0.0.1', '::1', '[::1]'], true)
            || str_starts_with($host, '127.');
    }
}
