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

final class OpenAICompatible implements Model
{
    /**
     * @param callable(string, array): array|null $transport
     */
    public function __construct(
        private readonly string $baseUrl,
        private readonly string $model,
        private readonly ?string $apiKey = null,
        private $transport = null,
        private readonly int $timeout = 60,
    ) {
    }

    public function generate(Request $request): Response
    {
        $payload = $this->buildPayload($request);
        $data = $this->transport !== null
            ? ($this->transport)('/chat/completions', $payload)
            : $this->post('/chat/completions', $payload);
        return $this->parseResponse($data);
    }

    private function buildPayload(Request $request): array
    {
        $payload = [
            'model' => $this->model,
            'messages' => array_map(fn (Message $message): array => $this->messagePayload($message), $request->messages),
        ];
        $tools = array_map(
            static fn (\Praxo\Core\ToolSpec $tool): array => [
                'type' => 'function',
                'function' => [
                    'name' => $tool->name,
                    'description' => $tool->description,
                    'parameters' => $tool->parameters ?? ['type' => 'object'],
                ],
            ],
            $request->tools,
        );
        if ($tools !== []) {
            $payload['tools'] = $tools;
        }
        if ($request->toolChoice !== null) {
            $payload['tool_choice'] = $request->toolChoice;
        }
        if ($request->temperature !== 0.0) {
            $payload['temperature'] = $request->temperature;
        }
        if ($request->responseFormat !== null) {
            $payload['response_format'] = $request->responseFormat;
        }
        return $payload;
    }

    private function messagePayload(Message $message): array
    {
        $content = $message->content;
        if (($content === null || $content === '') && $message->contentBlocks !== []) {
            $parts = [];
            foreach ($message->contentBlocks as $block) {
                if ($block->type === 'text' && $block->text !== null) {
                    $parts[] = $block->text;
                }
            }
            $content = implode('', $parts);
        }
        $out = ['role' => $message->role, 'content' => $content];
        if ($message->role === Roles::ASSISTANT && $message->toolCalls !== []) {
            $out['tool_calls'] = array_map(
                static fn (ToolCall $call): array => [
                    'id' => $call->id,
                    'type' => 'function',
                    'function' => [
                        'name' => $call->name,
                        'arguments' => Json::encode($call->arguments === [] ? new \stdClass() : $call->arguments),
                    ],
                ],
                $message->toolCalls,
            );
        }
        if ($message->role === Roles::TOOL && $message->toolId !== null) {
            $out['tool_call_id'] = $message->toolId;
        }
        return $out;
    }

    private function parseResponse(array $data): Response
    {
        $choice = $data['choices'][0] ?? [];
        $message = $choice['message'] ?? [];
        $toolCalls = [];
        foreach ($message['tool_calls'] ?? [] as $call) {
            $function = $call['function'] ?? [];
            $arguments = $function['arguments'] ?? [];
            if (is_string($arguments) && $arguments !== '') {
                $arguments = Json::decode($arguments);
            }
            $toolCalls[] = new ToolCall(
                id: $call['id'] ?? '',
                name: $function['name'] ?? '',
                arguments: is_array($arguments) ? $arguments : [],
            );
        }
        $usage = $data['usage'] ?? [];
        return new Response(
            message: new Message(
                role: Roles::ASSISTANT,
                content: $message['content'] ?? null,
                toolCalls: $toolCalls,
            ),
            usage: new Usage(
                inputTokens: (int) ($usage['prompt_tokens'] ?? 0),
                outputTokens: (int) ($usage['completion_tokens'] ?? 0),
            ),
            finishReason: $choice['finish_reason'] ?? null,
        );
    }

    private function post(string $path, array $payload): array
    {
        $url = rtrim($this->baseUrl, '/') . $path;
        $headers = "Content-Type: application/json\r\n";
        if ($this->apiKey !== null) {
            $headers .= "Authorization: Bearer {$this->apiKey}\r\n";
        }
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
