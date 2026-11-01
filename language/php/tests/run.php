<?php

declare(strict_types=1);

namespace Praxo\Tests;

require __DIR__ . '/../src/autoload.php';

use Praxo\Core\Action;
use Praxo\Core\Agent;
use Praxo\Core\AgentOptions;
use Praxo\Core\BaseMiddleware;
use Praxo\Core\CallLimitMiddleware;
use Praxo\Core\Decision;
use Praxo\Core\Event;
use Praxo\Core\EventSink;
use Praxo\Core\PolicyHook;
use Praxo\Core\CheckpointAllowlist;
use Praxo\Core\ContextBudget;
use Praxo\Core\ContextEstimator;
use Praxo\Core\FuncTool;
use Praxo\Core\InMemoryMemoryStore;
use Praxo\Core\Json;
use Praxo\Core\JsonSchema;
use Praxo\Core\MemoryRecord;
use Praxo\Core\Message;
use Praxo\Core\MiddlewareToolCall;
use Praxo\Core\Model;
use Praxo\Core\ModelCall;
use Praxo\Core\PathChecker;
use Praxo\Core\PathGrant;
use Praxo\Core\PiiRedactor;
use Praxo\Core\Plugin;
use Praxo\Core\PraxoException;
use Praxo\Core\Request;
use Praxo\Core\Response;
use Praxo\Core\Roles;
use Praxo\Core\RunResult;
use Praxo\Core\RunState;
use Praxo\Core\Session;
use Praxo\Core\StaticModel;
use Praxo\Core\StreamingModel;
use Praxo\Core\ToolCall;
use Praxo\Core\ToolCallParser;
use Praxo\Core\ToolRegistry;

final class ToolModel implements Model
{
    private int $step = 0;

    public function generate(Request $request): Response
    {
        if ($this->step++ === 0) {
            return new Response(Message::assistant('', [
                new ToolCall('c1', 'echo', ['text' => 'hi']),
            ]));
        }
        return new Response(Message::assistant('done'));
    }
}

final class RecordingPolicy implements PolicyHook
{
    /** @var list<Action> */
    public array $actions = [];
    public mixed $handler = null;

    public function authorize(Action $action): Decision
    {
        $this->actions[] = $action;
        return $this->handler === null
            ? Decision::allow('ok')
            : ($this->handler)($action);
    }
}

final class MutatingMiddleware extends BaseMiddleware
{
    public mixed $mutate = null;
    public int $beforeToolCalls = 0;

    public function beforeTool(MiddlewareToolCall $call): void
    {
        $this->beforeToolCalls++;
        if ($this->mutate !== null) {
            ($this->mutate)($call);
        }
    }
}

final class LifecycleMiddleware extends BaseMiddleware
{
    public mixed $before = null;
    public mixed $after = null;

    public function beforeRun(RunState $state): void
    {
        if ($this->before !== null) {
            ($this->before)($state);
        }
    }

    public function afterRun(?RunResult $result, ?PraxoException $error): void
    {
        if ($this->after !== null) {
            ($this->after)($result, $error);
        }
    }
}

final class RecordingSink implements EventSink
{
    /** @var list<Event> */
    public array $events = [];

    public function emit(Event $event): void
    {
        $this->events[] = $event;
    }
}

final class FailingModel implements Model
{
    public function generate(Request $request): Response
    {
        throw new PraxoException('RUN_FAILED', 'run failed');
    }
}

final class CancellingModel implements Model
{
    public function __construct(private mixed $cancel)
    {
    }

    public function generate(Request $request): Response
    {
        ($this->cancel)();
        return new Response(Message::assistant('done'));
    }
}

final class CancellationToolModel implements Model
{
    private int $step = 0;

    public function generate(Request $request): Response
    {
        if ($this->step++ === 0) {
            return new Response(Message::assistant('', [
                new ToolCall('c1', 'cancel', []),
                new ToolCall('c2', 'effect', []),
            ]));
        }
        return new Response(Message::assistant('done'));
    }
}

