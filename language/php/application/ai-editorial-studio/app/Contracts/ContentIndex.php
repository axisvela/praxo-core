<?php

declare(strict_types=1);

namespace App\Contracts;

interface ContentIndex
{
    /** @return list<array<string, mixed>> */
    public function search(string $brief): array;
}
