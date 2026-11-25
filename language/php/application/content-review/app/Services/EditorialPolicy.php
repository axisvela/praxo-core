<?php

declare(strict_types=1);

namespace App\Services;

use Praxo\Core\Action;
use Praxo\Core\Decision;
use Praxo\Core\PolicyHook;

final class EditorialPolicy implements PolicyHook
{
    public function __construct(
        private readonly string $tenantId,
        private readonly string $expectedTenant,
    ) {
    }

    public function authorize(Action $action): Decision
    {
        if ($this->tenantId !== $this->expectedTenant) {
            return Decision::deny('tenant mismatch');
        }

        if ($action->kind === 'model.generate') {
            return Decision::allow('deterministic editorial model');
        }

        if ($action->kind !== 'tool.invoke') {
            return Decision::deny('unsupported action');
        }

        if (($action->arguments['article'] ?? null) !== 'article-100') {
            return Decision::deny('only article-100 is in scope');
        }

        return match ($action->toolName) {
            'read_article' => Decision::allow('fixed article fixture'),
            'draft_publish' => ($action->arguments['action'] ?? null) === 'publish_review'
                ? Decision::allow('review-only publication draft')
                : Decision::deny('only publish_review is allowed'),
            default => Decision::deny('unsupported tool'),
        };
    }
}
