<?php

declare(strict_types=1);

namespace Praxo\Core;

final class RunState
{
    public function __construct(
        public string $runId = '',
        public string $prompt = '',
    ) {
    }
}

final class ModelCall
{
    public function __construct(
        public string $runId = '',
        public string $sessionId = '',
        public Request $request = new Request(),
        public bool $skip = false,
        public ?Response $response = null,
    ) {
    }
}

final class MiddlewareToolCall
{
    public function __construct(
        public string $runId = '',
        public string $sessionId = '',
        public ToolCall $call = new ToolCall(),
        public bool $skip = false,
        public mixed $result = null,
        public ?PraxoException $error = null,
    ) {
    }
}

final class ToolResult
{
    public function __construct(
        public mixed $value = null,
        public ?PraxoException $error = null,
    ) {
    }
}

abstract class BaseMiddleware
{
    public function name(): string
    {
        return '';
    }

    public function beforeRun(RunState $state): void
    {
    }

    public function beforeModel(ModelCall $call): void
    {
    }

    public function afterModel(ModelCall $call, Response $response): void
    {
    }

    public function beforeTool(MiddlewareToolCall $call): void
    {
    }

    public function afterTool(MiddlewareToolCall $call, ToolResult $result): void
    {
    }

    public function afterRun(?RunResult $result, ?PraxoException $error): void
    {
    }
}

final class PiiRule
{
    public function __construct(
        public string $name,
        public string $pattern,
        public string $replacement,
    ) {
    }
}

final class PiiRedactor
{
    /** @param list<PiiRule> $rules */
    public function __construct(private array $rules)
    {
    }

    public static function defaults(): self
    {
        return new self([
            new PiiRule('email', '~[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}~', '[REDACTED:email]'),
            new PiiRule('ssn', '~\b\d{3}-\d{2}-\d{4}\b~', '[REDACTED:ssn]'),
            new PiiRule('credit_card', '~\b(?:\d{4}[ -]?){3}\d{4}\b~', '[REDACTED:credit_card]'),
            new PiiRule('phone', '~\b(?:\+?1[-. ]?)?\(?\d{3}\)?[-. ]?\d{3}[-. ]?\d{4}\b~', '[REDACTED:phone]'),
        ]);
    }

    public function redact(string $text): string
    {
        $output = $text;
        foreach ($this->rules as $rule) {
            $output = preg_replace($rule->pattern, $rule->replacement, $output) ?? $output;
        }
        return $output;
    }

    public function redactValue(mixed $value): mixed
    {
        if (is_string($value)) {
            return $this->redact($value);
        }
        if (is_array($value)) {
            $output = [];
            foreach ($value as $key => $item) {
                $output[$key] = $this->redactValue($item);
            }
            return $output;
        }
        return $value;
    }
}

final class PiiMiddleware extends BaseMiddleware
{
    public function __construct(private PiiRedactor $redactor)
    {
    }

    public function name(): string
    {
        return 'pii';
    }

    public function beforeModel(ModelCall $call): void
    {
        $messages = [];
        foreach ($call->request->messages as $message) {
            $blocks = [];
            foreach ($message->contentBlocks as $block) {
                $blocks[] = new ContentBlock(
                    $block->type,
                    $this->redactor->redact($block->text ?? ''),
                    $block->imageUrl,
                    $block->data,
                );
            }
            $messages[] = new Message(
                role: $message->role,
                content: $this->redactor->redact($message->content ?? ''),
                contentBlocks: $blocks,
                toolCalls: $message->toolCalls,
                toolId: $message->toolId,
            );
        }
        $call->request = new Request(
            messages: $messages,
            tools: $call->request->tools,
            toolChoice: $call->request->toolChoice,
            responseFormat: $call->request->responseFormat,
            temperature: $call->request->temperature,
        );
    }

    public function afterTool(MiddlewareToolCall $call, ToolResult $result): void
    {
        $result->value = $this->redactor->redactValue($result->value);
    }
}

final class StructuredOutput extends BaseMiddleware
{
    public const STRATEGY_AUTO = 'auto';
    public const STRATEGY_PROVIDER = 'provider';
    public const STRATEGY_TOOL = 'tool';

    /** @var callable(string, PraxoException): string|null */
    public $repairer = null;

    public function __construct(
        public array $schema,
        public string $outputName = 'structured_output',
        public string $strategy = self::STRATEGY_AUTO,
        public int $maxRepairs = 0,
    ) {
        if ($this->outputName === '') {
            $this->outputName = 'structured_output';
        }
    }

    public function name(): string
    {
        return 'structured-output';
    }

    public function apply(RunResult $result): void
    {
        $output = $result->output;
        $lastError = null;
        for ($attempt = 0; $attempt <= $this->maxRepairs; $attempt++) {
            try {
                $this->validateOutput($output);
                $result->output = $output;
                return;
            } catch (PraxoException $error) {
                $lastError = $error;
            }
            if ($attempt === $this->maxRepairs || $this->repairer === null) {
                break;
            }
            $repaired = ($this->repairer)($output, $lastError);
            if (trim($repaired) === '') {
                throw PraxoException::structuredOutput(
                    'agent: structured output validation failed: repair returned empty output',
                );
            }
            $output = $repaired;
        }
        throw PraxoException::structuredOutput(
            'agent: structured output validation failed: ' . ($lastError?->getMessage() ?? ''),
        );
    }

