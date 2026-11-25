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
            return Decision::allow('editorial generation');
        }

        if ($action->kind !== 'tool.invoke') {
            return Decision::deny('unsupported action');
        }

        if ($action->toolName === 'publish_article') {
            return Decision::deny('direct publication requires a separately approved host workflow');
        }

        $brief = $action->arguments['brief'] ?? null;
        if (in_array($action->toolName, ['search_content', 'draft_article'], true)) {
            if (!is_string($brief) || trim($brief) === '') {
                return Decision::deny('brief is required');
            }
            if (strlen($brief) > (int) config('content.brief_max', 500)) {
                return Decision::deny('brief exceeds the configured limit');
            }
        }

        return match ($action->toolName) {
            'search_content' => Decision::allow('read-only content retrieval'),
            'draft_article' => is_array($action->arguments['sources'] ?? null)
                && $action->arguments['sources'] !== []
                && is_string($action->arguments['rationale'] ?? null)
                && trim($action->arguments['rationale']) !== ''
                ? Decision::allow('draft artifact with sources and rationale')
                : Decision::deny('sources and rationale are required'),
            'suggest_taxonomy' => is_string($action->arguments['draft_id'] ?? null)
                && $action->arguments['draft_id'] !== ''
                ? Decision::allow('draft-scoped taxonomy')
                : Decision::deny('draft_id is required'),
            'request_publish_review' => ($action->arguments['action'] ?? null) === 'publish_review'
                ? Decision::allow('review-only publication request')
                : Decision::deny('only publish_review is allowed'),
            default => Decision::deny('unsupported tool'),
        };
    }
}
