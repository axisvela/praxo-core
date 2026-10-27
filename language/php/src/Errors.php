<?php

declare(strict_types=1);

namespace Praxo\Core;

final class PraxoException extends \RuntimeException
{
    public function __construct(
        public readonly string $praxoCode,
        string $message,
    ) {
        parent::__construct($message);
    }

    public static function modelCallLimit(): self
    {
        return new self('AGENT_MODEL_CALL_LIMIT', 'agent: model call limit exceeded');
    }

    public static function toolCallLimit(): self
    {
        return new self('AGENT_TOOL_CALL_LIMIT', 'agent: tool call limit exceeded');
    }

    public static function maxSteps(): self
    {
        return new self('AGENT_MAX_STEPS', 'agent: maximum steps exceeded');
    }

    public static function maxTokens(): self
    {
        return new self('AGENT_MAX_TOKENS', 'agent: token budget exceeded');
    }

    public static function contextBudget(): self
    {
        return new self('AGENT_CONTEXT_BUDGET', 'agent: context budget cannot fit');
    }

    public static function structuredOutput(string $message): self
    {
        return new self('AGENT_STRUCTURED_OUTPUT', $message);
    }

    public static function toolNotSelected(): self
    {
        return new self('AGENT_TOOL_NOT_SELECTED', 'agent: tool is not selected');
    }

    public static function toolNotFound(string $message): self
    {
        return new self('TOOL_NOT_FOUND', $message);
    }

    public static function typeNotAllowed(string $message): self
    {
        return new self('CHECKPOINT_TYPE_NOT_ALLOWED', $message);
    }

    public static function checkpoint(string $message): self
    {
        return new self('CHECKPOINT_ERROR', $message);
    }

    public static function plugin(string $message): self
    {
        return new self('PLUGIN_INVALID_MANIFEST', $message);
    }

    public static function policy(string $message): self
    {
        return new self('POLICY_ERROR', $message);
    }
}
