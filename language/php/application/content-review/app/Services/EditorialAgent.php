<?php

declare(strict_types=1);

namespace App\Services;

use App\Contracts\ArticleStore;
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
        private readonly ArticleStore $articles,
        private readonly ?Model $model = null,
    ) {
    }

    public function review(string $tenantId, string $articleId): ReviewResult
    {
        $reads = 0;
        $drafts = 0;

        $registry = new ToolRegistry();
        $registry->register(new SchemaTool(
            'read_article',
            'Read one article through the application-owned content store; no publish.',
            [
                'type' => 'object',
                'properties' => [
                    'article' => ['type' => 'string', 'description' => 'Article id'],
                ],
                'required' => ['article'],
                'additionalProperties' => false,
            ],
            function (array $arguments) use ($articleId, &$reads): array {
                if (($arguments['article'] ?? null) !== $articleId) {
                    throw new PraxoException('TOOL_ERROR', 'article argument mismatch');
                }
                $reads++;

                return $this->articles->find($articleId);
            },
        ));
        $registry->register(new SchemaTool(
            'draft_publish',
            'Draft a review-only publication; never publish or update the CMS.',
            [
                'type' => 'object',
                'properties' => [
                    'article' => ['type' => 'string', 'description' => 'Article id'],
                    'action' => [
                        'type' => 'string',
                        'enum' => ['publish_review'],
                    ],
                ],
                'required' => ['article', 'action'],
                'additionalProperties' => false,
            ],
            function (array $arguments) use (&$drafts): array {
                if (($arguments['action'] ?? null) !== 'publish_review') {
                    throw new PraxoException('TOOL_ERROR', 'unsupported editorial action');
                }
                $drafts++;

                return [
                    'draft_id' => 'publish-100',
                    'article' => $arguments['article'],
                    'action' => 'publish_review',
                    'status' => 'draft_only',
                    'review_required' => true,
                    'publications_executed' => 0,
                ];
            },
        ));

        $options = new AgentOptions($this->model ?? $this->selectModel($articleId));
        $options->tools = $registry;
        $options->allowedTools = ['read_article', 'draft_publish'];
        $options->policy = new EditorialPolicy(
            $tenantId,
            (string) config('content.tenant', 'acme'),
        );
        $options->requirePolicy = true;
        $options->requireToolScope = true;
        $options->maxSteps = 4;
        $options->maxTokens = 2000;
        $options->modelCallLimit = 4;
        $options->toolCallLimit = 4;
        $options->systemPrompt = 'Review article '.$articleId.' for tenant '.$tenantId.'. '
            .'Read the article, then draft a publication review with action publish_review. '
            .'Return JSON with tenant, article, review and publications_executed. '
            .'Never publish, update the CMS, or use an external write.';

        try {
            $run = (new Agent($options))->run(
                new Session('laravel-content-'.$tenantId.'-'.$articleId),
                'Review '.$articleId.' for tenant '.$tenantId.'.',
            );
        } catch (PraxoException $error) {
            throw new ReviewFailure($error->praxoCode, $error->getMessage(), $reads, $drafts);
        } catch (\Throwable $error) {
            throw new ReviewFailure('AGENT_RUNTIME_ERROR', $error->getMessage(), $reads, $drafts);
        }

        $report = json_decode($run->output, true);
        if (!is_array($report)
            || !isset($report['article'], $report['review'], $report['publications_executed'])
            || ($report['publications_executed'] ?? null) !== 0) {
            throw new ReviewFailure(
                'AGENT_INVALID_OUTPUT',
                'agent did not return the required editorial review report',
                $reads,
                $drafts,
            );
        }

        return new ReviewResult($report, $reads, $drafts);
    }

    private function selectModel(string $articleId): Model
    {
        $baseUrl = (string) config('content.model.base_url', '');
        $name = (string) config('content.model.name', '');
        $apiKey = config('content.model.api_key');

        if ($baseUrl !== '' && $name !== '') {
            return new OpenAICompatible(
                $baseUrl,
                $name,
                is_string($apiKey) && $apiKey !== '' ? $apiKey : null,
            );
        }

        return new DeterministicEditorialModel($articleId);
    }
}
