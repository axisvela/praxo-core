<?php

declare(strict_types=1);

$autoload = __DIR__ . '/vendor/autoload.php';
if (is_file($autoload)) {
    require $autoload;
} else {
    require __DIR__ . '/../../language/php/src/autoload.php';
}

use Praxo\Core\Action;
use Praxo\Core\Agent;
use Praxo\Core\AgentOptions;
use Praxo\Core\Decision;
use Praxo\Core\FuncTool;
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

final class FixtureModel implements Model
{
    public function __construct(private readonly string $target)
    {
    }

    public function generate(Request $request): Response
    {
        $last = $request->messages[count($request->messages) - 1];
        if ($last->role === Roles::TOOL) {
            return new Response(Message::assistant('recorded'));
        }
        return new Response(Message::assistant('', [
            new ToolCall('record-1', 'record', ['target' => $this->target]),
        ]));
    }
}

final class StarterPolicy implements PolicyHook
{
    public function authorize(Action $action): Decision
    {
        return match ($action->kind) {
            'model.generate' => Decision::allow('model generation'),
            'tool.invoke' => $action->toolName === 'record'
                && ($action->arguments['target'] ?? null) === 'public'
                ? Decision::allow('public target')
                : Decision::deny('only the public target is permitted'),
            default => Decision::deny('unsupported action'),
        };
    }
}

final class Starter
{
    /** @return array{0: string, 1: int, 2: ?Throwable} */
    public static function runScenario(string $target): array
    {
        $calls = 0;
        $registry = new ToolRegistry();
        $registry->register(new FuncTool('record', 'Record a target in an in-memory counter.',
            static function (array $arguments) use (&$calls): array {
                $calls++;
                return ['output' => 'recorded'];
            }));

        $options = new AgentOptions(new FixtureModel($target));
        $options->tools = $registry;
        $options->allowedTools = ['record'];
        $options->policy = new StarterPolicy();

        try {
            $result = (new Agent($options))->run(new Session('consumer-' . $target), 'Record the requested target.');
            return [$result->output, $calls, null];
        } catch (PraxoException $error) {
            return ['', $calls, $error];
        }
    }

    public static function run(): void
    {
        [$output, $calls, $error] = self::runScenario('public');
        if ($error !== null || $output !== 'recorded' || $calls !== 1) {
            throw new RuntimeException("allow verification failed: output={$output} effects={$calls} error={$error?->getMessage()}");
        }
        echo "allow: recorded; effects=1\n";

        [, $calls, $error] = self::runScenario('private');
        if ($error === null || $error->praxoCode !== 'AGENT_POLICY_DENIED' || $calls !== 0) {
            throw new RuntimeException("deny verification failed: effects={$calls} error={$error?->getMessage()}");
        }
        echo "deny: policy rejected; effects=0\n";
    }
}

if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    Starter::run();
}
