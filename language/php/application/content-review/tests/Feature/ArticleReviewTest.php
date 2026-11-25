<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Contracts\ArticleStore;
use Illuminate\Support\Facades\Artisan;
use Tests\Support\ArticleStoreSpy;
use Tests\TestCase;

final class ArticleReviewTest extends TestCase
{
    private function useStore(ArticleStoreSpy $spy): ArticleStoreSpy
    {
        $this->app->instance(ArticleStore::class, $spy);

        return $spy;
    }

    public function test_laravel_route_drafts_editorial_review_without_publishing(): void
    {
        $this->withHeader('X-Tenant-Id', 'acme')
            ->postJson('/api/articles/article-100/review')
            ->assertOk()
            ->assertJsonPath('report.article.section', 'news')
            ->assertJsonPath('report.review.status', 'draft_only')
            ->assertJsonPath('report.review.review_required', true)
            ->assertJsonPath('report.publications_executed', 0)
            ->assertJsonPath('report.review.draft.publications_executed', 0)
            ->assertJsonPath('agent.reads', 1)
            ->assertJsonPath('agent.drafts', 1);
    }

    public function test_missing_tenant_is_rejected_before_the_content_store(): void
    {
        $spy = $this->useStore(new ArticleStoreSpy());

        $this->postJson('/api/articles/article-100/review')
            ->assertStatus(401)
            ->assertJsonPath('error', 'TENANT_REQUIRED');

        self::assertSame(0, $spy->reads);
    }

    public function test_mismatched_tenant_is_rejected_before_the_content_store(): void
    {
        $spy = $this->useStore(new ArticleStoreSpy());

        $this->withHeader('X-Tenant-Id', 'other')
            ->postJson('/api/articles/article-100/review')
            ->assertStatus(403)
            ->assertJsonPath('error', 'TENANT_DENIED');

        self::assertSame(0, $spy->reads);
    }

    public function test_out_of_scope_article_is_policy_denied_before_read(): void
    {
        $spy = $this->useStore(new ArticleStoreSpy());

        $this->withHeader('X-Tenant-Id', 'acme')
            ->postJson('/api/articles/article-200/review')
            ->assertStatus(403)
            ->assertJsonPath('error', 'AGENT_POLICY_DENIED')
            ->assertJsonPath('agent.reads', 0)
            ->assertJsonPath('agent.drafts', 0);

        self::assertSame(0, $spy->reads);
    }

    public function test_content_store_failure_returns_503_without_draft(): void
    {
        $spy = $this->useStore(new ArticleStoreSpy(fail: true));

        $this->withHeader('X-Tenant-Id', 'acme')
            ->postJson('/api/articles/article-100/review')
            ->assertStatus(503)
            ->assertJsonPath('error', 'TOOL_ERROR')
            ->assertJsonPath('agent.reads', 1)
            ->assertJsonPath('agent.drafts', 0);

        self::assertSame(1, $spy->reads);
    }

    public function test_artisan_command_uses_the_same_governed_agent(): void
    {
        $exit = Artisan::call('content:review-article', ['article' => 'article-100']);
        $output = Artisan::output();

        self::assertSame(0, $exit);
        self::assertStringContainsString('draft_only', $output);
        self::assertStringContainsString('"publications_executed": 0', $output);
    }

    public function test_artisan_command_returns_failure_for_dependency_error(): void
    {
        $exit = Artisan::call('content:review-article', [
            'article' => 'article-100',
            '--simulate-failure' => true,
        ]);

        self::assertSame(1, $exit);
        self::assertStringContainsString('TOOL_ERROR', Artisan::output());
    }
}