    public function beforeModel(ModelCall $call): void
    {
        if ($call->request->responseFormat === null
            && $this->strategy !== self::STRATEGY_TOOL
            && $this->schema !== []) {
            $call->request->responseFormat = ['name' => $this->outputName, 'schema' => $this->schema];
        }
        if ($this->strategy === self::STRATEGY_TOOL) {
            foreach ($call->request->tools as $tool) {
                if ($tool->name === $this->outputName) {
                    $call->request->toolChoice = 'required';
                    break;
                }
            }
        }
    }

    public function afterRun(?RunResult $result, ?PraxoException $error): void
    {
        if ($error === null && $result !== null) {
            $this->apply($result);
        }
    }

    public static function extractJson(string $output): mixed
    {
        $text = trim($output);
        if ($text === '') {
            throw PraxoException::structuredOutput('empty output');
        }
        if (str_starts_with($text, '```')) {
            $newline = strpos($text, "\n");
            if ($newline !== false) {
                $text = substr($text, $newline + 1);
            }
            $text = trim($text, "` \t\n\r\0\x0B");
        }
        $start = strcspn($text, '{[');
        if ($start >= strlen($text)) {
            throw PraxoException::structuredOutput('output does not contain JSON');
        }
        try {
            return Json::decode(substr($text, $start));
        } catch (\JsonException $error) {
            throw PraxoException::structuredOutput('decode JSON: ' . $error->getMessage());
        }
    }

    private function validateOutput(string $output): void
    {
        $data = self::extractJson($output);
        $errors = JsonSchema::validate($this->schema, $data);
        if ($errors !== []) {
            throw PraxoException::structuredOutput('schema: ' . count($errors) . ' error(s)');
        }
    }
}

final class CallLimitMiddleware extends BaseMiddleware
{
    /** @var array<string, array{models: int, tools: int}> */
    private array $counts = [];

    public function __construct(
        private int $modelLimit,
        private int $toolLimit,
    ) {
    }

    public function name(): string
    {
        return 'call-limit';
    }

    public function beforeRun(RunState $state): void
    {
        $this->counts[$state->runId] = ['models' => 0, 'tools' => 0];
    }

    public function beforeModel(ModelCall $call): void
    {
        $count = $this->counts[$call->runId] ?? ['models' => 0, 'tools' => 0];
        $count['models']++;
        $this->counts[$call->runId] = $count;
        if ($this->modelLimit > 0 && $count['models'] > $this->modelLimit) {
            throw PraxoException::modelCallLimit();
        }
    }

    public function beforeTool(MiddlewareToolCall $call): void
    {
        $count = $this->counts[$call->runId] ?? ['models' => 0, 'tools' => 0];
        $count['tools']++;
        $this->counts[$call->runId] = $count;
        if ($this->toolLimit > 0 && $count['tools'] > $this->toolLimit) {
            throw PraxoException::toolCallLimit();
        }
    }

    public function afterRun(?RunResult $result, ?PraxoException $error): void
    {
        if ($result !== null) {
            unset($this->counts[$result->runId]);
        }
    }
}

interface ToolSelector
{
    /**
     * @param list<ToolSpec> $tools
     * @return list<string>
     */
    public function select(string $query, array $tools): array;
}

final class ToolSelectionMiddleware extends BaseMiddleware
{
    /** @var array<string, array<string, true>> */
    private array $selected = [];

    public function __construct(private ToolSelector $selector)
    {
    }

    public function name(): string
    {
        return 'tool-selection';
    }

    public function beforeModel(ModelCall $call): void
    {
        $chosen = [];
        foreach ($this->selector->select(self::lastUserMessage($call->request->messages), $call->request->tools) as $name) {
            $chosen[$name] = true;
        }
        $this->selected[$call->runId] = $chosen;
        $call->request->tools = array_values(array_filter(
            $call->request->tools,
            static fn (ToolSpec $tool): bool => isset($chosen[$tool->name]),
        ));
    }

    public function beforeTool(MiddlewareToolCall $call): void
    {
        if (isset($this->selected[$call->runId]) && !isset($this->selected[$call->runId][$call->call->name])) {
            throw PraxoException::toolNotSelected();
        }
    }

    public function afterRun(?RunResult $result, ?PraxoException $error): void
    {
        if ($result !== null) {
            unset($this->selected[$result->runId]);
        }
    }

    /** @param list<Message> $messages */
    public static function lastUserMessage(array $messages): string
    {
        foreach (array_reverse($messages) as $message) {
            if ($message->role === Roles::USER) {
                return $message->content ?? '';
            }
        }
        return '';
    }
}

final class ModelFallback
{
    public static function fallback(?Model $fallback): callable
    {
        return static function (callable $next) use ($fallback): callable {
            return static function (Request $request) use ($next, $fallback): Response {
                try {
                    return $next($request);
                } catch (PraxoException $primary) {
                    if ($fallback === null) {
                        throw $primary;
                    }
                    try {
                        return $fallback->generate($request);
                    } catch (PraxoException) {
                        throw $primary;
                    }
                }
            };
        };
    }

    public static function fallbackWithContent(string $content): callable
    {
        return self::fallback(new StaticModel($content));
    }
}
