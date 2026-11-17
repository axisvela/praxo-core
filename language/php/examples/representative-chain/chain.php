<?php

declare(strict_types=1);

require __DIR__ . '/../../src/autoload.php';

use Praxo\Core\Action;
use Praxo\Core\Adapters\HarmovelaSink;
use Praxo\Core\Adapters\MCPClient;
use Praxo\Core\Adapters\MCPTransport;
use Praxo\Core\Adapters\OtelSink;
use Praxo\Core\Agent;
use Praxo\Core\AgentOptions;
use Praxo\Core\BaseMiddleware;
use Praxo\Core\Decision;
use Praxo\Core\MiddlewareToolCall;
use Praxo\Core\Model;
use Praxo\Core\MultiSink;
use Praxo\Core\PolicyHook;
use Praxo\Core\PraxoException;
use Praxo\Core\Request;
use Praxo\Core\Response;
use Praxo\Core\Message;
use Praxo\Core\Roles;
use Praxo\Core\Session;
use Praxo\Core\Tool;
use Praxo\Core\ToolCall;
use Praxo\Core\ToolRegistry;

final class FakeMCPTransport implements MCPTransport
{
    public array $effects = [];

    public function request(string $method, array $params, float $timeout): array
    {
        return match ($method) {
            'initialize' => [
                'protocolVersion' => '2024-11-05',
                'capabilities' => ['tools' => []],
                'serverInfo' => ['name' => 'fixture-mcp', 'version' => '0.0.1'],
            ],
            'tools/list' => ['tools' => [[
                'name' => 'record',
                'description' => 'Record a target',
                'inputSchema' => [
                    'type' => 'object',
                    'properties' => ['target' => ['type' => 'string']],
                    'required' => ['target'],
                ],
            ]]],
            'tools/call' => $this->callTool($params),
            default => throw new PraxoException('MCP_RPC', "mcp: {$method} failed"),
        };
    }

    private function callTool(array $params): array
    {
        if (($params['name'] ?? '') !== 'record') {
            return ['isError' => true, 'content' => [['type' => 'text', 'text' => 'unknown tool']]];
        }
        $arguments = $params['arguments'] ?? [];
        $arguments = is_array($arguments) ? $arguments : (array) $arguments;
        $target = (string) ($arguments['target'] ?? '');
        $this->effects[$target] = ($this->effects[$target] ?? 0) + 1;
        return ['content' => [['type' => 'text', 'text' => "recorded:{$target}"]]];
    }

    public function notify(string $method, array $params): void
    {
    }

    public function close(): void
    {
    }
}

final class McpRecordTool implements Tool
{
    public array $parameters = [
        'type' => 'object',
        'properties' => ['target' => ['type' => 'string']],
        'required' => ['target'],
    ];

    public function __construct(private MCPClient $client)
    {
    }

    public function name(): string
    {
        return 'record';
    }

    public function description(): string
    {
        return 'Record a target through the MCP transport seam.';
    }

    public function invoke(array $arguments): mixed
    {
        return $this->client->callTool('record', $arguments);
    }
}

final class ScriptedModel implements Model
{
    public int $calls = 0;

    public function __construct(
        private array $steps,
        private string $final,
    ) {
    }

    public function generate(Request $request): Response
    {
        $this->calls++;
        if ($this->steps !== []) {
            $step = array_shift($this->steps);
            return new Response(Message::assistant('', $step));
        }
        return new Response(Message::assistant($this->final));
    }
}

final class FuncPolicy implements PolicyHook
{
    private \Closure $function;

    public function __construct(callable $function)
    {
        $this->function = \Closure::fromCallable($function);
    }

    public function authorize(Action $action): Decision
    {
        return ($this->function)($action);
    }
}

final class ComposedPolicy implements PolicyHook
{
    private array $hooks;

    public function __construct(PolicyHook ...$hooks)
    {
        $this->hooks = $hooks;
    }

    public function authorize(Action $action): Decision
    {
        foreach ($this->hooks as $hook) {
            $decision = $hook->authorize($action);
            if (!$decision->allowed) {
                return $decision;
            }
        }
        return Decision::allow('delegation policy chain allowed');
    }
}

final class ParentPolicy
{
    public static function authorize(Action $action): Decision
    {
        if ($action->kind === 'model.generate') {
            return Decision::allow('model');
        }
        if ($action->kind !== 'tool.invoke') {
            return Decision::deny('unsupported action');
        }
        if ($action->toolName === 'record') {
            if (($action->arguments['target'] ?? '') === 'blocked') {
                return Decision::deny('blocked target');
            }
            return Decision::allow('record');
        }
        if ($action->toolName === 'delegate') {
            return Decision::allow('delegate');
        }
        return Decision::deny('parent tool is not allowed');
    }
}

final class ChildPolicy
{
    public static function authorize(Action $action): Decision
    {
        if ($action->kind === 'model.generate') {
            return Decision::allow('model');
        }
        if ($action->kind === 'tool.invoke' && $action->toolName === 'record') {
            return Decision::allow('child record');
        }
        return Decision::deny('child may only record');
    }
}

final class DelegateTool implements Tool
{
    public array $parameters = [
        'type' => 'object',
        'properties' => ['task' => ['type' => 'string']],
        'required' => ['task'],
    ];

    public function __construct(
        private Tool $record,
        private Model $childModel,
        private MultiSink $events,
    ) {
    }

    public function name(): string
    {
        return 'delegate';
    }

    public function description(): string
    {
        return 'Run a governed child agent with the narrowed record scope.';
    }

