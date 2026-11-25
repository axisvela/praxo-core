<?php

declare(strict_types=1);

namespace App\Services;

use Praxo\Core\Model;
use Praxo\Core\Request;
use Praxo\Core\Response;

final class TracingModel implements Model
{
    /** @var list<array<string, mixed>> */
    private array $steps = [];

    public function __construct(private readonly Model $inner)
    {
    }

    public function generate(Request $request): Response
    {
        try {
            $response = $this->inner->generate($request);
        } catch (\Throwable $error) {
            $this->steps[] = ['error' => $error->getMessage()];
            throw $error;
        }

        $toolCalls = [];
        $toolResults = [];
        foreach ($request->messages as $message) {
            foreach ($message->toolCalls as $call) {
                $toolCalls[] = [
                    'name' => $call->name,
                    'arguments' => $call->arguments,
                ];
            }
            if ($message->role === 'tool') {
                $toolResults[] = [
                    'tool_id' => $message->toolId,
                    'content' => $message->content ?? '',
                ];
            }
        }

        $outputCalls = [];
        foreach ($response->message->toolCalls as $call) {
            $outputCalls[] = [
                'name' => $call->name,
                'arguments' => $call->arguments,
            ];
        }

        $this->steps[] = [
            'tool_calls' => $toolCalls,
            'tool_results' => $toolResults,
            'model_output' => [
                'content' => $this->truncate($response->message->content ?? ''),
                'tool_calls' => $outputCalls,
            ],
        ];

        return $response;
    }

    /** @return list<array<string, mixed>> */
    public function steps(): array
    {
        return $this->steps;
    }

    private function truncate(string $text, int $max = 800): string
    {
        return strlen($text) > $max ? substr($text, 0, $max).'...' : $text;
    }
}