final class StreamFailureModel implements Model, StreamingModel
{
    public function generate(Request $request): Response
    {
        return new Response(Message::assistant('done'));
    }

    public function generateStream(Request $request, callable $onDelta): Response
    {
        $onDelta('x');
        return new Response(Message::assistant('done'));
    }
}
$passed = 0;

function check(bool $condition, string $message): void
{
    global $passed;
    if (!$condition) {
        throw new \RuntimeException($message);
    }
    $passed++;
}

$call = ToolCallParser::parse('{"name":"echo","input":{"text":"hi"}}');
check($call !== null && $call->name === 'echo' && $call->input['text'] === 'hi', 'toolcall json');
check(
    ToolCallParser::stripMarkup('hello<tool_call name="echo">{"text":"hi"}</tool_call>world') === 'helloworld',
    'toolcall strip',
);

$schema = Json::decode('{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}');
$errors = JsonSchema::validate($schema, []);
check(count($errors) === 1 && $errors[0]->path === '$.name', 'schema required');
check(JsonSchema::validate($schema, ['name' => 'ok']) === [], 'schema valid');
$unicodeSchema = Json::decode('{"type":"string","minLength":2,"maxLength":2}');
check(JsonSchema::validate($unicodeSchema, '你好') === [], 'schema unicode two');
check(count(JsonSchema::validate($unicodeSchema, '你')) === 1, 'schema unicode one');
$integerSchema = Json::decode('{"type":"integer"}');
check(JsonSchema::validate($integerSchema, 2) === [], 'schema integer');
check(count(JsonSchema::validate($integerSchema, 2.5)) === 1, 'schema integer fraction');

$messages = [
    Message::text(Roles::SYSTEM, 'sys'),
    Message::text(Roles::USER, 'message 0'),
    Message::text(Roles::USER, 'message 1'),
];
check(ContextEstimator::estimateTokens($messages) === 16, 'context estimate');

$store = new InMemoryMemoryStore();
$store->put('s1', new MemoryRecord('m1', 'event', 'Alpha', null, '2026-01-01T00:00:00Z'));
$store->put('s1', new MemoryRecord('m2', 'event', 'beta', null, '2026-01-02T00:00:00Z'));
$found = $store->search('s1', 'alpha', 10);
check(count($found) === 1 && $found[0]->id === 'm1', 'memory search');

$allow = new CheckpointAllowlist();
$allow->register('spec.payload');
$encoded = $allow->marshal('spec.payload', ['value' => 'x']);
check($allow->unmarshal($encoded)['value'] === 'x', 'checkpoint roundtrip');
try {
    $allow->marshal('spec.missing', []);
    check(false, 'checkpoint unregistered');
} catch (PraxoException $error) {
    check($error->praxoCode === 'CHECKPOINT_TYPE_NOT_ALLOWED', 'checkpoint code');
}

check(PiiRedactor::defaults()->redact('email a@b.com') === 'email [REDACTED:email]', 'pii redaction');
$piiHistory = [
    'messages' => [[
        'content' => 'email a@b.com',
        'toolCalls' => [[
            'arguments' => ['email' => 'a@b.com', 'nested' => ['ssn' => '123-45-6789']],
        ]],
    ]],
];
$redactedHistory = PiiRedactor::defaults()->redactValue($piiHistory);
check(
    $redactedHistory['messages'][0]['toolCalls'][0]['arguments']['email'] === '[REDACTED:email]',
    'pii tool-call email',
);
check(
    $redactedHistory['messages'][0]['toolCalls'][0]['arguments']['nested']['ssn'] === '[REDACTED:ssn]',
    'pii nested tool-call ssn',
);
check($piiHistory['messages'][0]['toolCalls'][0]['arguments']['email'] === 'a@b.com', 'pii caller arguments unchanged');
$manifest = Plugin::parseManifest('{"schemaVersion":1,"id":"com.example.echo","version":"1.0.0","kind":"tool.provider.v1","entrypoint":{"type":"process","command":"echo"},"protocol":"jsonrpc-2","capabilities":[],"permissions":{},"limits":{},"health":{},"isolation":"process"}');
check($manifest->id === 'com.example.echo', 'plugin manifest');

