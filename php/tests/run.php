<?php

declare(strict_types=1);

namespace Praxo\Tests;

require __DIR__ . '/../src/autoload.php';

use Praxo\Core\Agent;
use Praxo\Core\AgentOptions;
use Praxo\Core\CheckpointAllowlist;
use Praxo\Core\ContextBudget;
use Praxo\Core\ContextEstimator;
use Praxo\Core\FuncTool;
use Praxo\Core\InMemoryMemoryStore;
use Praxo\Core\Json;
use Praxo\Core\JsonSchema;
use Praxo\Core\MemoryRecord;
use Praxo\Core\Message;
use Praxo\Core\Model;
use Praxo\Core\PathChecker;
use Praxo\Core\PathGrant;
use Praxo\Core\PiiRedactor;
use Praxo\Core\Plugin;
use Praxo\Core\PraxoException;
use Praxo\Core\Request;
use Praxo\Core\Response;
use Praxo\Core\Roles;
use Praxo\Core\Session;
use Praxo\Core\StaticModel;
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

echo "PHP core tests passed ({$passed})\n";

