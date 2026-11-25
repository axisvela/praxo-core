<?php

declare(strict_types=1);

namespace Tests\Support;

use App\Contracts\ArticleStore;
use Praxo\Core\PraxoException;

final class ArticleStoreSpy implements ArticleStore
{
    public int $reads = 0;

    public function __construct(private readonly bool $fail = false)
    {
    }

    public function find(string $articleId): array
    {
        $this->reads++;

        if ($this->fail) {
            throw new PraxoException('TOOL_ERROR', 'content store unavailable');
        }

        return [
            'article' => 'article-100',
            'tenant' => 'acme',
            'title' => 'Q3 service update',
            'section' => 'news',
            'status' => 'draft',
            'author' => 'editor-100',
            'source' => 'test_spy',
        ];
    }
}