$root = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'praxo-test-' . bin2hex(random_bytes(6));
mkdir($root . DIRECTORY_SEPARATOR . 'root', 0777, true);
mkdir($root . DIRECTORY_SEPARATOR . 'outside', 0777, true);
try {
    $checker = new PathChecker([new PathGrant($root . DIRECTORY_SEPARATOR . 'root', 'readwrite')]);
    check($checker->check($root . DIRECTORY_SEPARATOR . 'root' . DIRECTORY_SEPARATOR . 'a.txt', 'read')->allowed, 'policy inside');
    check(!$checker->check($root . DIRECTORY_SEPARATOR . 'outside' . DIRECTORY_SEPARATOR . 'x.txt', 'read')->allowed, 'policy outside');
} finally {
    @rmdir($root . DIRECTORY_SEPARATOR . 'root');
    @rmdir($root . DIRECTORY_SEPARATOR . 'outside');
    @rmdir($root);
}

$modelLimit = new CallLimitMiddleware(1, 0);
$modelCall = new ModelCall('r1');
$modelLimit->beforeModel($modelCall);
try {
    $modelLimit->beforeModel($modelCall);
    check(false, 'model call limit');
} catch (PraxoException $error) {
    check($error->praxoCode === 'AGENT_MODEL_CALL_LIMIT', 'model call limit code');
}
$toolLimit = new CallLimitMiddleware(0, 1);
$toolCall = new MiddlewareToolCall('r2');
$toolLimit->beforeTool($toolCall);
try {
    $toolLimit->beforeTool($toolCall);
    check(false, 'tool call limit');
} catch (PraxoException $error) {
    check($error->praxoCode === 'AGENT_TOOL_CALL_LIMIT', 'tool call limit code');
}

$isolatedLimit = new CallLimitMiddleware(1, 0);
$firstCall = new ModelCall('r1');
$secondCall = new ModelCall('r2');
$isolatedLimit->beforeModel($firstCall);
$isolatedLimit->beforeModel($secondCall);
try {
    $isolatedLimit->beforeModel($firstCall);
    check(false, 'call limit run isolation');
} catch (PraxoException $error) {
    check($error->praxoCode === 'AGENT_MODEL_CALL_LIMIT', 'call limit run isolation code');
}

$capacityOptions = new AgentOptions(new StaticModel('done'));
$capacityOptions->systemPrompt = str_repeat('x', 1000);
$capacityOptions->context = new ContextBudget(10, 0);
try {
    (new Agent($capacityOptions))->run(new Session('s1'), 'go');
    check(false, 'capacity fail closed');
} catch (PraxoException $error) {
    check($error->praxoCode === 'AGENT_CONTEXT_BUDGET', 'capacity fail closed code');
}

$agent = new Agent(new AgentOptions(new StaticModel('hello')));
$result = $agent->run(new Session('s1'), 'hello');
check($result->output === 'hello' && $result->steps === 1, 'agent direct');

$calls = 0;
$registry = new ToolRegistry();
$registry->register(new FuncTool('echo', 'Echo', static function (array $arguments) use (&$calls): array {
    $calls++;
    return $arguments;
}));
$agentOptions = new AgentOptions(new ToolModel());
$agentOptions->tools = $registry;
$agentOptions->maxSteps = 8;
$agent = new Agent($agentOptions);
$result = $agent->run(new Session('s1'), 'use the tool');
check($result->output === 'done' && $result->steps === 2 && $calls === 1, 'agent tool loop');

