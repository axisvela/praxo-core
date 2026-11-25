<?php

declare(strict_types=1);

namespace App\Services;

use App\Contracts\ContentIndex;
use App\Contracts\DraftRepository;
use Praxo\Core\Adapters\OpenAICompatible;
use Praxo\Core\Agent;
use Praxo\Core\AgentOptions;
use Praxo\Core\Model;
use Praxo\Core\PraxoException;
use Praxo\Core\Session;
use Praxo\Core\ToolRegistry;

final class EditorialAgent
{
    public function __construct(
        private readonly ContentIndex $index,
        private readonly DraftRepository $drafts,
        private readonly ?Model $model = null,
        private readonly ?string $modelMode = null,
    ) {
    }

    public function review(string $tenantId, string $brief): ReviewResult
    {
        $reads = 0;
        $drafts = 0;
        $reviews = 0;
        $publications = 0;

        $registry = new ToolRegistry();
        $registry->register(new SchemaTool(
            'search_content',
            'Search the application-owned content index; read-only.',
            [
                'type' => 'object',
                'properties' => [
                    'brief' => ['type' => 'string', 'description' => 'Editorial brief'],
                ],
                'required' => ['brief'],
                'additionalProperties' => false,
            ],
            function (array $arguments) use (&$reads): array {
                $reads++;

                return ['sources' => $this->index->search((string) $arguments['brief'])];
            },
        ));
        $registry->register(new SchemaTool(
            'draft_article',
            'Save a model-written draft artifact; no CMS publication.',
            [
                'type' => 'object',
                'properties' => [
                    'brief' => ['type' => 'string'],
                    'title' => ['type' => 'string'],
                    'slug' => ['type' => 'string'],
                    'outline' => [
                        'type' => 'array',
                        'items' => ['type' => 'string'],
                    ],
                    'body' => ['type' => 'string'],
                    'seo_description' => ['type' => 'string'],
                    'rationale' => ['type' => 'string'],
                    'sources' => [
                        'type' => 'array',
                        'items' => ['type' => 'object'],
                    ],
                ],
                'required' => [
                    'brief', 'title', 'slug', 'outline', 'body', 'seo_description',
                    'rationale', 'sources',
                ],
                'additionalProperties' => false,
            ],
            function (array $arguments) use (&$drafts): array {
                if (!is_string($arguments['title'] ?? null) || trim($arguments['title']) === '') {
                    throw new PraxoException('TOOL_ERROR', 'draft title is required');
                }
                if (!is_string($arguments['body'] ?? null) || trim($arguments['body']) === '') {
                    throw new PraxoException('TOOL_ERROR', 'draft body is required');
                }
                if (!is_string($arguments['rationale'] ?? null) || trim($arguments['rationale']) === '') {
                    throw new PraxoException('TOOL_ERROR', 'editorial rationale is required');
                }
                $drafts++;

                return $this->drafts->saveDraft([
                    'brief' => $arguments['brief'],
                    'title' => $arguments['title'],
                    'slug' => $arguments['slug'],
                    'outline' => $arguments['outline'],
                    'body' => $arguments['body'],
                    'seo_description' => $arguments['seo_description'],
                    'rationale' => $arguments['rationale'],
                    'sources' => $arguments['sources'],
                ]);
            },
        ));
        $registry->register(new SchemaTool(
            'suggest_taxonomy',
            'Attach a section and tags to a saved draft; no publication.',
            [
                'type' => 'object',
                'properties' => [
                    'draft_id' => ['type' => 'string'],
                    'section' => ['type' => 'string'],
                    'tags' => [
                        'type' => 'array',
                        'items' => ['type' => 'string'],
                    ],
                ],
                'required' => ['draft_id', 'section', 'tags'],
                'additionalProperties' => false,
            ],
            function (array $arguments): array {
                return $this->drafts->saveTaxonomy(
                    (string) $arguments['draft_id'],
                    [
                        'section' => $arguments['section'],
                        'tags' => $arguments['tags'],
                    ],
                );
            },
        ));
        $registry->register(new SchemaTool(
            'request_publish_review',
            'Create a review-only publication request; never publish.',
            [
                'type' => 'object',
                'properties' => [
                    'draft_id' => ['type' => 'string'],
                    'action' => [
                        'type' => 'string',
                        'enum' => ['publish_review'],
                    ],
                ],
                'required' => ['draft_id', 'action'],
                'additionalProperties' => false,
            ],
            function (array $arguments) use (&$reviews): array {
                if (($arguments['action'] ?? null) !== 'publish_review') {
                    throw new PraxoException('TOOL_ERROR', 'unsupported review action');
                }
                $reviews++;

                return $this->drafts->requestReview((string) $arguments['draft_id']);
            },
        ));
        $registry->register(new SchemaTool(
            'publish_article',
            'Would publish to the CMS. Always denied in the agent path.',
            [
                'type' => 'object',
                'properties' => [
                    'brief' => ['type' => 'string'],
                ],
                'required' => ['brief'],
                'additionalProperties' => false,
            ],
            function (array $arguments) use (&$publications): array {
                $publications++;

                return $this->drafts->publish((string) ($arguments['draft_id'] ?? 'draft-1'));
            },
        ));

        [$model, $modelMode] = $this->selectModel($brief);
        $tracing = new TracingModel($model);
        $options = new AgentOptions($tracing);
        $options->tools = $registry;
        $options->allowedTools = [
            'search_content',
            'draft_article',
            'suggest_taxonomy',
            'request_publish_review',
            'publish_article',
        ];
        $options->policy = new EditorialPolicy(
            $tenantId,
            (string) config('content.tenant', 'acme'),
        );
        $options->requirePolicy = true;
        $options->requireToolScope = true;
        $options->maxSteps = 6;
        $options->maxTokens = 60000;
        $options->modelCallLimit = 6;
        $options->toolCallLimit = 6;
        $options->systemPrompt = 'You are an AI editorial studio for tenant '.$tenantId.'. '
            .'Use search_content, draft_article, suggest_taxonomy, and request_publish_review. '
            .'Draft only; never publish or write to the CMS. '
            .'Return JSON with brief, sources, draft, taxonomy, review, and publications_executed.';

        try {
            $run = (new Agent($options))->run(
                new Session('laravel-ai-editorial-'.$tenantId.'-'.substr(hash('sha256', $brief), 0, 16)),
                $brief,
            );
        } catch (PraxoException $error) {
            throw new ReviewFailure(
                $error->praxoCode,
                $error->getMessage(),
                $reads,
                $drafts,
                $reviews,
                $publications,
            );
        } catch (\Throwable $error) {
            throw new ReviewFailure(
                'AGENT_RUNTIME_ERROR',
                $error->getMessage(),
                $reads,
                $drafts,
                $reviews,
                $publications,
            );
        }

        $report = $this->parseReport($run->output);
        if (!is_array($report)
            || !isset($report['brief'], $report['sources'], $report['draft'], $report['taxonomy'], $report['review'])
            || ($report['publications_executed'] ?? null) !== 0) {
            throw new ReviewFailure(
                'AGENT_INVALID_OUTPUT',
                'agent did not return the required editorial package',
                $reads,
                $drafts,
                $reviews,
                $publications,
            );
        }
        $report = $this->normalizeReport($report, $tracing->steps());
        $report['tenant'] = $tenantId;
        $report['model'] = $modelMode;
        $report['agent_trace'] = $tracing->steps();

        return new ReviewResult($report, $reads, $drafts, $reviews, $publications);
    }