    public function invoke(array $arguments): mixed
    {
        $registry = new ToolRegistry();
        $registry->register($this->record);
        $options = new AgentOptions($this->childModel);
        $options->tools = $registry;
        $options->maxSteps = 3;
        $options->allowedTools = ['record'];
        $options->policy = new ComposedPolicy(
            new FuncPolicy(ParentPolicy::authorize(...)),
            new FuncPolicy(ChildPolicy::authorize(...)),
        );
        $options->requirePolicy = true;
        $options->requireToolScope = true;
        $options->events = $this->events;
        $result = (new Agent($options))->run(new Session('chain-child'), 'record child');
        return ['output' => $result->output];
    }
}

final class EditTargetMiddleware extends BaseMiddleware
{
    public function beforeTool(MiddlewareToolCall $call): void
    {
        $call->call->arguments['target'] = 'blocked';
    }
}

final class EventLog
{
    public array $otel = [];
    public array $harmovela = [];

    public function sinks(): MultiSink
    {
        return new MultiSink([
            new OtelSink(transport: function (string $endpoint, string $body, array $headers): array {
                $payload = json_decode($body, true);
                foreach ($payload['resourceSpans'] ?? [] as $resource) {
                    foreach ($resource['scopeSpans'] ?? [] as $scope) {
                        foreach ($scope['spans'] ?? [] as $span) {
                            $this->otel[] = (string) ($span['name'] ?? '');
                        }
                    }
                }
                return ['status' => 200, 'body' => ''];
            }),
            new HarmovelaSink(
                baseUrl: 'http://harmovela.local',
                transport: function (string $path, string $body, array $headers): array {
                    $payload = json_decode($body, true);
                    $this->harmovela[] = (string) ($payload['type'] ?? '');
                    return ['status' => 202, 'body' => ''];
                },
            ),
        ]);
    }
}

function runChain(): array
{
    $transport = new FakeMCPTransport();
    $client = (new MCPClient($transport))->start();
    try {
        $record = new McpRecordTool($client);
        $events = new EventLog();
        $childModel = new ScriptedModel([
            [new ToolCall('child-record', 'record', ['target' => 'child'])],
        ], 'CHILD-DONE');
        $parentModel = new ScriptedModel([
            [new ToolCall('parent-record', 'record', ['target' => 'parent'])],
            [new ToolCall('parent-delegate', 'delegate', ['task' => 'child'])],
        ], 'DONE');
        $registry = new ToolRegistry();
        $registry->register($record);
        $registry->register(new DelegateTool($record, $childModel, $events->sinks()));
        $options = new AgentOptions($parentModel);
        $options->tools = $registry;
        $options->maxSteps = 6;
        $options->allowedTools = ['record', 'delegate'];
        $options->policy = new FuncPolicy(ParentPolicy::authorize(...));
        $options->requirePolicy = true;
        $options->requireToolScope = true;
        $options->events = $events->sinks();
        $result = (new Agent($options))->run(new Session('chain-parent'), 'run the representative chain');
        return [
            'output' => $result->output,
            'effects' => $transport->effects,
            'child_calls' => $childModel->calls,
            'otel' => $events->otel,
            'harmovela' => $events->harmovela,
        ];
    } finally {
        $client->close();
    }
}

function runDenial(): array
{
    $transport = new FakeMCPTransport();
    $client = (new MCPClient($transport))->start();
    try {
        $record = new McpRecordTool($client);
        $registry = new ToolRegistry();
        $registry->register($record);
        $model = new ScriptedModel([
            [new ToolCall('denied-record', 'record', ['target' => 'safe'])],
        ], 'UNEXPECTED');
        $options = new AgentOptions($model);
        $options->tools = $registry;
        $options->maxSteps = 2;
        $options->allowedTools = ['record'];
        $options->policy = new FuncPolicy(ParentPolicy::authorize(...));
        $options->middleware = [new EditTargetMiddleware()];
        $options->requirePolicy = true;
        $options->requireToolScope = true;
        try {
            (new Agent($options))->run(new Session('chain-denial'), 'call record');
        } catch (PraxoException $error) {
            return [
                'blocked' => $transport->effects['blocked'] ?? 0,
                'code' => $error->praxoCode,
            ];
        }
        throw new \RuntimeException('denial path unexpectedly succeeded');
    } finally {
        $client->close();
    }
}

function check(bool $condition, string $message): void
{
    if (!$condition) {
        throw new \RuntimeException($message);
    }
}

$result = runChain();
check($result['output'] === 'DONE', 'parent output was not DONE');
check(($result['effects']['parent'] ?? 0) === 1, 'parent effect count was not one');
check(($result['effects']['child'] ?? 0) === 1, 'child effect count was not one');
check($result['child_calls'] >= 2, 'child model calls were fewer than two');
foreach (['praxo.run.started', 'praxo.tool.call', 'praxo.run.completed'] as $span) {
    check(in_array($span, $result['otel'], true), "missing otel span {$span}");
}
foreach (['run.started', 'tool.call', 'run.completed'] as $kind) {
    check(in_array($kind, $result['harmovela'], true), "missing harmovela event {$kind}");
}
$denial = runDenial();
check($denial['blocked'] === 0, 'denied target produced an effect');
check($denial['code'] === 'AGENT_POLICY_DENIED', 'denial code was not AGENT_POLICY_DENIED');

echo "output: {$result['output']}\n";
echo 'effects: parent=' . ($result['effects']['parent'] ?? 0)
    . ' child=' . ($result['effects']['child'] ?? 0) . "\n";
echo "child calls: {$result['child_calls']}\n";
echo 'otel spans: ' . count($result['otel']) . "\n";
echo 'harmovela events: ' . count($result['harmovela']) . "\n";
echo "denied effects: {$denial['blocked']}\n";
