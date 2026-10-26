<?php

declare(strict_types=1);

namespace Praxo\Conformance;

require __DIR__ . '/../src/autoload.php';
require __DIR__ . '/support.php';
require __DIR__ . '/middleware.php';
require __DIR__ . '/agent.php';
require __DIR__ . '/api.php';

use Praxo\Core\CheckpointAllowlist;
use Praxo\Core\ContextBudget;
use Praxo\Core\ContextEstimator;
use Praxo\Core\Event;
use Praxo\Core\FilterSink;
use Praxo\Core\InMemoryMemoryStore;
use Praxo\Core\Json;
use Praxo\Core\JsonSchema;
use Praxo\Core\MemoryRecord;
use Praxo\Core\Message;
use Praxo\Core\MultiSink;
use Praxo\Core\PathChecker;
use Praxo\Core\PathGrant;
use Praxo\Core\Plugin;
use Praxo\Core\PraxoException;
use Praxo\Core\StreamKinds;
use Praxo\Core\ToolCallParser;

function main(array $argv): int
{
    if (in_array('--api-snapshot', $argv, true)) {
        echo apiSnapshot();
        return 0;
    }
    if (in_array('--check-api', $argv, true)) {
        return checkApi();
    }
    $failures = runAll();
    if ($failures === []) {
        echo "all spec vectors passed\n";
        return 0;
    }
    foreach ($failures as $failure) {
        fwrite(STDERR, $failure . "\n");
    }
    return 1;
}

/** @return list<string> */
function runAll(): array
{
    $root = repoRoot();
    $version = trim((string) file_get_contents($root . '/spec/SPEC_VERSION'));
    $failures = [];
    $seen = [];
    $paths = glob($root . '/spec/vectors/*.json') ?: [];
    sort($paths, SORT_STRING);
    foreach ($paths as $path) {
        $name = pathinfo($path, PATHINFO_FILENAME);
        try {
            $file = Json::decode((string) file_get_contents($path));
            if (!is_array($file)) {
                throw new AssertionFailed('vector file must be an object');
            }
        } catch (\Throwable $error) {
            $failures[] = "{$name}: {$error->getMessage()}";
            continue;
        }
        $group = Json::string($file, 'group') ?? '';
        if (Json::string($file, 'specVersion') !== $version) {
            $failures[] = "{$name}: specVersion mismatch";
        }
        if ($name !== $group) {
            $failures[] = "{$name}: group mismatch";
        }
        foreach (Json::array($file, 'vectors') as $vector) {
            $id = Json::string($vector, 'id') ?? '';
            if (isset($seen[$id])) {
                $failures[] = "{$group}/{$id}: duplicate id with {$seen[$id]}";
            }
            $seen[$id] = $group;
            try {
                runVector($group, $vector);
            } catch (\Throwable $error) {
                $failures[] = "{$group}/{$id}: {$error->getMessage()}";
            }
        }
    }
    return $failures;
}

function runVector(string $group, array $vector): void
{
    $input = Json::get($vector, 'input') ?? [];
    $expect = Json::get($vector, 'expect') ?? [];
    match ($group) {
        'toolcall' => runToolcall($input, $expect),
        'jsonschema' => runJsonSchema($input, $expect),
        'plugin' => runPlugin($input, $expect),
        'memory' => runMemory($input, $expect),
        'event' => runEvent($input, $expect),
        'stream' => runStream($expect),
        'checkpoint' => runCheckpoint($input, $expect),
        'policy' => runPolicy($input, $expect),
        'context' => runContext($input, $expect),
        'middleware' => runMiddlewareVector($input, $expect),
        'agent-loop' => runAgentVector($input, $expect),
        default => throw new AssertionFailed("no runner for group {$group}"),
    };
}

function runToolcall(array $input, array $expect): void
{
    $operation = Json::string($input, 'operation') ?? '';
    $content = Json::string($input, 'content') ?? '';
    if ($operation === 'strip') {
        $got = ToolCallParser::stripMarkup($content);
        check($got === (Json::string($expect, 'text') ?? ''), "strip: got {$got}");
        return;
    }
    $call = ToolCallParser::parse($content);
    if (Json::bool($expect, 'nil')) {
        check($call === null, 'expected nil');
        return;
    }
    check($call !== null, 'expected a tool call');
    check($call->name === (Json::string($expect, 'name') ?? ''), "name: got {$call->name}");
    $want = Json::get($expect, 'input');
    check(Json::equals($call->input, is_array($want) ? $want : []), 'input mismatch');
}

