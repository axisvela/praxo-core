<?php

declare(strict_types=1);

$autoload = __DIR__ . '/vendor/autoload.php';
if (is_file($autoload)) {
    require $autoload;
} else {
    require __DIR__ . '/../../src/autoload.php';
}

use Praxo\Core\Adapters\MCPClient;
use Praxo\Core\Adapters\MCPTransport;
use Praxo\Core\PraxoException;

final class FakeTransport implements MCPTransport
{
    public function request(string $method, array $params, float $timeout): array
    {
        return match ($method) {
            'initialize' => [
                'protocolVersion' => '2024-11-05',
                'capabilities' => ['tools' => []],
                'serverInfo' => ['name' => 'example-mcp', 'version' => '1.0.0'],
            ],
            'tools/list' => ['tools' => [
                ['name' => 'echo', 'description' => 'Echo input', 'inputSchema' => ['type' => 'object']],
                ['name' => 'add', 'description' => 'Add two integers', 'inputSchema' => ['type' => 'object']],
            ]],
            'tools/call' => ['structuredContent' => ['sum' => 5], 'isError' => false],
            default => throw new PraxoException('MCP_RPC', "mcp: {$method} failed"),
        };
    }

    public function notify(string $method, array $params): void
    {
    }

    public function close(): void
    {
    }
}

$client = (new MCPClient(new FakeTransport()))->start();
$tools = $client->listTools();
$result = $client->callTool('add', ['a' => 2, 'b' => 3]);
$client->close();

if (array_column($tools, 'name') !== ['echo', 'add'] || $result !== ['sum' => 5]) {
    throw new RuntimeException('mcp example failed');
}

echo "PHP MCP example passed\n";
