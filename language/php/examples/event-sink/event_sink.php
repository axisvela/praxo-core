<?php

declare(strict_types=1);

$autoload = __DIR__ . '/vendor/autoload.php';
if (is_file($autoload)) {
    require $autoload;
} else {
    require __DIR__ . '/../../src/autoload.php';
}

use Praxo\Core\Agent;
use Praxo\Core\AgentOptions;
use Praxo\Core\Event;
use Praxo\Core\EventSink;
use Praxo\Core\FilterSink;
use Praxo\Core\FuncTool;
use Praxo\Core\Message;
use Praxo\Core\Model;
use Praxo\Core\MultiSink;
use Praxo\Core\Request;
use Praxo\Core\Response;
use Praxo\Core\Roles;
use Praxo\Core\Session;
use Praxo\Core\ToolCall;
use Praxo\Core\ToolRegistry;

final class RecordingSink implements EventSink
{
    /** @var list<Event> */
    public array $events = [];

    public function emit(Event $event): void
    {
        $this->events[] = $event;
    }

    /** @return list<string> */
    public function types(): array
    {
        return array_map(static fn(Event $event): string => $event->type, $this->events);
    }
}

final class ToolThenAnswerModel implements Model
{
    private int $calls = 0;

    public function generate(Request $request): Response
    {
        $this->calls++;
        if ($this->calls === 1) {
            return new Response(Message::assistant('', [
                new ToolCall('call-1', 'lookup', ['key' => 'status']),
            ]));
        }
        return new Response(Message::assistant('status: green'));
    }
}

final class EventSinkExample
{
    public static function run(EventSink $allSink, EventSink $toolSink): string
    {
        $tools = new ToolRegistry();
        $tools->register(new FuncTool(
            'lookup',
            'Look up a small status value.',
            static fn(array $args): array => [
                'key' => $args['key'] ?? '',
                'value' => 'green',
            ]
        ));
        $options = new AgentOptions(new ToolThenAnswerModel());
        $options->tools = $tools;
        $options->events = new MultiSink([
            $allSink,
            new FilterSink($toolSink, static fn(Event $event): bool => $event->type === 'tool.call'),
        ]);
        $options->systemPrompt = 'Use tools when asked for status.';
        $options->maxSteps = 3;
        return (new Agent($options))
            ->run(new Session('event-sink'), 'Check the status.')
            ->output;
    }
}
