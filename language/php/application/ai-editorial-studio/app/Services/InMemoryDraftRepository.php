<?php

declare(strict_types=1);

namespace App\Services;

use App\Contracts\DraftRepository;
use Praxo\Core\PraxoException;

final class InMemoryDraftRepository implements DraftRepository
{
    /** @var array<string, array<string, mixed>> */
    private array $drafts = [];

    /** @var array<string, array<string, mixed>> */
    private array $reviews = [];

    private int $draftSequence = 0;

    private int $reviewSequence = 0;

    private int $publications = 0;

    public function saveDraft(array $draft): array
    {
        $id = 'draft-'.(++$this->draftSequence);
        $draft['draft_id'] = $id;
        $draft['status'] = 'draft_only';
        $draft['review_required'] = true;
        $this->drafts[$id] = $draft;

        return $draft;
    }

    public function saveTaxonomy(string $draftId, array $taxonomy): array
    {
        if (!isset($this->drafts[$draftId])) {
            throw new PraxoException('TOOL_ERROR', 'draft not found');
        }

        $taxonomy['draft_id'] = $draftId;
        $this->drafts[$draftId]['taxonomy'] = $taxonomy;

        return $taxonomy;
    }

    public function requestReview(string $draftId): array
    {
        if (!isset($this->drafts[$draftId])) {
            throw new PraxoException('TOOL_ERROR', 'draft not found');
        }

        $id = 'review-'.(++$this->reviewSequence);
        $review = [
            'review_id' => $id,
            'draft_id' => $draftId,
            'status' => 'review_requested',
            'review_required' => true,
            'publications_executed' => 0,
        ];
        $this->reviews[$id] = $review;
        $this->drafts[$draftId]['review_id'] = $id;

        return $review;
    }

    public function publish(string $draftId): array
    {
        if (!isset($this->drafts[$draftId])) {
            throw new PraxoException('TOOL_ERROR', 'draft not found');
        }

        $this->publications++;

        return [
            'draft_id' => $draftId,
            'status' => 'published',
            'publications' => $this->publications,
        ];
    }

    public function draftCount(): int
    {
        return count($this->drafts);
    }

    public function reviewCount(): int
    {
        return count($this->reviews);
    }

    public function publicationCount(): int
    {
        return $this->publications;
    }
}
