<?php

declare(strict_types=1);

$autoload = __DIR__ . '/vendor/autoload.php';
if (is_file($autoload)) {
    require $autoload;
} else {
    require __DIR__ . '/../../src/autoload.php';
}

use Praxo\Core\Action;
use Praxo\Core\Adapters\OpenAICompatible;
use Praxo\Core\Agent;
use Praxo\Core\AgentOptions;
use Praxo\Core\Decision;
use Praxo\Core\PolicyHook;
use Praxo\Core\Session;
use Praxo\Core\Tool;
use Praxo\Core\ToolRegistry;

final class GetTimeTool implements Tool
{
    public ?array $parameters = [
        'type' => 'object',
        'properties' => [
            'zone' => [
                'type' => 'string',
                'enum' => ['utc', 'local'],
                'description' => 'utc or local; defaults to utc',
            ],
        ],
    ];

    public ?string $risk = 'read';

    public function name(): string
    {
        return 'get_time';
    }

    public function description(): string
    {
        return 'Return the current time in ISO 8601 format for the requested zone.';
    }

    public function invoke(array $arguments): mixed
    {
        $zone = ($arguments['zone'] ?? 'utc') === 'local'
            ? new DateTimeZone(date_default_timezone_get())
            : new DateTimeZone('UTC');
        return (new DateTimeImmutable('now', $zone))->format(DateTimeInterface::ATOM);
    }
}

final class AllowGetTime implements PolicyHook
{
    public function authorize(Action $action): Decision
    {
        return match ($action->kind) {
            'model.generate' => Decision::allow('model generation'),
            'tool.invoke' => $action->toolName === 'get_time'
                ? Decision::allow('get_time is permitted')
                : Decision::deny('only get_time is permitted'),
            default => Decision::deny('unsupported action'),
        };
    }
}

function envOr(string $name, string $fallback): string
{
    $value = getenv($name);
    return $value === false || $value === '' ? $fallback : $value;
}

$baseUrl = envOr('PRAXO_BASE_URL', 'http://localhost:11434/v1');
$modelName = envOr('PRAXO_MODEL', 'qwen3.5:4b');
$prompt = envOr(
    'PRAXO_PROMPT',
    'What time is it? Use get_time with zone set to utc and reply with the time.'
);

$tools = new ToolRegistry();
$tools->register(new GetTimeTool());

$options = new AgentOptions(new OpenAICompatible(
    $baseUrl,
    $modelName,
    envOr('PRAXO_API_KEY', ''),
));
$options->tools = $tools;
$options->systemPrompt = 'You are a concise assistant. Use the provided tools when they help.';
$options->maxSteps = 4;
$options->allowedTools = ['get_time'];
$options->policy = new AllowGetTime();

try {
    $result = (new Agent($options))->run(new Session('live-model'), $prompt);
    echo $result->output . "\n";
} catch (Throwable $error) {
    fwrite(STDERR, "live model run failed: {$error->getMessage()}\n\n"
        . "Check PRAXO_BASE_URL ({$baseUrl}), PRAXO_MODEL ({$modelName}), and PRAXO_API_KEY\n");
    exit(1);
}
