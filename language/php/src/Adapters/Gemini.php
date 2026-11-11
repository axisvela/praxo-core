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
use Praxo\Core\ToolCall;
use Praxo\Core\Usage;

final class Gemini implements Model
{
    /** @param callable(string, array): array|null $transport */
    public function __construct(
        private readonly string $model,
        private readonly ?string $apiKey = null,
        private readonly string $baseUrl = 'https://generativelanguage.googleapis.com',
        private readonly int $maxOutputTokens = 0,
        private $transport = null,
        private readonly int $timeout = 60,
    ) {
    }

    public function generate(Request $request): Response
    {
        if ($this->apiKey === null || $this->apiKey === '') {
            throw new PraxoException('MODEL_CONFIG', 'gemini: API key is required');
        }
        if ($this->model === '') {
            throw new PraxoException('MODEL_CONFIG', 'gemini: model is required');
        }
        $payload = $this->buildPayload($request);
        $path = '/v1beta/models/' . rawurlencode($this->model) . ':generateContent';
        $data = $this->transport !== null
            ? ($this->transport)($path, $payload)
            : $this->post($path, $payload);
        return $this->parseResponse($data);
    }

    private function buildPayload(Request $request): array
    {
        [$system, $contents] = $this->buildContents($request->messages);
        $payload = ['contents' => $contents];
        if ($system !== []) {
            $payload['system_instruction'] = ['parts' => $system];
        }
        if ($request->tools !== []) {
            $payload['tools'] = [[
                'functionDeclarations' => array_map(
                    static fn (\Praxo\Core\ToolSpec $tool): array => [
                        'name' => $tool->name,
                        'description' => $tool->description,
                        'parameters' => $tool->parameters ?? ['type' => 'object', 'properties' => new \stdClass()],
                    ],
                    $request->tools,
                ),
            ]];
            $payload['toolConfig'] = [
                'functionCallingConfig' => [
                    'mode' => $this->toolMode($request->toolChoice),
                ],
            ];
        }
        if (($request->temperature !== 0.0) || $this->maxOutputTokens > 0) {
            $payload['generationConfig'] = [
                'temperature' => $request->temperature,
                'maxOutputTokens' => $this->maxOutputTokens,
            ];
        }
        return $payload;
    }

    /** @return array{0: array, 1: array} */
    private function buildContents(array $messages): array
    {
        $system = [];
        $out = [];
        $pending = [];
        $names = [];
        $flush = function () use (&$out, &$pending): void {
            if ($pending !== []) {
                $out[] = ['role' => 'user', 'parts' => $pending];
                $pending = [];
            }
        };
        foreach ($messages as $message) {
            if ($message->role === Roles::SYSTEM) {
                if ($message->content !== null && $message->content !== '') {
                    $system[] = ['text' => $message->content];
                }
                continue;
            }
            if ($message->role === Roles::TOOL) {
                $name = $names[$message->toolId ?? ''] ?? ($message->toolId ?: 'tool');
                $pending[] = [
                    'functionResponse' => [
                        'name' => $name,
                        'response' => ['result' => $message->content ?? ''],
                    ],
                ];
                continue;
            }
            $flush();
            $parts = $this->messageParts($message);
            if ($parts !== []) {
                $out[] = [
                    'role' => $message->role === Roles::ASSISTANT ? 'model' : 'user',
                    'parts' => $parts,
                ];
            }
            foreach ($message->toolCalls as $call) {
                if ($call->id !== '' && $call->name !== '') {
                    $names[$call->id] = $call->name;
                }
            }
        }
        $flush();
        return [$system, $out];
    }

    private function messageParts(Message $message): array
    {
        $parts = [];
        if ($message->content !== null && $message->content !== '') {
            $parts[] = ['text' => $message->content];
        }
        foreach ($message->contentBlocks as $block) {
            if ($block->type === 'text' && $block->text !== null && $block->text !== '') {
                $parts[] = ['text' => $block->text];
            }
        }
        foreach ($message->toolCalls as $call) {
            $parts[] = [
                'functionCall' => [
                    'name' => $call->name,
                    'args' => $call->arguments === [] ? new \stdClass() : $call->arguments,
                ],
            ];
        }
        return $parts;
    }

    private function toolMode(?string $choice): string
    {
        return match ($choice) {
            'required' => 'ANY',
            'none' => 'NONE',
            default => 'AUTO',
        };
    }

    private function parseResponse(array $data): Response
    {
        if (isset($data['error'])) {
            throw new PraxoException(
                'MODEL_HTTP',
                'gemini: ' . (string) ($data['error']['message'] ?? 'error'),
            );
        }
        $candidate = $data['candidates'][0] ?? null;
        if ($candidate === null) {
            throw new PraxoException('MODEL_HTTP', 'gemini: empty response');
        }
        $content = '';
        $calls = [];
        foreach ($candidate['content']['parts'] ?? [] as $part) {
            if (isset($part['text'])) {
                $content .= (string) $part['text'];
            }
            if (isset($part['functionCall'])) {
                $calls[] = new ToolCall(
                    id: 'call-' . (count($calls) + 1),
                    name: (string) ($part['functionCall']['name'] ?? ''),
                    arguments: is_array($part['functionCall']['args'] ?? null)
                        ? $part['functionCall']['args'] : [],
                );
            }
        }
        $usage = $data['usageMetadata'] ?? [];
        return new Response(
            message: new Message(
                role: Roles::ASSISTANT,
                content: $content,
                toolCalls: $calls,
            ),
            usage: new Usage(
                inputTokens: (int) ($usage['promptTokenCount'] ?? 0),
                outputTokens: (int) ($usage['candidatesTokenCount'] ?? 0),
                cachedTokens: (int) ($usage['cachedContentTokenCount'] ?? 0),
            ),
            finishReason: isset($candidate['finishReason'])
                ? (string) $candidate['finishReason'] : null,
        );
    }

    private function post(string $path, array $payload): array
    {
        $url = rtrim($this->baseUrl, '/') . $path;
        $headers = "Content-Type: application/json\r\n"
            . "x-goog-api-key: {$this->apiKey}\r\n";
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