    /**
     * @param array<string, mixed> $report
     * @param list<array<string, mixed>> $steps
     * @return array<string, mixed>
     */
    private function normalizeReport(array $report, array $steps): array
    {
        $payloads = [];
        foreach ($steps as $step) {
            foreach ($step['tool_results'] ?? [] as $result) {
                $decoded = json_decode($result['content'] ?? '', true);
                if (is_array($decoded)) {
                    $payloads[] = $decoded;
                }
            }
        }

        foreach ($payloads as $payload) {
            if (isset($payload['draft_id'], $payload['title'])) {
                $report['draft'] = $payload;
            }
            if (isset($payload['review_id'])) {
                $report['review'] = $payload;
            }
            if (isset($payload['section'], $payload['tags']) && !isset($payload['title'])) {
                $report['taxonomy'] = $payload;
            }
        }

        $report['publications_executed'] = 0;

        return $report;
    }

    private function parseReport(string $output): ?array
    {
        $decoded = json_decode($output, true);
        if (is_array($decoded)) {
            return $decoded;
        }

        if (preg_match('/\{.*\}/s', $output, $matches) === 1) {
            $decoded = json_decode($matches[0], true);
            if (is_array($decoded)) {
                return $decoded;
            }
        }

        return null;
    }

    /** @return array{0: Model, 1: string} */
    private function selectModel(string $brief): array
    {
        if ($this->model !== null) {
            return [$this->model, $this->modelMode ?? 'injected'];
        }

        $baseUrl = (string) config('content.model.base_url', '');
        $name = (string) config('content.model.name', '');
        $apiKey = config('content.model.api_key');

        if ($baseUrl !== '' && $name !== '') {
            return [
                new OpenAICompatible(
                    $baseUrl,
                    $name,
                    is_string($apiKey) && $apiKey !== '' ? $apiKey : null,
                ),
                'live',
            ];
        }

        return [new DeterministicEditorialModel($brief), 'deterministic'];
    }
}
