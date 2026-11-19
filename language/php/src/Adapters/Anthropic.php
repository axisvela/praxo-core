<?php

declare(strict_types=1);

namespace Praxo\Core\Adapters;

use Praxo\Core\Json;
use Praxo\Core\Message;
use Praxo\Core\Model;
use Praxo\Core\PraxoException;
use Praxo\Core\Request;
use Praxo\Core\Response;
use Praxo\Core\Roles;
use Praxo\Core\StreamingModel;
use Praxo\Core\ToolCall;
use Praxo\Core\Usage;

final class Anthropic implements StreamingModel
{
    /** @param callable(string, array): array|null $transport */
    public function __construct(
        private readonly string $model,
        private readonly ?string $apiKey = null,
        private readonly string $baseUrl = 'https://api.anthropic.com',
        private readonly string $version = '2023-06-01',
        private readonly int $maxTokens = 1024,
        private $transport = null,
        private readonly int $timeout = 60,
        private $streamTransport = null,
    ) {
    }

    public function generate(Request $request): Response
    {
        if ($this->apiKey === null || $this->apiKey === '') {
            throw new PraxoException('MODEL_CONFIG', 'anthropic: API key is required');
        }
        if ($this->model === '') {
            throw new PraxoException('MODEL_CONFIG', 'anthropic: model is required');
        }
        $payload = $this->buildPayload($request);
        $data = $this->transport !== null
            ? ($this->transport)('/v1/messages', $payload)
            : $this->post('/v1/messages', $payload);
        return $this->parseResponse($data);
    }

    public function generateStream(Request $request, callable $onDelta): Response
    {
        if ($this->apiKey === null || $this->apiKey === '') {
            throw new PraxoException('MODEL_CONFIG', 'anthropic: API key is required');
        }
        if ($this->model === '') {
            throw new PraxoException('MODEL_CONFIG', 'anthropic: model is required');
        }
        $payload = $this->buildPayload($request, true);
        $text = $this->streamTransport !== null
            ? ($this->streamTransport)('/v1/messages', $payload)
            : $this->postStream('/v1/messages', $payload);
        if (!is_string($text)) {
            throw new PraxoException('PROVIDER_HTTP', 'anthropic: stream transport must return SSE text');
        }
        return $this->parseStream($text, $onDelta);
    }

    private function buildPayload(Request $request, bool $stream = false): array
    {
        [$system, $messages] = $this->buildMessages($request->messages);
        $payload = [
            'model' => $this->model,
            'max_tokens' => $this->maxTokens,
            'messages' => $messages,
        ];
        if ($system !== '') {
            $payload['system'] = $system;
        }
        if ($request->tools !== []) {
            $payload['tools'] = array_map(
                static fn (\Praxo\Core\ToolSpec $tool): array => [
                    'name' => $tool->name,
                    'description' => $tool->description,
                    'input_schema' => $tool->parameters ?? ['type' => 'object', 'properties' => new \stdClass()],
                ],
                $request->tools,
            );
            $choice = $this->toolChoice($request->toolChoice);
            if ($choice !== null) {
                $payload['tool_choice'] = $choice;
            }
        }
        if ($request->temperature !== 0.0) {
            $payload['temperature'] = $request->temperature;
        }
        if ($stream) {
            $payload['stream'] = true;
        }
        return $payload;
    }

    /** @return array{0: string, 1: array} */
    private function buildMessages(array $messages): array
    {
        $system = [];
        $out = [];
        $pending = [];
        $flush = function () use (&$out, &$pending): void {
            if ($pending !== []) {
                $out[] = ['role' => 'user', 'content' => $pending];
                $pending = [];
            }
        };
        foreach ($messages as $message) {
            if ($message->role === Roles::SYSTEM) {
                if ($message->content !== null && $message->content !== '') {
                    $system[] = $message->content;
                }
                continue;
            }
            if ($message->role === Roles::TOOL) {
                $pending[] = [
                    'type' => 'tool_result',
                    'tool_use_id' => $message->toolId ?? '',
                    'content' => $message->content ?? '',
                ];
                continue;
            }
            $flush();
            $content = $this->messageContent($message);
            if ($content !== []) {
                $out[] = ['role' => $message->role, 'content' => $content];
            }
        }
        $flush();
        return [implode("\n\n", $system), $out];
    }