$invoked = [];
$registry = new ToolRegistry();
$registry->register(new FuncTool('echo', 'Echo', static function (array $arguments) use (&$invoked): array {
    $invoked[] = $arguments;
    return $arguments;
}));
$policy = new RecordingPolicy();
$middleware = new MutatingMiddleware();
$middleware->mutate = static function (MiddlewareToolCall $call): void {
    $call->call->arguments = ['text' => 'mutated'];
};
$options = new AgentOptions(new ToolModel());
$options->tools = $registry;
$options->policy = $policy;
$options->middleware[] = $middleware;
$result = (new Agent($options))->run(new Session('s1'), 'go');
$toolActions = array_values(array_filter(
    $policy->actions,
    static fn(Action $action): bool => $action->kind === 'tool.invoke',
));
check($result->output === 'done' && count($invoked) === 1, 'final arguments effect');
check(count($toolActions) === 2, 'final arguments reauthorized');
check($toolActions[0]->arguments['text'] === 'hi', 'original arguments authorized');
check($toolActions[1]->arguments['text'] === 'mutated', 'final arguments authorized');
check($invoked[0]['text'] === 'mutated', 'final arguments invoked');

$echoCalls = 0;
$otherCalls = 0;
$registry = new ToolRegistry();
$registry->register(new FuncTool('echo', 'Echo', static function (array $arguments) use (&$echoCalls): array {
    $echoCalls++;
    return $arguments;
}));
$registry->register(new FuncTool('other', 'Other', static function (array $arguments) use (&$otherCalls): array {
    $otherCalls++;
    return $arguments;
}));
$policy = new RecordingPolicy();
$middleware = new MutatingMiddleware();
$middleware->mutate = static function (MiddlewareToolCall $call): void {
    $call->call->name = 'other';
};
$options = new AgentOptions(new ToolModel());
$options->tools = $registry;
$options->policy = $policy;
$options->middleware[] = $middleware;
(new Agent($options))->run(new Session('s1'), 'go');
$toolActions = array_values(array_filter(
    $policy->actions,
    static fn(Action $action): bool => $action->kind === 'tool.invoke',
));
check($echoCalls === 0 && $otherCalls === 1, 'final name uses final tool');
check(
    count($toolActions) === 2
    && $toolActions[0]->toolName === 'echo'
    && $toolActions[1]->toolName === 'other',
    'final name authorized',
);

$deniedCalls = 0;
$deniedRegistry = new ToolRegistry();
$deniedRegistry->register(new FuncTool('echo', 'Echo', static fn(array $arguments): array => $arguments));
$deniedRegistry->register(new FuncTool('other', 'Other', static function (array $arguments) use (&$deniedCalls): array {
    $deniedCalls++;
    return $arguments;
}));
$deniedMiddleware = new MutatingMiddleware();
$deniedMiddleware->mutate = static function (MiddlewareToolCall $call): void {
    $call->call->name = 'other';
};
$deniedOptions = new AgentOptions(new ToolModel());
$deniedOptions->tools = $deniedRegistry;
$deniedOptions->allowedTools = ['echo'];
$deniedOptions->middleware[] = $deniedMiddleware;
try {
    (new Agent($deniedOptions))->run(new Session('s1'), 'go');
    check(false, 'final name allowlist');
} catch (PraxoException $error) {
    check($error->praxoCode === 'AGENT_TOOL_NOT_ALLOWED' && $deniedCalls === 0, 'final name allowlist code');
}

$policy = new RecordingPolicy();
$middleware = new MutatingMiddleware();
$options = new AgentOptions(new ToolModel());
$options->tools = $registry;
$options->policy = $policy;
$options->middleware[] = $middleware;
(new Agent($options))->run(new Session('s1'), 'go');
$toolActions = array_values(array_filter(
    $policy->actions,
    static fn(Action $action): bool => $action->kind === 'tool.invoke',
));
check(count($toolActions) === 1, 'unchanged call authorized once');

$toolCalls = 0;
$registry = new ToolRegistry();
$registry->register(new FuncTool('echo', 'Echo', static function (array $arguments) use (&$toolCalls): array {
    $toolCalls++;
    return $arguments;
}));
$policy = new RecordingPolicy();
$policy->handler = static fn(Action $action): Decision => $action->kind === 'tool.invoke'
    ? Decision::deny('blocked')
    : Decision::allow('ok');
