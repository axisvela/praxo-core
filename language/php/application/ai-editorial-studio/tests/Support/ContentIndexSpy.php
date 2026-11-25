<?php

declare(strict_types=1);

namespace Tests\Support;

use App\Contracts\ContentIndex;
use Praxo\Core\PraxoException;

final class ContentIndexSpy implements ContentIndex
{
    public int $reads = 0;

    public function __construct(private readonly bool $fail = false)
    {
    }

    public function search(string $brief): array
    {
        $this->reads++;

        if ($this->fail) {
            throw new PraxoException('TOOL_ERROR', 'content search unavailable');
        }

        return [
            [
                'id' => 'article-100',
                'title' => 'Q3 service update',
                'section' => 'news',
                'snippet' => 'Previous quarterly service update for existing customers.',
            ],
        ];
    }
}