    private function messageContent(Message $message): array
    {
        $content = [];
        if ($message->content !== null && $message->content !== '') {
            $content[] = ['type' => 'text', 'text' => $message->content];
        }
        foreach ($message->contentBlocks as $block) {
            if ($block->type === 'text' && $block->text !== null && $block->text !== '') {
                $content[] = ['type' => 'text', 'text' => $block->text];
            }
        }
        foreach ($message->toolCalls as $call) {
            $content[] = [
                'type' => 'tool_use',
                'id' => $call->id,
                'name' => $call->name,
                'input' => $call->arguments === [] ? new \stdClass() : $call->arguments,
            ];
        }
        return $content;
    }

    private function toolChoice(?string $choice): ?array
    {
        return match ($choice) {
            'auto' => ['type' => 'auto'],
            'required' => ['type' => 'any'],
            'none' => ['type' => 'none'],
            default => null,
        };
    }

    private function parseStream(string $text, callable $onDelta): Response
    {
        $content = '';
        $calls = [];
        $inputTokens = 0;
        $outputTokens = 0;
        $cachedTokens = 0;
        $stopReason = null;
        $stopped = false;
        foreach (preg_split("/\r?\n/", $text) ?: [] as $line) {
            if (!str_starts_with($line, 'data:')) {
                continue;
            }
            $chunk = trim(substr($line, 5));
            if ($chunk === '') {
                continue;
            }
            try {
                $event = Json::decode($chunk);
            } catch (\Throwable) {
                throw new PraxoException('MODEL_STREAM', 'anthropic: invalid stream chunk');
            }
            if (!is_array($event)) {
                continue;
            }
            $type = $event['type'] ?? '';
            if ($type === 'message_start') {
                $usage = $event['message']['usage'] ?? [];
                $inputTokens = (int) ($usage['input_tokens'] ?? 0);
                $cachedTokens = (int) ($usage['cache_read_input_tokens'] ?? 0);
            } elseif ($type === 'content_block_start') {
                $index = (int) ($event['index'] ?? 0);
                $block = $event['content_block'] ?? [];
                if (($block['type'] ?? '') === 'tool_use') {
                    $calls[$index] = [
                        'id' => $block['id'] ?? '',
                        'name' => $block['name'] ?? '',
                        'arguments' => '',
                    ];
                }
            } elseif ($type === 'content_block_delta') {
                $index = (int) ($event['index'] ?? 0);
                $delta = $event['delta'] ?? [];
                $deltaType = $delta['type'] ?? '';
                if ($deltaType === 'text_delta') {
                    $piece = $delta['text'] ?? '';
                    if ($piece !== '') {
                        $content .= $piece;
                        $onDelta($piece);
                    }
                } elseif ($deltaType === 'input_json_delta' && isset($calls[$index])) {
                    $calls[$index]['arguments'] .= $delta['partial_json'] ?? '';
                }
            } elseif ($type === 'message_delta') {
                $stopReason = $event['delta']['stop_reason'] ?? $stopReason;
                $outputTokens = (int) ($event['usage']['output_tokens'] ?? $outputTokens);
            } elseif ($type === 'message_stop') {
                $stopped = true;
            } elseif ($type === 'error') {
                throw new PraxoException('MODEL_STREAM', 'anthropic: stream error');
            }
        }
        if (!$stopped && $stopReason === null) {
            throw new PraxoException('MODEL_STREAM', 'anthropic: stream ended before completion');
        }
        ksort($calls);
        $toolCalls = [];
        foreach ($calls as $call) {
            if (($call['name'] ?? '') === '') {
                continue;
            }
            $arguments = [];
            if (($call['arguments'] ?? '') !== '') {
                try {
                    $arguments = Json::decode($call['arguments']);
                } catch (\Throwable) {
                    throw new PraxoException('PROVIDER_JSON', 'anthropic: invalid tool arguments');
                }
                if (!is_array($arguments)) {
                    throw new PraxoException('PROVIDER_JSON', 'anthropic: invalid tool arguments');
                }
            }
            $toolCalls[] = new ToolCall($call['id'], $call['name'], $arguments);
        }
        return new Response(
            Message::assistant($content, $toolCalls),
            new Usage($inputTokens, $outputTokens, $cachedTokens),
            $stopReason,
        );
    }