$middleware = new MutatingMiddleware();
$options = new AgentOptions(new ToolModel());
$options->tools = $registry;
$options->policy = $policy;
$options->middleware[] = $middleware;
try {
    (new Agent($options))->run(new Session('s1'), 'go');
    check(false, 'initial denial');
} catch (PraxoException $error) {
    check(
        $error->praxoCode === 'AGENT_POLICY_DENIED'
        && $middleware->beforeToolCalls === 0
        && $toolCalls === 0,
        'initial denial prevents middleware and effect',
    );
}

$calls = [];
$sink = new RecordingSink();
$first = new LifecycleMiddleware();
$first->before = static function (RunState $state) use (&$calls): void {
    $calls[] = 'first.before';
};
$first->after = static function (?RunResult $result, ?PraxoException $error) use (&$calls): void {
    $calls[] = 'first.after';
};
$second = new LifecycleMiddleware();
$second->before = static function (RunState $state) use (&$calls): void {
    $calls[] = 'second.before';
    throw new PraxoException('STARTUP_FAILED', 'startup failed');
};
$second->after = static function (?RunResult $result, ?PraxoException $error) use (&$calls): void {
    $calls[] = 'second.after';
};
$third = new LifecycleMiddleware();
$third->before = static function (RunState $state) use (&$calls): void {
    $calls[] = 'third.before';
};
$third->after = static function (?RunResult $result, ?PraxoException $error) use (&$calls): void {
    $calls[] = 'third.after';
};
$options = new AgentOptions(new StaticModel('done'));
$options->events = $sink;
$options->middleware = [$first, $second, $third];
try {
    (new Agent($options))->run(new Session('s1'), 'go');
    check(false, 'startup failure');
} catch (PraxoException $error) {
    check($error->praxoCode === 'STARTUP_FAILED' && $error->getMessage() === 'startup failed', 'startup failure preserved');
}
check($calls === ['first.before', 'second.before', 'first.after', 'second.after'], 'startup cleanup order');
check($sink->events === [], 'startup emits no run events');

$calls = [];
$first = new LifecycleMiddleware();
$first->after = static function (?RunResult $result, ?PraxoException $error) use (&$calls): void {
    $calls[] = 'first.after';
    throw new PraxoException('CLEANUP_FAILED', 'cleanup failed');
};
$second = new LifecycleMiddleware();
$second->after = static function (?RunResult $result, ?PraxoException $error) use (&$calls): void {
    $calls[] = 'second.after';
};
$options = new AgentOptions(new FailingModel());
$options->middleware = [$first, $second];
try {
    (new Agent($options))->run(new Session('s1'), 'go');
    check(false, 'run failure');
} catch (PraxoException $error) {
    check($error->praxoCode === 'RUN_FAILED' && $error->getMessage() === 'run failed', 'run error preserved');
}
check($calls === ['first.after', 'second.after'], 'after-run continues after failure');

$calls = [];
$sink = new RecordingSink();
$first = new LifecycleMiddleware();
$first->after = static function (?RunResult $result, ?PraxoException $error) use (&$calls): void {
    $calls[] = 'first.after';
    throw new PraxoException('CLEANUP_FAILED', 'cleanup failed');
};
$second = new LifecycleMiddleware();
$second->after = static function (?RunResult $result, ?PraxoException $error) use (&$calls): void {
    $calls[] = 'second.after';
};
$options = new AgentOptions(new StaticModel('done'));
$options->events = $sink;
$options->middleware = [$first, $second];
try {
    (new Agent($options))->run(new Session('s1'), 'go');
    check(false, 'cleanup failure');
} catch (PraxoException $error) {
    check($error->praxoCode === 'CLEANUP_FAILED' && $error->getMessage() === 'cleanup failed', 'cleanup error fails closed');
}
check($calls === ['first.after', 'second.after'], 'cleanup continues after failure');
check(
    array_map(static fn(Event $event): string => $event->type, $sink->events) === ['run.started', 'run.failed'],
    'cleanup failure emits failed',
);

