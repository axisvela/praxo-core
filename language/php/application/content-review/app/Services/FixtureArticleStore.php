<?php

declare(strict_types=1);

namespace App\Services;

use App\Contracts\ArticleStore;
use Praxo\Core\PraxoException;

final class FixtureArticleStore implements ArticleStore
{
    public function find(string $articleId): array
    {
        if ((bool) config('content.store_failure', false)) {
            throw new PraxoException('TOOL_ERROR', 'content store unavailable');
        }

        if ($articleId !== 'article-100') {
            throw new PraxoException('TOOL_ERROR', 'article not found');
        }

        return [
            'article' => 'article-100',
            'tenant' => (string) config('content.tenant', 'acme'),
            'title' => 'Q3 service update',
            'section' => 'news',
            'status' => 'draft',
            'author' => 'editor-100',
            'source' => 'laravel_app_owned_store',
        ];
    }
}
