<?php
/**
 * CS-07 localization slice: compare fixed localization rules and draft
 * review-only product text. No legal/tax guarantee or publication.
 */

declare(strict_types=1);

$autoload = __DIR__ . '/../../src/autoload.php';
if (!is_file($autoload)) {
    fwrite(STDERR, "PHP Core autoload not found: {$autoload}\n");
    exit(1);
}
require $autoload;

use Praxo\Core\Action;
use Praxo\Core\Agent;
use Praxo\Core\AgentOptions;
use Praxo\Core\Decision;
use Praxo\Core\FuncTool;
use Praxo\Core\Message;
use Praxo\Core\Model;
use Praxo\Core\PolicyHook;
use Praxo\Core\PraxoException;
use Praxo\Core\Request;
use Praxo\Core\Response;
use Praxo\Core\Roles;
use Praxo\Core\Session;
use Praxo\Core\ToolCall;
use Praxo\Core\ToolRegistry;

final class LocalizationModel implements Model
{
    public function __construct(private readonly string $product)
    {
    }

    public function generate(Request $request): Response
    {
        $results = array_values(array_filter(
            $request->messages,
            static fn (Message $message): bool => $message->role === Roles::TOOL,
        ));
        $count = count($results);
        if ($count === 0) {
            return new Response(Message::assistant('', [
                new ToolCall('terms-1', 'read_terms', ['product' => $this->product]),
            ]));
        }
        if ($count === 1) {
            return new Response(Message::assistant('', [
                new ToolCall('draft-1', 'draft_localization', [
                    'product' => $this->product,
                    'action' => 'draft_localized',
                ]),
            ]));
        }
        $terms = json_decode($results[0]->content ?? '{}', true);
        $draft = json_decode($results[$count - 1]->content ?? '{}', true);
        $report = json_encode([
            'stage' => 'localization_drafted',
            'terms' => $terms,
            'draft' => $draft,
            'legal_guarantees' => 0,
            'tax_claims' => 0,
        ]);
        return new Response(Message::assistant($report === false ? '{}' : $report));
    }
}

final class LocalizationPolicy implements PolicyHook
{
    public function authorize(Action $action): Decision
    {
        if ($action->kind === 'model.generate') {
            return Decision::allow('deterministic localization');
        }
        if ($action->kind !== 'tool.invoke') {
            return Decision::deny('unsupported action');
        }
        if (($action->arguments['product'] ?? null) !== 'product-100') {
            return Decision::deny('only product-100 is in scope');
        }
        return match ($action->toolName) {
            'read_terms' => Decision::allow('read-only localization rules'),
            'draft_localization' => ($action->arguments['action'] ?? null) === 'draft_localized'
                ? Decision::allow('review-only localized text')
                : Decision::deny('only draft_localized is allowed'),
            default => Decision::deny('unsupported tool'),
        };
    }
}

final class LocalizationTutorial
{
    /** @return array{0: ?array<string, mixed>, 1: array{reads: int, drafts: int}, 2: ?Throwable} */
    public static function run(string $product = 'product-100', bool $failure = false): array
    {
        $state = ['reads' => 0, 'drafts' => 0];
        $registry = new ToolRegistry();
        $registry->register(new FuncTool('read_terms', 'Read fixed localization rules; no legal advice.', static function (array $arguments) use (&$state, $failure): array {
            if (($arguments['product'] ?? null) !== 'product-100') {
                throw new RuntimeException('product not found');
            }
            $state['reads']++;
            if ($failure) {
                throw new RuntimeException('TERMS_INDEX_UNAVAILABLE');
            }
            return [
                'product' => 'product-100',
                'markets' => ['de'],
                'rules' => ['formal-address', 'unit-cm'],
                'source' => 'terms_fixture',
            ];
        }));
        $registry->register(new FuncTool('draft_localization', 'Draft review-only localized text; no legal or tax guarantee.', static function (array $arguments) use (&$state): array {
            $state['drafts']++;
            return [
                'draft_id' => 'localization-100',
                'product' => $arguments['product'],
                'action' => $arguments['action'],
                'segments' => 2,
                'status' => 'draft_only',
                'review_required' => true,
                'legal_guarantees' => 0,
                'tax_claims' => 0,
            ];
        }));

        $options = new AgentOptions(new LocalizationModel($product));
        $options->tools = $registry;
        $options->allowedTools = ['read_terms', 'draft_localization'];
        $options->policy = new LocalizationPolicy();
        $options->requirePolicy = true;
        $options->requireToolScope = true;
        $options->maxSteps = 4;

        try {
            $result = (new Agent($options))->run(
                new Session('localization-draft'),
                'Compare the fixed rules and draft review-only localized text.',
            );
            $decoded = json_decode($result->output, true);
            return [is_array($decoded) ? $decoded : null, $state, null];
        } catch (Throwable $error) {
            return [null, $state, $error];
        }
    }

    public static function test(): void
    {
        [$report, $state, $error] = self::run();
        if ($error !== null || $state !== ['reads' => 1, 'drafts' => 1]) {
            throw new RuntimeException('success failed: ' . $error?->getMessage());
        }
        if (($report['terms']['markets'] ?? null) !== ['de']
            || ($report['terms']['rules'] ?? null) !== ['formal-address', 'unit-cm']
            || ($report['draft']['status'] ?? null) !== 'draft_only'
            || ($report['draft']['segments'] ?? null) !== 2
            || ($report['legal_guarantees'] ?? null) !== 0
            || ($report['tax_claims'] ?? null) !== 0) {
            throw new RuntimeException('unexpected report: ' . json_encode($report));
        }

        [, $state, $error] = self::run('product-200');
        if (!$error instanceof PraxoException || $error->praxoCode !== 'AGENT_POLICY_DENIED'
            || $state !== ['reads' => 0, 'drafts' => 0]) {
            throw new RuntimeException('scope denial failed: ' . $error?->getMessage());
        }

        [, $state, $error] = self::run('product-100', true);
        if ($error === null || $state !== ['reads' => 1, 'drafts' => 0]) {
            throw new RuntimeException('dependency failure failed: ' . $error?->getMessage());
        }

        echo "PHP CS-07 localization-draft tutorial: success, denial and dependency failure passed\n";
    }
}

if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    if (($argv[1] ?? null) === '--test') {
        LocalizationTutorial::test();
    } else {
        $product = 'product-100';
        $index = array_search('--product', $argv, true);
        if ($index !== false && isset($argv[$index + 1])) {
            $product = $argv[$index + 1];
        }
        [$report, $state, $error] = LocalizationTutorial::run(
            $product,
            in_array('--simulate-failure', $argv, true),
        );
        if ($error !== null) {
            fwrite(STDERR, "localization draft failed: reads={$state['reads']} drafts={$state['drafts']}; {$error->getMessage()}\n");
            exit(1);
        }
        echo json_encode($report), "\n";
    }
}