$cancelled = false;
$cancellation = static function () use (&$cancelled): bool {
    return $cancelled;
};
$calls = [];
$sink = new RecordingSink();
$lifecycle = new LifecycleMiddleware();
$lifecycle->after = static function (?RunResult $result, ?PraxoException $error) use (&$calls): void {
    $calls[] = 'after';
};
$options = new AgentOptions(new CancellingModel(static function () use (&$cancelled): void {
    $cancelled = true;
}));
$options->cancellation = $cancellation;
$options->events = $sink;
$options->middleware[] = $lifecycle;
try {
    (new Agent($options))->run(new Session('s1'), 'go');
    check(false, 'model cancellation');
} catch (PraxoException $error) {
    check($error->praxoCode === 'AGENT_CANCELLED', 'model cancellation code');
}
check($calls === ['after'], 'model cancellation runs after-run');
check(
    array_map(static fn(Event $event): string => $event->type, $sink->events) === ['run.started', 'run.failed'],
    'model cancellation emits failed',
);

$cancelled = false;
$effectCalls = 0;
$calls = [];
$registry = new ToolRegistry();
$registry->register(new FuncTool('cancel', 'Cancel', static function () use (&$cancelled): array {
    $cancelled = true;
    return [];
}));
$registry->register(new FuncTool('effect', 'Effect', static function () use (&$effectCalls): array {
    $effectCalls++;
    return [];
}));
$lifecycle = new LifecycleMiddleware();
$lifecycle->after = static function (?RunResult $result, ?PraxoException $error) use (&$calls): void {
    $calls[] = 'after';
};
$options = new AgentOptions(new CancellationToolModel());
$options->tools = $registry;
$options->cancellation = $cancellation;
$options->middleware[] = $lifecycle;
try {
    (new Agent($options))->run(new Session('s1'), 'go');
    check(false, 'tool cancellation');
} catch (PraxoException $error) {
    check($error->praxoCode === 'AGENT_CANCELLED', 'tool cancellation code');
}
check($effectCalls === 0, 'tool cancellation stops later effects');
check($calls === ['after'], 'tool cancellation runs after-run');

$calls = [];
$sink = new RecordingSink();
$lifecycle = new LifecycleMiddleware();
$lifecycle->after = static function (?RunResult $result, ?PraxoException $error) use (&$calls): void {
    $calls[] = 'after';
};
$options = new AgentOptions(new StreamFailureModel());
$options->events = $sink;
$options->middleware[] = $lifecycle;
try {
    (new Agent($options))->runStream(new Session('s1'), 'go', static function (string $delta): void {
        throw new PraxoException('CALLBACK', 'callback failed');
    });
    check(false, 'stream callback failure');
} catch (PraxoException $error) {
    check($error->praxoCode === 'CALLBACK', 'stream callback code');
}
check($calls === ['after'], 'stream failure runs after-run');
check(
    array_map(static fn(Event $event): string => $event->type, $sink->events) === ['run.started', 'run.failed'],
    'stream failure emits failed',
);

try {
    \Praxo\Core\parseSseStream("data: {\"choices\":[{\"delta\":{\"content\":\"hi\"}}]}\n\n", static function (string $delta): void {
    });
    check(false, 'sse truncation');
} catch (PraxoException $error) {
    check($error->praxoCode === 'MODEL_STREAM', 'sse truncation code');
}
try {
    \Praxo\Core\parseSseStream(
        "data: {\"choices\":[{\"delta\":{\"content\":\"hi\"}}]}\n\ndata: {\"choices\"",
        static function (string $delta): void {
        },
    );
    check(false, 'sse half packet');
} catch (PraxoException $error) {
    check($error->praxoCode === 'MODEL_STREAM', 'sse half packet code');
}
$response = \Praxo\Core\parseSseStream(
    "data: {\"choices\":[{\"delta\":{\"content\":\"hi\"}}]}\n\ndata: [DONE]\n\n",
    static function (string $delta): void {
    },
);
check($response->message->content === 'hi', 'sse completion');

echo "PHP core tests passed ({$passed})\n";

