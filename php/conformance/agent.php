<?php

declare(strict_types=1);

namespace Praxo\Conformance;

use Praxo\Core\Agent;
use Praxo\Core\AgentOptions;
use Praxo\Core\FuncTool;
use Praxo\Core\Json;
use Praxo\Core\PraxoException;
use Praxo\Core\Session;
use Praxo\Core\ToolRegistry;

function runAgentVector(array $input, array $expect): void
{
    $script = Json::array($input, 'script');
    $invocations = 0;
    $registry = new ToolRegistry();
    foreach (Json::array($input, 'tools') as $tool) {
        $registry->register(new FuncTool(
            Json::string($tool, 'name') ?? '',
            Json::string($tool, 'description') ?? '',
            static function (array $arguments) use (&$invocations): array {
                $invocations++;
                return $arguments;
            },
        ));
    }
    $sink = new RecordingSink();
    $options = new AgentOptions(new ScriptedModel($script));
    $options->tools = $registry;
    $options->events = $sink;
    $options->maxSteps = Json::int($input, 'maxSteps');
    $options->maxTokens = Json::int($input, 'maxTokens');
    $agent = new Agent($options);
    $result = null;
    $failure = null;
    try {
        $result = $agent->run(new Session('s1'), Json::string($input, 'prompt') ?? '');
    } catch (PraxoException $error) {
        $failure = $error;
    }
    if (Json::bool($expect, 'error')) {
        check($failure !== null, 'unexpected success');
        $code = Json::string($expect, 'errorCode');
        if ($code !== null) {
            check($failure->praxoCode === $code, "errorCode: got {$failure->praxoCode}");
        }
    } else {
        check($failure === null, $failure?->getMessage() ?? 'unexpected failure');
        check($result->output === (Json::string($expect, 'output') ?? ''), "output: got {$result->output}");
        check($result->steps === Json::int($expect, 'steps'), "steps: got {$result->steps}");
    }
    check($invocations === Json::int($expect, 'toolInvocations'), "tool invocations: got {$invocations}");
    check(Json::equals(normalize($sink->types), Json::get($expect, 'events')), 'events mismatch');
}
