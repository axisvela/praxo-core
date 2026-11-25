<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Contracts\ContentIndex;
use App\Contracts\DraftRepository;
use App\Services\EditorialAgent;
use App\Services\FixtureContentIndex;
use App\Services\InMemoryDraftRepository;
use App\Services\ReviewFailure;
use Illuminate\Support\Facades\Artisan;
use Praxo\Core\Message;
use Praxo\Core\Model;
use Praxo\Core\Request;
use Praxo\Core\Response;
use Tests\Support\ContentIndexSpy;
use Tests\TestCase;

final class EditorialDraftTest extends TestCase
{
    private function useIndex(ContentIndexSpy $spy): ContentIndexSpy
    {
        $this->app->instance(ContentIndex::class, $spy);

        return $spy;
    }

    private function drafts(): DraftRepository
    {
        return $this->app->make(DraftRepository::class);
    }

    public function test_ai_editorial_studio_generates_review_only_package(): void
    {
        $response = $this->withHeader('X-Tenant-Id', 'acme')
            ->postJson('/api/editorial/drafts', [
                'brief' => 'Write a Q3 service update for the news section.',
            ]);

        $response
            ->assertOk()
            ->assertJsonPath('report.draft.status', 'draft_only')
            ->assertJsonPath('report.draft.title', 'Q3 service update')
            ->assertJsonPath('report.taxonomy.section', 'news')
            ->assertJsonPath('report.review.status', 'review_requested')
            ->assertJsonPath('report.review.review_required', true)
            ->assertJsonPath('report.publications_executed', 0)
            ->assertJsonPath('report.review.publications_executed', 0)
            ->assertJsonPath('agent.reads', 1)
            ->assertJsonPath('agent.drafts', 1)
            ->assertJsonPath('agent.reviews', 1)
            ->assertJsonPath('agent.publications', 0);

        $payload = $response->json();
        self::assertSame('deterministic', $payload['report']['model']);
        self::assertNotEmpty($payload['report']['draft']['rationale']);
        self::assertIsArray($payload['report']['agent_trace']);

        $toolCalls = [];
        foreach ($payload['report']['agent_trace'] as $step) {
            foreach ($step['tool_calls'] ?? [] as $call) {
                $toolCalls[] = $call['name'];
            }
        }
        self::assertContains('search_content', $toolCalls);
        self::assertContains('draft_article', $toolCalls);

        $repository = $this->drafts();
        self::assertSame(1, $repository->draftCount());
        self::assertSame(1, $repository->reviewCount());
        self::assertSame(0, $repository->publicationCount());
    }

    public function test_missing_tenant_is_rejected_before_retrieval(): void
    {
        $spy = $this->useIndex(new ContentIndexSpy());

        $this->postJson('/api/editorial/drafts', ['brief' => 'Write a Q3 service update.'])
            ->assertStatus(401)
            ->assertJsonPath('error', 'TENANT_REQUIRED');

        self::assertSame(0, $spy->reads);
    }

    public function test_mismatched_tenant_is_rejected_before_retrieval(): void
    {
        $spy = $this->useIndex(new ContentIndexSpy());

        $this->withHeader('X-Tenant-Id', 'other')
            ->postJson('/api/editorial/drafts', ['brief' => 'Write a Q3 service update.'])
            ->assertStatus(403)
            ->assertJsonPath('error', 'TENANT_DENIED');

        self::assertSame(0, $spy->reads);
    }

    public function test_direct_publish_brief_is_denied_before_any_effect(): void
    {
        $spy = $this->useIndex(new ContentIndexSpy());

        $this->withHeader('X-Tenant-Id', 'acme')
            ->postJson('/api/editorial/drafts', [
                'brief' => 'Publish immediately: Q3 service update.',
            ])
            ->assertStatus(403)
            ->assertJsonPath('error', 'AGENT_POLICY_DENIED')
            ->assertJsonPath('agent.reads', 0)
            ->assertJsonPath('agent.drafts', 0)
            ->assertJsonPath('agent.reviews', 0)
            ->assertJsonPath('agent.publications', 0);

        self::assertSame(0, $spy->reads);
        self::assertSame(0, $this->drafts()->publicationCount());
    }

    public function test_content_search_failure_returns_503_without_draft(): void
    {
        $spy = $this->useIndex(new ContentIndexSpy(fail: true));

        $this->withHeader('X-Tenant-Id', 'acme')
            ->postJson('/api/editorial/drafts', ['brief' => 'Write a Q3 service update.'])
            ->assertStatus(503)
            ->assertJsonPath('error', 'TOOL_ERROR')
            ->assertJsonPath('agent.reads', 1)
            ->assertJsonPath('agent.drafts', 0)
            ->assertJsonPath('agent.reviews', 0)
            ->assertJsonPath('agent.publications', 0);

        self::assertSame(1, $spy->reads);
        self::assertSame(0, $this->drafts()->draftCount());
    }

    public function test_brief_validation_rejects_missing_input(): void
    {
        $this->withHeader('X-Tenant-Id', 'acme')
            ->postJson('/api/editorial/drafts', [])
            ->assertStatus(422)
            ->assertJsonValidationErrors('brief');
    }

    public function test_artisan_command_generates_the_same_package(): void
    {
        $exit = Artisan::call('content:draft-article', [
            'brief' => 'Write a Q3 service update for the news section.',
        ]);
        $output = Artisan::output();

        self::assertSame(0, $exit);
        self::assertStringContainsString('draft_only', $output);
        self::assertStringContainsString('review_requested', $output);
        self::assertStringContainsString('"publications": 0', $output);
    }

    public function test_artisan_command_rejects_direct_publish_brief(): void
    {
        $exit = Artisan::call('content:draft-article', [
            'brief' => 'Publish immediately: Q3 service update.',
        ]);
        $output = Artisan::output();

        self::assertSame(1, $exit);
        self::assertStringContainsString('AGENT_POLICY_DENIED', $output);
    }

    public function test_invalid_model_output_is_rejected(): void
    {
        $model = new class implements Model {
            public function generate(Request $request): Response
            {
                return new Response(Message::assistant('not-json'));
            }
        };
        $agent = new EditorialAgent(
            new FixtureContentIndex(),
            new InMemoryDraftRepository(),
            $model,
        );

        try {
            $agent->review('acme', 'Write a Q3 service update.');
            self::fail('expected invalid output to be rejected');
        } catch (ReviewFailure $failure) {
            self::assertSame('AGENT_INVALID_OUTPUT', $failure->errorCode);
            self::assertSame(0, $failure->reads);
            self::assertSame(0, $failure->drafts);
            self::assertSame(0, $failure->reviews);
            self::assertSame(0, $failure->publications);
        }
    }
}