    private function parseResponse(array $data): Response
    {
        if (isset($data['error'])) {
            throw new PraxoException(
                'MODEL_HTTP',
                'anthropic: ' . (string) ($data['error']['message'] ?? 'error'),
            );
        }
        $content = '';
        $calls = [];
        foreach ($data['content'] ?? [] as $block) {
            if (($block['type'] ?? '') === 'text') {
                $content .= (string) ($block['text'] ?? '');
            } elseif (($block['type'] ?? '') === 'tool_use') {
                $calls[] = new ToolCall(
                    id: (string) ($block['id'] ?? ''),
                    name: (string) ($block['name'] ?? ''),
                    arguments: is_array($block['input'] ?? null) ? $block['input'] : [],
                );
            }
        }
        $usage = $data['usage'] ?? [];
        return new Response(
            message: new Message(
                role: Roles::ASSISTANT,
                content: $content,
                toolCalls: $calls,
            ),
            usage: new Usage(
                inputTokens: (int) ($usage['input_tokens'] ?? 0),
                outputTokens: (int) ($usage['output_tokens'] ?? 0),
                cachedTokens: (int) ($usage['cache_read_input_tokens'] ?? 0),
            ),
            finishReason: isset($data['stop_reason']) ? (string) $data['stop_reason'] : null,
        );
    }

    private function postStream(string $path, array $payload): string
    {
        $url = rtrim($this->baseUrl, '/') . $path;
        $headers = "Content-Type: application/json\r\nAccept: text/event-stream\r\n";
        $headers .= "x-api-key: {$this->apiKey}\r\n";
        $headers .= "anthropic-version: {$this->version}\r\n";
        $context = stream_context_create([
            'http' => [
                'method' => 'POST',
                'header' => $headers,
                'content' => Json::encode($payload),
                'timeout' => $this->timeout,
                'ignore_errors' => true,
            ],
        ]);
        $body = @file_get_contents($url, false, $context);
        if ($body === false) {
            throw new PraxoException('PROVIDER_HTTP', 'provider request failed');
        }
        $status = $http_response_header[0] ?? '';
        if (!preg_match('/\s2\d\d\s/', $status)) {
            throw new PraxoException('PROVIDER_HTTP', "provider returned {$status}: {$body}");
        }
        return $body;
    }

    private function post(string $path, array $payload): array
    {
        $url = rtrim($this->baseUrl, '/') . $path;
        $headers = "Content-Type: application/json\r\n"
            . "x-api-key: {$this->apiKey}\r\n"
            . "anthropic-version: {$this->version}\r\n";
        $context = stream_context_create([
            'http' => [
                'method' => 'POST',
                'header' => $headers,
                'content' => Json::encode($payload),
                'timeout' => $this->timeout,
                'ignore_errors' => true,
            ],
        ]);
        $body = @file_get_contents($url, false, $context);
        if ($body === false) {
            throw new PraxoException('PROVIDER_HTTP', 'provider request failed');
        }
        $status = $http_response_header[0] ?? '';
        if (!preg_match('/\s2\d\d\s/', $status)) {
            throw new PraxoException('PROVIDER_HTTP', "provider returned {$status}: {$body}");
        }
        return Json::decode($body) ?? [];
    }
}
