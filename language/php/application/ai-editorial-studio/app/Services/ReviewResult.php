<?php

declare(strict_types=1);

namespace App\Services;

final readonly class ReviewResult
{
    /** @param array<string, mixed> $report */
    public function __construct(
        public array $report,
        public int $reads,
        public int $drafts,
        public int $reviews,
        public int $publications,
    ) {
    }

    /** @return array<string, mixed> */
    public function toArray(): array
    {
        return [
            'report' => $this->report,
            'agent' => [
                'reads' => $this->reads,
                'drafts' => $this->drafts,
                'reviews' => $this->reviews,
                'publications' => $this->publications,
            ],
        ];
    }
}
