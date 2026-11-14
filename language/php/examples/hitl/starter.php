<?php

declare(strict_types=1);

$autoload = __DIR__ . '/vendor/autoload.php';
if (is_file($autoload)) {
    require $autoload;
} else {
    require __DIR__ . '/../../src/autoload.php';
}

use Praxo\Core\Action;
use Praxo\Core\Agent;
use Praxo\Core\AgentOptions;
use Praxo\Core\Decision;
use Praxo\Core\FuncTool;
use Praxo\Core\Interrupt;
use Praxo\Core\InterruptAction;
use Praxo\Core\InterruptDecision;
use Praxo\Core\Message;
use Praxo\Core\Model;
use Praxo\Core\PolicyHook;
use Praxo\Core\PraxoException;
use Praxo\Core\Request;
use Praxo\Core\Response;
use Praxo\Core\Roles;
use Praxo\Core\Session;
use Praxo\Core\ToolCall;
use Praxo\Core\ToolRegistry;
use Praxo\Core\ToolSpec;

final class FixtureModel implements Model
{
    public function generate(Request $request): Response
    {
        $last = $request->messages[count($request->messages) - 1];
        if ($last->role === Roles::TOOL) {
            return new Response(Message::assistant('done'));
        }
        return new Response(Message::assistant('', [
            new ToolCall('write-note-1', 'write_note', [
                'text' => 'hello',
                'visibility' => 'public',
            ]),
        ]));
    }
}

final class WriteNoteTool implements \Praxo\Core\Tool
{
    /** @var list<string> */
    public array $notes = [];

    public function name(): string
    {
        return 'write_note';
    }

    public function description(): string
    {
        return 'Write a short note with the requested visibility.';
    }

    public function invoke(array $arguments): mixed
    {
        $this->notes[] = (string) ($arguments['text'] ?? '');
        return 'written';
    }

    public function spec(): ToolSpec
    {
        return new ToolSpec(
            $this->name(),
            $this->description(),
            [
                'type' => 'object',
                'required' => ['text', 'visibility'],
                'properties' => [
                    'text' => ['type' => 'string'],
                    'visibility' => ['type' => 'string', 'enum' => ['public', 'private']],
                ],
            ],
            'write',
        );
    }
}

final class PublicNotesPolicy implements PolicyHook
{
    public function authorize(Action $action): Decision
    {
        if ($action->kind === 'model.generate') {
            return Decision::allow('model generation');
        }
        if ($action->kind === 'tool.invoke') {
            return $action->toolName === 'write_note'
                && ($action->arguments['visibility'] ?? null) === 'public'
                ? Decision::allow('only public notes are permitted')
                : Decision::deny('only public notes are permitted');
        }
        return Decision::deny('unsupported action');
    }
}

final class HitlStarter
{
    /** @return array{0: string, 1: int, 2: ?PraxoException} */
    public static function runScenario(InterruptDecision $decision): array
    {
        $tool = new WriteNoteTool();
        $registry = new ToolRegistry();
        $registry->register($tool);
        $options = new AgentOptions(new FixtureModel());
        $options->tools = $registry;
        $options->maxSteps = 3;
        $options->allowedTools = ['write_note'];
        $options->policy = new PublicNotesPolicy();
        $options->interruptOn = ['write_note'];
        $options->onInterruptDecision = static fn (Interrupt $interrupt): InterruptDecision => $decision;

        try {
            $result = (new Agent($options))->run(
                new Session('hitl'),
                'Write a note.'
            );
            return [$result->output, count($tool->notes), null];
        } catch (PraxoException $error) {
            return ['', count($tool->notes), $error];
        }
    }

    public static function run(): void
    {
        [$output, $effects, $error] = self::runScenario(
            new InterruptDecision(InterruptAction::APPROVE)
        );
        if ($error !== null || $output !== 'done' || $effects !== 1) {
            throw new RuntimeException(
                "approve scenario failed: output={$output} effects={$effects}"
            );
        }
        echo "approve: written; effects=1\n";

        [, $effects, $error] = self::runScenario(new InterruptDecision(
            InterruptAction::EDIT,
            ['text' => 'hello', 'visibility' => 'private'],
        ));
        if ($error === null || $error->praxoCode !== 'AGENT_POLICY_DENIED' || $effects !== 0) {
            throw new RuntimeException(
                "edit scenario failed: effects={$effects}"
            );
        }
        echo "edit: policy rejected; effects=0\n";
    }
}

HitlStarter::run();
