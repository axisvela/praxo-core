<?php

declare(strict_types=1);

namespace App\Services;

use Praxo\Core\Message;
use Praxo\Core\Model;
use Praxo\Core\Request;
use Praxo\Core\Response;
use Praxo\Core\Roles;
use Praxo\Core\ToolCall;

final class DeterministicEditorialModel implements Model
{
    public function __construct(private readonly string $articleId)
    {
    }

    public function generate(Request $request): Response
    {
        $toolMessages = array_values(array_filter(
            $request->messages,
            static fn (Message $message): bool => $message->role === Roles::TOOL,
        ));

        if ($toolMessages === []) {
            return new Response(Message::assistant('', [
                new ToolCall('read-1', 'read_article', ['article' => $this->articleId]),
            ]));
        }

        if (count($toolMessages) === 1) {
            return new Response(Message::assistant('', [
                new ToolCall('draft-1', 'draft_publish', [
                    'article' => $this->articleId,
                    'action' => 'publish_review',
                ]),
            ]));
        }

        $article = json_decode($toolMessages[0]->content ?? '{}', true) ?: [];
        $draft = json_decode($toolMessages[count($toolMessages) - 1]->content ?? '{}', true) ?: [];

        $report = [
            'tenant' => $article['tenant'] ?? null,
            'article' => $article,
            'review' => [
                'status' => 'draft_only',
                'reason' => 'editorial_review_required',
                'draft' => $draft,
                'review_required' => true,
            ],
            'publications_executed' => 0,
        ];

        return new Response(Message::assistant(
            (string) json_encode($report, JSON_UNESCAPED_SLASHES),
        ));
    }
}
