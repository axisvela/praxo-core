<?php

declare(strict_types=1);

namespace App\Contracts;

interface DraftRepository
{
    /** @param array<string, mixed> $draft
     *  @return array<string, mixed> */
    public function saveDraft(array $draft): array;

    /** @param array<string, mixed> $taxonomy
     *  @return array<string, mixed> */
    public function saveTaxonomy(string $draftId, array $taxonomy): array;

    /** @return array<string, mixed> */
    public function requestReview(string $draftId): array;

    /** @return array<string, mixed> */
    public function publish(string $draftId): array;

    public function draftCount(): int;

    public function reviewCount(): int;

    public function publicationCount(): int;
}