function runJsonSchema(array $input, array $expect): void
{
    $errors = JsonSchema::validate(Json::get($input, 'schema'), Json::get($input, 'data'));
    $paths = array_map(static fn ($error) => $error->path, $errors);
    sort($paths, SORT_STRING);
    $want = [];
    foreach (Json::array($expect, 'errorPaths') as $path) {
        if (is_string($path)) {
            $want[] = $path;
        }
    }
    sort($want, SORT_STRING);
    check(($errors === []) === Json::bool($expect, 'valid'), 'valid mismatch');
    check($paths === $want, 'errorPaths: got [' . implode(', ', $paths) . ']');
}

function runPlugin(array $input, array $expect): void
{
    $raw = Json::string($input, 'raw') ?? Json::encode(Json::get($input, 'manifest'));
    try {
        $manifest = Plugin::parseManifest($raw);
    } catch (PraxoException) {
        $manifest = null;
    }
    check(($manifest !== null) === Json::bool($expect, 'valid'), 'valid mismatch');
    if ($manifest === null) {
        return;
    }
    $id = Json::string($expect, 'id');
    if ($id !== null) {
        check($manifest->id === $id, "id: got {$manifest->id}");
    }
    $kind = Json::string($expect, 'kind');
    if ($kind !== null) {
        check($manifest->kind === $kind, "kind: got {$manifest->kind}");
    }
}

function runMemory(array $input, array $expect): void
{
    $store = new InMemoryMemoryStore();
    foreach (Json::array($input, 'puts') as $put) {
        $record = Json::get($put, 'record');
        $store->put(
            Json::string($put, 'session') ?? '',
            new MemoryRecord(
                id: Json::string($record, 'id') ?? '',
                frame: Json::string($record, 'frame') ?? '',
                content: Json::string($record, 'content') ?? '',
                createdAt: Json::string($record, 'createdAt'),
            ),
        );
    }
    $records = $store->search(
        Json::string($input, 'session') ?? '',
        Json::string($input, 'query') ?? '',
        Json::int($input, 'limit'),
    );
    $ids = array_map(static fn (MemoryRecord $record): string => $record->id, $records);
    $contents = array_map(static fn (MemoryRecord $record): string => $record->content, $records);
    check(Json::equals(normalize($ids), Json::get($expect, 'ids')), 'ids mismatch');
    check(Json::equals(normalize($contents), Json::get($expect, 'contents')), 'contents mismatch');
}

function runEvent(array $input, array $expect): void
{
    $events = [];
    foreach (Json::array($input, 'events') as $type) {
        if (is_string($type)) {
            $events[] = new Event($type, 's1');
        }
    }
    if (Json::string($input, 'sink') === 'multi') {
        $count = max(1, Json::int($input, 'sinkCount', 1));
        $sinks = [];
        for ($index = 0; $index < $count; $index++) {
            $sinks[] = new RecordingSink();
        }
        $multi = new MultiSink($sinks);
        foreach ($events as $event) {
            $multi->emit($event);
        }
        $perSink = array_map(static fn (RecordingSink $sink): array => $sink->types, $sinks);
        check(Json::equals($perSink, Json::get($expect, 'perSink')), 'perSink mismatch');
        return;
    }
    $allowed = null;
    $predicate = Json::get($input, 'predicateTypes');
    if (is_array($predicate)) {
        $allowed = array_fill_keys(array_filter($predicate, 'is_string'), true);
    }
    $sink = new RecordingSink();
    $filter = new FilterSink(
        $sink,
        static fn (Event $event): bool => $allowed === null || isset($allowed[$event->type]),
    );
    foreach ($events as $event) {
        $filter->emit($event);
    }
    check(Json::equals(normalize($sink->types), Json::get($expect, 'delivered')), 'delivered mismatch');
}

function runStream(array $expect): void
{
    check(Json::equals(StreamKinds::ALL, Json::get($expect, 'kinds')), 'kinds mismatch');
}

