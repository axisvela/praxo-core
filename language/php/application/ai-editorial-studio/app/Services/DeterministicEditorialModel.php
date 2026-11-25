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
    public function __construct(private readonly string $brief)
    {
    }

    public function generate(Request $request): Response
    {
        $toolMessages = array_values(array_filter(
            $request->messages,
            static fn (Message $message): bool => $message->role === Roles::TOOL,
        ));

        if ($toolMessages === []) {
            if (stripos($this->brief, 'publish immediately') !== false) {
                return new Response(Message::assistant('', [
                    new ToolCall('publish-1', 'publish_article', ['brief' => $this->brief]),
                ]));
            }

            return new Response(Message::assistant('', [
                new ToolCall('search-1', 'search_content', ['brief' => $this->brief]),
            ]));
        }

        if (count($toolMessages) === 1) {
            $search = json_decode($toolMessages[0]->content ?? '{}', true) ?: [];
            $sources = is_array($search['sources'] ?? null) ? $search['sources'] : [];
            $title = stripos($this->brief, 'q3') !== false ? 'Q3 service update' : 'Editorial draft';

            return new Response(Message::assistant('', [
                new ToolCall('draft-1', 'draft_article', [
                    'brief' => $this->brief,
                    'title' => $title,
                    'slug' => 'q3-service-update',
                    'outline' => [
                        'Context for existing customers',
                        'What changed this quarter',
                        'Next steps and support contact',
                    ],
                    'body' => 'Draft generated from the brief: '.$this->brief,
                    'seo_description' => 'A Q3 service update for existing customers.',
                    'rationale' => 'Lead with customer impact, then explain the Q3 changes and next steps.',
                    'sources' => $sources,
                ]),
            ]));
        }

        $draft = json_decode($toolMessages[1]->content ?? '{}', true) ?: [];
        $draftId = is_string($draft['draft_id'] ?? null) ? $draft['draft_id'] : '';

        if (count($toolMessages) === 2) {
            return new Response(Message::assistant('', [
                new ToolCall('taxonomy-1', 'suggest_taxonomy', [
                    'draft_id' => $draftId,
                    'section' => 'news',
                    'tags' => ['service-update', 'q3', 'customer-communication'],
                ]),
            ]));
        }

        if (count($toolMessages) === 3) {
            return new Response(Message::assistant('', [
                new ToolCall('review-1', 'request_publish_review', [
                    'draft_id' => $draftId,
                    'action' => 'publish_review',
                ]),
            ]));
        }

        $search = json_decode($toolMessages[0]->content ?? '{}', true) ?: [];
        $taxonomy = json_decode($toolMessages[2]->content ?? '{}', true) ?: [];
        $review = json_decode($toolMessages[3]->content ?? '{}', true) ?: [];

        $report = [
            'brief' => $this->brief,
            'sources' => is_array($search['sources'] ?? null) ? $search['sources'] : [],
            'draft' => $draft,
            'taxonomy' => $taxonomy,
            'review' => $review,
            'publications_executed' => 0,
        ];

        return new Response(Message::assistant(
            (string) json_encode($report, JSON_UNESCAPED_SLASHES),
        ));
    }
}
