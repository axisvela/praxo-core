<?php

declare(strict_types=1);

namespace Praxo\Core;

final class Roles
{
    public const SYSTEM = 'system';
    public const USER = 'user';
    public const ASSISTANT = 'assistant';
    public const TOOL = 'tool';
}

final class ContentBlock
{
    public function __construct(
        public string $type = '',
        public ?string $text = null,
        public ?string $imageUrl = null,
        public ?string $data = null,
    ) {
    }

    public function toArray(): array
    {
        $out = ['type' => $this->type];
        if ($this->text !== null) {
            $out['text'] = $this->text;
        }
        if ($this->imageUrl !== null) {
            $out['image_url'] = $this->imageUrl;
        }
        if ($this->data !== null) {
            $out['data'] = $this->data;
        }
        return $out;
    }
}

final class ToolCall
{
    public function __construct(
        public string $id = '',
        public string $name = '',
        public array $arguments = [],
    ) {
    }

    public function toArray(): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'arguments' => $this->arguments === [] ? new \stdClass() : $this->arguments,
        ];
    }
}

final class Message
{
    public function __construct(
        public string $role = '',
        public ?string $content = null,
        public array $contentBlocks = [],
        public array $toolCalls = [],
        public ?string $toolId = null,
    ) {
    }

    public static function text(string $role, string $content): self
    {
        return new self($role, $content);
    }

    public static function assistant(string $content, array $toolCalls = []): self
    {
        return new self(Roles::ASSISTANT, $content, [], $toolCalls);
    }

    public static function tool(string $content, string $toolId): self
    {
        return new self(Roles::TOOL, $content, [], [], $toolId);
    }

    public function toArray(): array
    {
        $out = ['role' => $this->role];
        if ($this->content !== null) {
            $out['content'] = $this->content;
        }
        if ($this->contentBlocks !== []) {
            $out['contentBlocks'] = array_map(
                static fn (ContentBlock $block): array => $block->toArray(),
                $this->contentBlocks,
            );
        }
        if ($this->toolCalls !== []) {
            $out['toolCalls'] = array_map(
                static fn (ToolCall $call): array => $call->toArray(),
                $this->toolCalls,
            );
        }
        if ($this->toolId !== null) {
            $out['toolId'] = $this->toolId;
        }
        return $out;
    }
}

final class ToolSpec
{
    public function __construct(
        public string $name = '',
        public string $description = '',
        public ?array $parameters = null,
        public ?string $risk = null,
    ) {
    }
}

final class Usage
{
    public function __construct(
        public int $inputTokens = 0,
        public int $outputTokens = 0,
        public int $cachedTokens = 0,
    ) {
    }

    public function plus(Usage $other): self
    {
        return new self(
            $this->inputTokens + $other->inputTokens,
            $this->outputTokens + $other->outputTokens,
            $this->cachedTokens + $other->cachedTokens,
        );
    }
}

final class Request
{
    public function __construct(
        public array $messages = [],
        public array $tools = [],
        public ?string $toolChoice = null,
        public ?array $responseFormat = null,
        public float $temperature = 0.0,
    ) {
    }

    public static function of(array $messages): self
    {
        return new self($messages);
    }
}

final class Response
{
    public function __construct(
        public Message $message = new Message(),
        public Usage $usage = new Usage(),
        public ?string $finishReason = null,
    ) {
    }
}

final class Session
{
    public function __construct(
        public string $id,
        public string $tenantId = 'default',
        public string $workspaceId = '',
        public array $messages = [],
    ) {
    }
}

final class RunResult
{
    public function __construct(
        public string $runId = '',
        public string $output = '',
        public int $steps = 0,
        public Usage $usage = new Usage(),
    ) {
    }
}

final class MemoryRecord
{
    public function __construct(
        public string $id = '',
        public string $frame = '',
        public string $content = '',
        public ?array $metadata = null,
        public ?string $createdAt = null,
    ) {
    }
}

final class PathGrant
{
    public function __construct(
        public string $root = '',
        public string $access = 'read',
    ) {
    }
}

final class Action
{
    public function __construct(
        public string $kind = '',
        public string $sessionId = '',
        public ?string $toolName = null,
        public ?array $arguments = null,
    ) {
    }
}

final class Decision
{
    public function __construct(
        public bool $allowed,
        public string $reason = '',
    ) {
    }

    public static function allow(string $reason): self
    {
        return new self(true, $reason);
    }

    public static function deny(string $reason): self
    {
        return new self(false, $reason);
    }
}

final class Event
{
    public function __construct(
        public string $type,
        public string $sessionId,
        public ?string $runId = null,
        public ?array $data = null,
        public ?string $at = null,
    ) {
        $this->at ??= gmdate('Y-m-d\TH:i:s\Z');
    }

    public function withRun(string $runId): self
    {
        $this->runId = $runId;
        return $this;
    }

    public function withData(array $data): self
    {
        $this->data = $data;
        return $this;
    }
}

final class StreamKinds
{
    public const ALL = ['values', 'updates', 'messages', 'tasks', 'debug', 'checkpoint'];
}