function runCheckpoint(array $input, array $expect): void
{
    $allow = new CheckpointAllowlist();
    foreach (Json::array($input, 'registered') as $type) {
        if (is_string($type)) {
            $allow->register($type);
        }
    }
    $operation = Json::string($input, 'operation') ?? 'roundtrip';
    $type = Json::string($input, 'type') ?? '';
    $value = Json::get($input, 'value');
    if ($operation === 'roundtrip') {
        $data = $allow->marshal($type, $value);
        $got = $allow->unmarshal($data);
        check(Json::equals($got, Json::get($expect, 'value')), 'value mismatch');
        return;
    }
    try {
        if ($operation === 'marshal') {
            $allow->marshal($type, $value);
        } elseif ($operation === 'unmarshal') {
            $allow->unmarshal(Json::encode(['type' => $type, 'data' => $value]));
        } else {
            throw new AssertionFailed('CHECKPOINT_ERROR');
        }
        check(Json::get($expect, 'errorCode') === null, 'expected an error');
    } catch (PraxoException $error) {
        check($error->praxoCode === (Json::string($expect, 'errorCode') ?? ''), "errorCode: got {$error->praxoCode}");
    }
}

function runPolicy(array $input, array $expect): void
{
    $root = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'praxo-policy-' . bin2hex(random_bytes(8));
    mkdir($root, 0777, true);
    try {
        foreach (Json::array($input, 'makeDirs') as $dir) {
            if (is_string($dir)) {
                $path = $root . DIRECTORY_SEPARATOR . $dir;
                if (!is_dir($path)) {
                    mkdir($path, 0777, true);
                }
            }
        }
        $grants = [];
        foreach (Json::array($input, 'grants') as $item) {
            $grantRoot = $root . DIRECTORY_SEPARATOR . (Json::string($item, 'root') ?? '');
            if (!is_dir($grantRoot)) {
                mkdir($grantRoot, 0777, true);
            }
            $grants[] = new PathGrant($grantRoot, Json::string($item, 'access') ?? 'read');
        }
        $checker = new PathChecker($grants);
        $target = $root . DIRECTORY_SEPARATOR . (Json::string($input, 'target') ?? '');
        $need = Json::string($input, 'need') ?? 'read';
        if (Json::bool($expect, 'error')) {
            try {
                $checker->check($target, $need);
                check(false, 'expected a policy error');
            } catch (PraxoException $error) {
                check($error->praxoCode === 'POLICY_ERROR', "errorCode: got {$error->praxoCode}");
            }
            return;
        }
        $allowed = $checker->check($target, $need)->allowed;
        check($allowed === Json::bool($expect, 'allowed'), "allowed: got " . ($allowed ? 'true' : 'false'));
    } finally {
        removeTree($root);
    }
}

function runContext(array $input, array $expect): void
{
    $messages = [];
    foreach (Json::array($input, 'messages') as $item) {
        $messages[] = new Message(
            role: Json::string($item, 'role') ?? '',
            content: Json::string($item, 'content'),
        );
    }
    if (Json::string($input, 'operation') === 'estimate') {
        $tokens = ContextEstimator::estimateTokens($messages);
        check($tokens === Json::int($expect, 'tokens'), "tokens: got {$tokens}");
        return;
    }
    $budget = new ContextBudget(
        Json::int(Json::get($input, 'budget'), 'maxTokens'),
        Json::int(Json::get($input, 'budget'), 'keepRecent'),
    );
    [$output, $ok] = $budget->compact($messages);
    check($ok === Json::bool($expect, 'ok'), 'ok: got ' . ($ok ? 'true' : 'false'));
    if (!$ok) {
        return;
    }
    $tokens = ContextEstimator::estimateTokens($output);
    check($tokens === Json::int($expect, 'tokens'), "tokens: got {$tokens}");
    $wire = array_map(static fn (Message $message): array => $message->toArray(), $output);
    check(Json::equals($wire, Json::get($expect, 'messages')), 'messages mismatch');
}

function removeTree(string $path): void
{
    if (!is_dir($path)) {
        return;
    }
    foreach (scandir($path) ?: [] as $item) {
        if ($item === '.' || $item === '..') {
            continue;
        }
        $child = $path . DIRECTORY_SEPARATOR . $item;
        is_dir($child) ? removeTree($child) : @unlink($child);
    }
    @rmdir($path);
}

exit(main($argv));
