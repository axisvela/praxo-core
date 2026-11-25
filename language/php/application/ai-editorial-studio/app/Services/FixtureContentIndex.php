<?php

declare(strict_types=1);

namespace App\Services;

use App\Contracts\ContentIndex;
use Praxo\Core\PraxoException;

final class FixtureContentIndex implements ContentIndex
{
    public function search(string $brief): array
    {
        if ((bool) config('content.store_failure', false)) {
            throw new PraxoException('TOOL_ERROR', 'content search unavailable');
        }

        return [
            [
                'id' => 'article-100',
                'title' => 'Q3 service update',
                'section' => 'news',
                'snippet' => 'Previous quarterly service update for existing customers.',
            ],
            [
                'id' => 'article-101',
                'title' => 'Customer onboarding checklist',
                'section' => 'support',
                'snippet' => 'Checklist used when onboarding a new customer account.',
            ],
        ];
    }
}
