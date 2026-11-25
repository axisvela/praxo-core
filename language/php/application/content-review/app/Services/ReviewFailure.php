<?php

declare(strict_types=1);

namespace App\Services;

final class ReviewFailure extends \RuntimeException
{
    public function __construct(
        public readonly string $errorCode,
        string $message,
        public readonly int $reads,
        public readonly int $drafts,
    ) {
        parent::__construct($message);
    }

    /** @return array<string, mixed> */
    public function toArray(): array
    {
        return [
            'error' => $this->errorCode,
            'message' => $this->getMessage(),
            'agent' => [
                'reads' => $this->reads,
                'drafts' => $this->drafts,
            ],
        ];
    }
}
