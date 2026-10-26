<?php

declare(strict_types=1);

namespace Praxo\Conformance;

use Praxo\Core\Event;
use Praxo\Core\EventSink;
use Praxo\Core\Message;
use Praxo\Core\Model;
use Praxo\Core\Request;
use Praxo\Core\Response;
use Praxo\Core\ToolCall;
use Praxo\Core\ToolSelector;
use Praxo\Core\ToolSpec;
use Praxo\Core\Usage;

final class AssertionFailed extends \RuntimeException
{
}

function check(bool $condition, string $message): void
{
    if (!$condition) {
        throw new AssertionFailed($message);
    }
}

function repoRoot(): string
{
    $root = dirname(__DIR__, 2);
    if (!is_file($root . '/spec/SPEC_VERSION')) {
        throw new \RuntimeException('cannot find repository root');
    }
    return $root;
}

function normalize(array $values): mixed
{
    return $values === [] ? null : array_values($values);
}

final class RecordingSink implements EventSink
{
    /** @var list<string> */
    public array $types = [];

    public function emit(Event $event): void
    {
        $this->types[] = $event->type;
    }
}

final class ScriptedModel implements Model
{
    private int $next = 0;

    /** @param list<array> $steps */
    public function __construct(private array $steps)
    {
    }

    public function generate(Request $request): Response
    {
        if ($this->next >= count($this->steps)) {
            throw new \Praxo\Core\PraxoException('SCRIPT', 'script exhausted');
        }
        $step = $this->steps[$this->next++];
        $calls = [];
        foreach ($step['toolCalls'] ?? [] as $call) {
            $calls[] = new ToolCall(
                $call['id'] ?? '',
                $call['name'] ?? '',
                is_array($call['arguments'] ?? null) ? $call['arguments'] : [],
            );
        }
        return new Response(
            message: Message::assistant($step['content'] ?? '', $calls),
            usage: new Usage((int) ($step['inputTokens'] ?? 0), (int) ($step['outputTokens'] ?? 0)),
        );
    }
}

final class FixedSelector implements ToolSelector
{
    /** @param list<string> $names */
    public function __construct(private array $names)
    {
    }

    public function select(string $query, array $tools): array
    {
        return $this->names;
    }
}
