<?php

declare(strict_types=1);

namespace Praxo\Core;

interface Model
{
    public function generate(Request $request): Response;
}

interface StreamingModel extends Model
{
    /** @param callable(string): void $onDelta */
    public function generateStream(Request $request, callable $onDelta): Response;
}

interface Tool
{
    public function name(): string;

    public function description(): string;

    public function invoke(array $arguments): mixed;
}

final class FuncTool implements Tool
{
    private \Closure $function;

    public function __construct(
        private string $toolName,
        private string $toolDescription,
        callable $function,
    ) {
        $this->function = \Closure::fromCallable($function);
    }

    public function name(): string
    {
        return $this->toolName;
    }

    public function description(): string
    {
        return $this->toolDescription;
    }

    public function invoke(array $arguments): mixed
    {
        return ($this->function)($arguments);
    }
}

final class ToolRegistry
{
    /** @var array<string, Tool> */
    private array $tools = [];

    public function register(Tool $tool): void
    {
        $this->tools[$tool->name()] = $tool;
    }

    public function get(string $name): Tool
    {
        if (!isset($this->tools[$name])) {
            throw PraxoException::toolNotFound("tool not found: {$name}");
        }
        return $this->tools[$name];
    }

    public function contains(string $name): bool
    {
        return isset($this->tools[$name]);
    }

    /** @return list<ToolSpec> */
    public function specs(): array
    {
        $specs = array_map(
            static fn (Tool $tool): ToolSpec => new ToolSpec($tool->name(), $tool->description()),
            array_values($this->tools),
        );
        usort($specs, static fn (ToolSpec $left, ToolSpec $right): int => strcmp($left->name, $right->name));
        return $specs;
    }

    public function count(): int
    {
        return count($this->tools);
    }
}

final class StaticModel implements Model
{
    public function __construct(private string $content)
    {
    }

    public function generate(Request $request): Response
    {
        return new Response(Message::assistant($this->content));
    }
}

final class AgentOptions
{
    public ?ToolRegistry $tools = null;
    public ?EventSink $events = null;
    public ?PolicyHook $policy = null;
    public string $systemPrompt = '';
    /** @var list<string> */
    public array $memoryFiles = [];
    public ?ContextBudget $context = null;
    /** @var list<BaseMiddleware> */
    public array $middleware = [];
    /** @var list<callable> */
    public array $modelMiddleware = [];
    public ?StructuredOutput $structuredOutput = null;
    /** @var list<string> */
    public array $allowedTools = [];
    public ?ToolSelector $toolSelector = null;
    public ?PiiRedactor $piiRedactor = null;
    public int $modelCallLimit = 0;
    public int $toolCallLimit = 0;
    public ?Model $fallbackModel = null;
    public ?string $toolChoice = null;
    public ?array $responseFormat = null;
    public int $maxSteps = 8;
    public int $maxTokens = 0;

    public function __construct(public Model $model)
    {
    }
}

final class Agent
{
    private string $systemPrompt;
    /** @var list<BaseMiddleware> */
    private array $middleware;
    /** @var list<callable> */
    private array $modelMiddleware;

    public function __construct(private AgentOptions $options)
    {
        $memory = self::loadAgentsMd($options->memoryFiles);
        $this->systemPrompt = $memory === ''
            ? $options->systemPrompt
            : trim($options->systemPrompt . "\n\n" . $memory);
        $middleware = $options->middleware;
        if ($options->structuredOutput !== null) {
            $middleware[] = $options->structuredOutput;
        }
        if ($options->toolSelector !== null) {
            $middleware[] = new ToolSelectionMiddleware($options->toolSelector);
        }
        if ($options->piiRedactor !== null) {
            $middleware[] = new PiiMiddleware($options->piiRedactor);
        }
        if ($options->modelCallLimit > 0 || $options->toolCallLimit > 0) {
            $middleware[] = new CallLimitMiddleware($options->modelCallLimit, $options->toolCallLimit);
        }
        $this->middleware = self::mergeMiddleware($middleware);
        $this->modelMiddleware = $options->modelMiddleware;
        if ($options->fallbackModel !== null) {
            $this->modelMiddleware[] = ModelFallback::fallback($options->fallbackModel);
        }
    }

