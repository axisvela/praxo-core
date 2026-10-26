<?php

declare(strict_types=1);

namespace Praxo\Conformance;

use Praxo\Core\CallLimitMiddleware;
use Praxo\Core\Json;
use Praxo\Core\MiddlewareToolCall;
use Praxo\Core\ModelCall;
use Praxo\Core\ModelFallback;
use Praxo\Core\PiiMiddleware;
use Praxo\Core\PiiRedactor;
use Praxo\Core\PraxoException;
use Praxo\Core\Request;
use Praxo\Core\RunResult;
use Praxo\Core\RunState;
use Praxo\Core\StructuredOutput;
use Praxo\Core\ToolCall;
use Praxo\Core\ToolResult;
use Praxo\Core\ToolSelectionMiddleware;
use Praxo\Core\ToolSpec;

function runMiddlewareVector(array $input, array $expect): void
{
    switch (Json::string($input, 'operation')) {
        case 'pii':
            $got = PiiRedactor::defaults()->redact(Json::string($input, 'text') ?? '');
            check($got === (Json::string($expect, 'text') ?? ''), "text: got {$got}");
            return;
        case 'pii-value':
            $middleware = new PiiMiddleware(PiiRedactor::defaults());
            $result = new ToolResult(Json::get($input, 'value'));
            $middleware->afterTool(new MiddlewareToolCall(), $result);
            check(Json::equals($result->value, Json::get($expect, 'value')), 'value mismatch');
            return;
        case 'structured':
            $output = new StructuredOutput(
                Json::get($input, 'schema') ?? [],
                maxRepairs: Json::int($input, 'maxRepairs'),
            );
            $repair = Json::string($input, 'repairOutput');
            if ($repair !== null) {
                $output->repairer = static fn (): string => $repair;
            }
            $result = new RunResult(output: Json::string($input, 'output') ?? '');
            try {
                $output->apply($result);
                check(Json::bool($expect, 'ok'), 'expected a structured output error');
                check($result->output === (Json::string($expect, 'output') ?? ''), "output: got {$result->output}");
            } catch (PraxoException $error) {
                check(!Json::bool($expect, 'ok'), $error->getMessage());
                check($error->praxoCode === (Json::string($expect, 'errorCode') ?? ''), "errorCode: got {$error->praxoCode}");
            }
            return;
        case 'call-limit':
            $middleware = new CallLimitMiddleware(
                Json::int($input, 'modelLimit'),
                Json::int($input, 'toolLimit'),
            );
            $middleware->beforeRun(new RunState('r1'));
            $outcomes = [];
            foreach (Json::array($input, 'calls') as $kind) {
                try {
                    if ($kind === 'model') {
                        $middleware->beforeModel(new ModelCall(runId: 'r1'));
                    } else {
                        $middleware->beforeTool(new MiddlewareToolCall(runId: 'r1', call: new ToolCall(name: 'echo')));
                    }
                    $outcomes[] = 'ok';
                } catch (PraxoException $error) {
                    $outcomes[] = $error->praxoCode;
                }
            }
            check(Json::equals($outcomes, Json::get($expect, 'outcomes')), 'outcomes mismatch');
            return;
        case 'tool-selection':
            $selected = array_values(array_filter(Json::array($input, 'selected'), 'is_string'));
            $middleware = new ToolSelectionMiddleware(new FixedSelector($selected));
            $tools = [];
            foreach (Json::array($input, 'tools') as $name) {
                if (is_string($name)) {
                    $tools[] = new ToolSpec($name);
                }
            }
            $call = new ModelCall(runId: 'r1', request: new Request(tools: $tools));
            $middleware->beforeModel($call);
            $advertised = array_map(static fn (ToolSpec $tool): string => $tool->name, $call->request->tools);
            check(Json::equals($advertised, Json::get($expect, 'advertised')), 'advertised mismatch');
            try {
                $middleware->beforeTool(new MiddlewareToolCall(
                    runId: 'r1',
                    call: new ToolCall(name: Json::string($input, 'requested') ?? ''),
                ));
                $reject = 'ok';
            } catch (PraxoException $error) {
                $reject = $error->praxoCode;
            }
            check($reject === (Json::string($expect, 'reject') ?? ''), "reject: got {$reject}");
            return;
        case 'fallback':
            $content = Json::string($input, 'fallbackContent') ?? '';
            $handler = ModelFallback::fallbackWithContent($content)(
                static fn () => throw new PraxoException('PRIMARY_FAILED', 'primary failed'),
            );
            $response = $handler(new Request());
            check($response->message->content === $content, 'output mismatch');
            return;
        default:
            throw new AssertionFailed('unknown middleware operation');
    }
}
