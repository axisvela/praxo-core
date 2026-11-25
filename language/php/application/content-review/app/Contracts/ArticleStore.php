<?php

declare(strict_types=1);

namespace App\Contracts;

interface ArticleStore
{
    /** @return array<string, mixed> */
    public function find(string $articleId): array;
}