    public function run(Session $session, string $prompt): RunResult
    {
        $maxSteps = $this->options->maxSteps > 0 ? $this->options->maxSteps : 8;
        $runId = 'run-' . (int) floor(microtime(true) * 1000);
        $messages = array_map(self::cloneMessage(...), $session->messages);
        if ($this->systemPrompt !== '') {
            array_unshift($messages, Message::text(Roles::SYSTEM, $this->systemPrompt));
        }
        $messages[] = Message::text(Roles::USER, $prompt);
        $usage = new Usage();

        $this->beforeRun($runId, $prompt);
        $this->emit('run.started', $session->id, $runId);
        $afterRunInvoked = false;
        try {
            for ($step = 1; $step <= $maxSteps; $step++) {
                $this->authorize(new Action('model.generate', $session->id));
                $messages = $this->compact($messages);
                $request = new Request(
                    messages: $messages,
                    tools: $this->toolSpecs(),
                    toolChoice: $this->options->toolChoice,
                    responseFormat: $this->options->responseFormat,
                );
                $call = new ModelCall(runId: $runId, sessionId: $session->id, request: $request);
                $this->beforeModel($call);
                if ($call->skip) {
                    $response = $call->response
                        ?? throw new PraxoException('AGENT_MIDDLEWARE', 'agent: model middleware skipped without a response');
                } else {
                    $response = $this->generate($call->request);
                }
                $this->afterModel($call, $response);
                $usage = $usage->plus($response->usage);
                if ($this->options->maxTokens > 0
                    && $usage->inputTokens + $usage->outputTokens > $this->options->maxTokens) {
                    throw PraxoException::maxTokens();
                }
                $messages[] = $response->message;
                if ($response->message->toolCalls === []) {
                    $result = new RunResult(
                        runId: $runId,
                        output: $response->message->content ?? '',
                        steps: $step,
                        usage: $usage,
                    );
                    $afterRunInvoked = true;
                    $this->afterRun($result, null);
                    $this->emit('run.completed', $session->id, $runId);
                    return $result;
                }
                foreach ($response->message->toolCalls as $toolCall) {
                    $messages[] = $this->invokeTool($toolCall, $runId, $session->id);
                }
            }
            throw PraxoException::maxSteps();
        } catch (PraxoException $error) {
            if (!$afterRunInvoked) {
                $this->afterRun(null, $error);
            }
            $this->emit('run.failed', $session->id, $runId, ['error' => $error->getMessage()]);
            throw $error;
        }
    }

    /** @param list<Message> $messages @return list<Message> */
    private function compact(array $messages): array
    {
        if ($this->options->context === null || $this->options->context->maxTokens === 0) {
            return $messages;
        }
        [$output, $ok] = $this->options->context->compact($messages);
        if (!$ok) {
            throw PraxoException::contextBudget();
        }
        return $output;
    }

    /** @return list<ToolSpec> */
    private function toolSpecs(): array
    {
        if ($this->options->tools === null) {
            return [];
        }
        $specs = $this->options->tools->specs();
        if ($this->options->allowedTools === []) {
            return $specs;
        }
        return array_values(array_filter(
            $specs,
            fn (ToolSpec $spec): bool => in_array($spec->name, $this->options->allowedTools, true),
        ));
    }

    private function toolAllowed(string $name): bool
    {
        return $this->options->allowedTools === []
            || in_array($name, $this->options->allowedTools, true);
    }

    private function generate(Request $request): Response
    {
        $handler = fn (Request $req): Response => $this->options->model->generate($req);
        foreach (array_reverse($this->modelMiddleware) as $middleware) {
            $handler = $middleware($handler);
        }
        return $handler($request);
    }

