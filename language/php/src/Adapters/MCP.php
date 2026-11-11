<?php

declare(strict_types=1);

namespace Praxo\Core\Adapters;

use Praxo\Core\PraxoException;

interface MCPTransport
{
    /** @param array<string, mixed> $params */
    public function request(string $method, array $params, float $timeout): array;

    /** @param array<string, mixed> $params */
    public function notify(string $method, array $params): void;

    public function close(): void;
}

final class MCPClient
{
    private bool $connected = false;
    private bool $closed = false;
    private string $protocolVersion = '';
    private array $serverInfo = [];

    public function __construct(
        private readonly MCPTransport $transport,
        private readonly string $clientVersion = '0.5.0',
        private readonly float $timeout = 5.0,
    ) {
    }

    public function protocolVersion(): string
    {
        return $this->protocolVersion;
    }

    public function serverInfo(): array
    {
        return $this->serverInfo;
    }

    public function start(): self
    {
        if ($this->connected) {
            return $this;
        }
        $result = $this->transport->request('initialize', [
            'protocolVersion' => '2024-11-05',
            'capabilities' => [],
            'clientInfo' => ['name' => 'praxo-core', 'version' => $this->clientVersion],
        ], $this->timeout);
        $version = (string) ($result['protocolVersion'] ?? '');
        if ($version === '') {
            throw new PraxoException('MCP_HANDSHAKE', 'mcp: initialize returned no protocol version');
        }
        $this->protocolVersion = $version;
        $this->serverInfo = is_array($result['serverInfo'] ?? null) ? $result['serverInfo'] : [];
        $this->transport->notify('notifications/initialized', []);
        $this->connected = true;
        return $this;
    }

    /** @return list<array<string, mixed>> */
    public function listTools(): array
    {
        $this->ensureConnected();
        $tools = [];
        $names = [];
        $cursor = null;
        $seen = [];
        do {
            $result = $this->transport->request(
                'tools/list',
                $cursor === null ? [] : ['cursor' => $cursor],
                $this->timeout,
            );
            foreach (($result['tools'] ?? []) as $tool) {
                $name = (string) ($tool['name'] ?? '');
                if (isset($names[$name])) {
                    throw new PraxoException('MCP_DUPLICATE_TOOL', "mcp: duplicate tool {$name}");
                }
                $names[$name] = true;
                $tools[] = $tool;
            }
            $cursor = isset($result['nextCursor']) && $result['nextCursor'] !== ''
                ? (string) $result['nextCursor'] : null;
            if ($cursor !== null) {
                if (isset($seen[$cursor])) {
                    throw new PraxoException('MCP_PAGINATION', 'mcp: repeated cursor');
                }
                $seen[$cursor] = true;
            }
        } while ($cursor !== null);
        return $tools;
    }

    public function callTool(string $name, array $arguments = []): mixed
    {
        $this->ensureConnected();
        $result = $this->transport->request(
            'tools/call',
            ['name' => $name, 'arguments' => (object) $arguments],
            $this->timeout,
        );
        if (($result['isError'] ?? false) === true) {
            throw new PraxoException('MCP_TOOL_ERROR', "mcp: tool {$name} failed");
        }
        if (array_key_exists('structuredContent', $result)) {
            return $result['structuredContent'];
        }
        $texts = [];
        foreach (($result['content'] ?? []) as $item) {
            if (($item['type'] ?? '') === 'text') {
                $texts[] = (string) ($item['text'] ?? '');
            }
        }
        if ($texts === []) {
            return null;
        }
        return count($texts) === 1 ? $texts[0] : $texts;
    }

    public function close(): void
    {
        if ($this->closed) {
            return;
        }
        $this->closed = true;
        $this->connected = false;
        $this->transport->close();
    }

    private function ensureConnected(): void
    {
        if ($this->closed) {
            throw new PraxoException('MCP_CLOSED', 'mcp: client is closed');
        }
        if (!$this->connected) {
            $this->start();
        }
    }
}

final class StdioMCPTransport implements MCPTransport
{
    /** @var resource|null */
    private $process = null;
    /** @var resource|null */
    private $stdin = null;
    /** @var resource|null */
    private $stdout = null;
    /** @var resource|null */
    private $stderr = null;
    private int $nextId = 0;

    /** @param list<string> $args @param array<string, string> $env */
    public function __construct(
        private readonly string $command,
        private readonly array $args = [],
        private readonly array $env = [],
    ) {
    }

    public function start(): void
    {
        if ($this->process !== null) {
            return;
        }
        $command = array_merge([$this->command], $this->args);
        $descriptors = [
            0 => ['pipe', 'r'],
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ];
        $process = proc_open($command, $descriptors, $pipes, null, $this->env ?: null);
        if (!is_resource($process)) {
            throw new PraxoException('MCP_TRANSPORT', 'mcp: failed to start server');
        }
        $this->process = $process;
        $this->stdin = $pipes[0];
        $this->stdout = $pipes[1];
        $this->stderr = $pipes[2];
    }

    public function request(string $method, array $params, float $timeout): array
    {
        $this->start();
        $this->nextId++;
        $id = $this->nextId;
        $this->write(['jsonrpc' => '2.0', 'id' => $id, 'method' => $method, 'params' => $params]);
        $deadline = microtime(true) + $timeout;
        while (true) {
            $remaining = $deadline - microtime(true);
            if ($remaining <= 0) {
                $this->notify('notifications/cancelled', ['requestId' => $id, 'reason' => 'timeout']);
                throw new PraxoException('MCP_TIMEOUT', "mcp: {$method} timed out");
            }
            $read = [$this->stdout];
            $write = null;
            $except = null;
            $seconds = (int) floor($remaining);
            $micros = (int) (($remaining - $seconds) * 1_000_000);
            $ready = @stream_select($read, $write, $except, $seconds, $micros);
            if ($ready === false || $ready === 0) {
                continue;
            }
            $line = fgets($this->stdout);
            if ($line === false) {
                throw new PraxoException('MCP_CLOSED', 'mcp: server closed the stream');
            }
            $message = json_decode($line, true);
            if (!is_array($message)) {
                throw new PraxoException('MCP_PROTOCOL', 'mcp: invalid JSON from server');
            }
            if (($message['id'] ?? null) !== $id) {
                continue;
            }
            if (isset($message['error'])) {
                $error = is_array($message['error']) ? $message['error'] : [];
                throw new PraxoException('MCP_RPC', 'mcp: ' . (string) ($error['message'] ?? 'rpc error'));
            }
            return is_array($message['result'] ?? null) ? $message['result'] : [];
        }
    }

    public function notify(string $method, array $params): void
    {
        if ($this->process === null) {
            return;
        }
        $this->write(['jsonrpc' => '2.0', 'method' => $method, 'params' => $params]);
    }

    public function close(): void
    {
        if ($this->process === null) {
            return;
        }
        foreach ([$this->stdin, $this->stdout, $this->stderr] as $pipe) {
            if (is_resource($pipe)) {
                fclose($pipe);
            }
        }
        proc_terminate($this->process);
        proc_close($this->process);
        $this->process = null;
        $this->stdin = $this->stdout = $this->stderr = null;
    }

    private function write(array $message): void
    {
        if (!is_resource($this->stdin)) {
            throw new PraxoException('MCP_CLOSED', 'mcp: client is closed');
        }
        $encoded = json_encode($message, JSON_UNESCAPED_SLASHES);
        if ($encoded === false || fwrite($this->stdin, $encoded . "\n") === false) {
            throw new PraxoException('MCP_TRANSPORT', 'mcp: write failed');
        }
        fflush($this->stdin);
    }
}