    private function invokeTool(ToolCall $call, string $runId, string $sessionId): Message
    {
        if (!$this->toolAllowed($call->name)) {
            throw new PraxoException('AGENT_TOOL_NOT_ALLOWED', "agent: tool {$call->name} is not allowed");
        }
        $this->authorize(new Action('tool.invoke', $sessionId, $call->name, $call->arguments));
        $tools = $this->options->tools
            ?? throw PraxoException::toolNotFound("tool {$call->name} is not registered");
        $tool = $tools->get($call->name);
        $middlewareCall = new MiddlewareToolCall($runId, $sessionId, $call);
        $this->beforeTool($middlewareCall);
        if ($middlewareCall->skip) {
            $value = $middlewareCall->result;
            $error = $middlewareCall->error;
        } else {
            $this->emit('tool.call', $sessionId, $runId, [
                'name' => $call->name,
                'arguments' => $call->arguments,
            ]);
            try {
                $value = $tool->invoke($call->arguments);
                $error = null;
            } catch (PraxoException $exception) {
                $value = null;
                $error = $exception;
            }
        }
        $result = new ToolResult($value, $error);
        $this->afterTool($middlewareCall, $result);
        if ($result->error !== null) {
            throw $result->error;
        }
        return Message::tool(Json::encode($result->value), $call->id);
    }

    private function authorize(Action $action): void
    {
        if ($this->options->policy === null) {
            return;
        }
        $decision = $this->options->policy->authorize($action);
        if (!$decision->allowed) {
            throw new PraxoException(
                'AGENT_POLICY_DENIED',
                "agent: {$action->kind} denied: {$decision->reason}",
            );
        }
    }

    private function beforeRun(string $runId, string $prompt): void
    {
        $state = new RunState($runId, $prompt);
        foreach ($this->middleware as $middleware) {
            $middleware->beforeRun($state);
        }
    }

    private function beforeModel(ModelCall $call): void
    {
        foreach ($this->middleware as $middleware) {
            $middleware->beforeModel($call);
            if ($call->skip) {
                break;
            }
        }
    }

    private function afterModel(ModelCall $call, Response $response): void
    {
        foreach ($this->middleware as $middleware) {
            $middleware->afterModel($call, $response);
        }
    }

    private function beforeTool(MiddlewareToolCall $call): void
    {
        foreach ($this->middleware as $middleware) {
            $middleware->beforeTool($call);
            if ($call->skip) {
                break;
            }
        }
    }

    private function afterTool(MiddlewareToolCall $call, ToolResult $result): void
    {
        foreach ($this->middleware as $middleware) {
            $middleware->afterTool($call, $result);
        }
    }

    private function afterRun(?RunResult $result, ?PraxoException $error): void
    {
        foreach ($this->middleware as $middleware) {
            $middleware->afterRun($result, $error);
        }
    }

    private function emit(string $type, string $sessionId, string $runId, ?array $data = null): void
    {
        $event = new Event($type, $sessionId, $runId, $data);
        $this->options->events?->emit($event);
    }

    /** @param list<BaseMiddleware> $items @return list<BaseMiddleware> */
    private static function mergeMiddleware(array $items): array
    {
        $output = [];
        $positions = [];
        foreach ($items as $item) {
            $name = $item->name();
            if ($name === '') {
                $output[] = $item;
                continue;
            }
            if (isset($positions[$name])) {
                $output[$positions[$name]] = $item;
                continue;
            }
            $positions[$name] = count($output);
            $output[] = $item;
        }
        return $output;
    }

    private static function cloneMessage(Message $message): Message
    {
        $blocks = array_map(
            static fn (ContentBlock $block): ContentBlock => new ContentBlock(
                $block->type,
                $block->text,
                $block->imageUrl,
                $block->data,
            ),
            $message->contentBlocks,
        );
        $calls = array_map(
            static fn (ToolCall $call): ToolCall => new ToolCall($call->id, $call->name, $call->arguments),
            $message->toolCalls,
        );
        return new Message($message->role, $message->content, $blocks, $calls, $message->toolId);
    }

    /** @param list<string> $paths */
    private static function loadAgentsMd(array $paths): string
    {
        $maxBytes = 64 * 1024;
        $output = '';
        $used = 0;
        foreach ($paths as $path) {
            if (trim($path) === '' || !is_file($path)) {
                continue;
            }
            $text = trim((string) file_get_contents($path));
            if ($text === '') {
                continue;
            }
            $chunk = "## AGENTS.md: {$path}\n{$text}";
            $bytes = strlen($chunk);
            if ($used + $bytes > $maxBytes) {
                break;
            }
            if ($output !== '') {
                $output .= "\n\n";
            }
            $output .= $chunk;
            $used += $bytes;
        }
        return $output;
    }
}
