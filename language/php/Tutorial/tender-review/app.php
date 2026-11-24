<?php
/**
 * BE-04 tender review slice: validate fixed qualifications and flag document
 * similarities for review. No bid submission or collusion verdict.
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

final class TenderModel implements Model
{
    public function __construct(private readonly string $tender)
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
                new ToolCall('bids-1', 'read_bids', ['tender' => $this->tender]),
            ]));
        }
        if ($count === 1) {
            return new Response(Message::assistant('', [
                new ToolCall('flags-1', 'draft_review', [
                    'tender' => $this->tender,
                    'action' => 'draft_flags',
                ]),
            ]));
        }
        $bids = json_decode($results[0]->content ?? '{}', true);
        $review = json_decode($results[$count - 1]->content ?? '{}', true);
        $report = json_encode([
            'stage' => 'tender_flags_drafted',
            'bids' => $bids,
            'review' => $review,
            'submissions' => 0,
            'collusion_verdicts' => 0,
        ]);
        return new Response(Message::assistant($report === false ? '{}' : $report));
    }
}

final class TenderPolicy implements PolicyHook
{
    public function authorize(Action $action): Decision
    {
        if ($action->kind === 'model.generate') {
            return Decision::allow('deterministic tender review');
        }
        if ($action->kind !== 'tool.invoke') {
            return Decision::deny('unsupported action');
        }
        if (($action->arguments['tender'] ?? null) !== 'tender-100') {
            return Decision::deny('only tender-100 is in scope');
        }
        return match ($action->toolName) {
            'read_bids' => Decision::allow('read-only bid fixtures'),
            'draft_review' => ($action->arguments['action'] ?? null) === 'draft_flags'
                ? Decision::allow('review-only tender flags')
                : Decision::deny('only draft_flags is allowed'),
            default => Decision::deny('unsupported tool'),
        };
    }
}

final class TenderTutorial
{
    /** @return array{0: ?array<string, mixed>, 1: array{reads: int, drafts: int}, 2: ?Throwable} */
    public static function run(string $tender = 'tender-100', bool $failure = false): array
    {
        $state = ['reads' => 0, 'drafts' => 0];
        $registry = new ToolRegistry();
        $registry->register(new FuncTool('read_bids', 'Validate fixed bid qualifications; no submission.', static function (array $arguments) use (&$state, $failure): array {
            if (($arguments['tender'] ?? null) !== 'tender-100') {
                throw new RuntimeException('tender not found');
            }
            $state['reads']++;
            if ($failure) {
                throw new RuntimeException('BID_INDEX_UNAVAILABLE');
            }
            return [
                'tender' => 'tender-100',
                'bids' => 3,
                'qualified' => 2,
                'similar_documents' => 1,
                'source' => 'bid_fixture',
            ];
        }));
        $registry->register(new FuncTool('draft_review', 'Draft review-only flags; never submits a bid.', static function (array $arguments) use (&$state): array {
            $state['drafts']++;
            return [
                'review_id' => 'tender-review-100',
                'tender' => $arguments['tender'],
                'action' => $arguments['action'],
                'flags' => ['shared-document-phrasing', 'missing-certificate'],
                'status' => 'draft_only',
                'review_required' => true,
                'submissions' => 0,
                'collusion_verdicts' => 0,
            ];
        }));

        $options = new AgentOptions(new TenderModel($tender));
        $options->tools = $registry;
        $options->allowedTools = ['read_bids', 'draft_review'];
        $options->policy = new TenderPolicy();
        $options->requirePolicy = true;
        $options->requireToolScope = true;
        $options->maxSteps = 4;

        try {
            $result = (new Agent($options))->run(
                new Session('tender-review'),
                'Validate the fixed bids and draft a review-only flag list.',
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
        if (($report['stage'] ?? null) !== 'tender_flags_drafted'
            || ($report['bids']['qualified'] ?? null) !== 2
            || ($report['bids']['similar_documents'] ?? null) !== 1
            || ($report['review']['status'] ?? null) !== 'draft_only'
            || count($report['review']['flags'] ?? []) !== 2
            || ($report['submissions'] ?? null) !== 0
            || ($report['collusion_verdicts'] ?? null) !== 0) {
            throw new RuntimeException('unexpected report: ' . json_encode($report));
        }

        [, $state, $error] = self::run('tender-200');
        if (!$error instanceof PraxoException || $error->praxoCode !== 'AGENT_POLICY_DENIED'
            || $state !== ['reads' => 0, 'drafts' => 0]) {
            throw new RuntimeException('scope denial failed: ' . $error?->getMessage());
        }

        [, $state, $error] = self::run('tender-100', true);
        if ($error === null || $state !== ['reads' => 1, 'drafts' => 0]) {
            throw new RuntimeException('dependency failure failed: ' . $error?->getMessage());
        }

        echo "PHP BE-04 tender-review tutorial: success, denial and dependency failure passed\n";
    }
}

if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    if (($argv[1] ?? null) === '--test') {
        TenderTutorial::test();
    } else {
        $tender = 'tender-100';
        $index = array_search('--tender', $argv, true);
        if ($index !== false && isset($argv[$index + 1])) {
            $tender = $argv[$index + 1];
        }
        [$report, $state, $error] = TenderTutorial::run(
            $tender,
            in_array('--simulate-failure', $argv, true),
        );
        if ($error !== null) {
            fwrite(STDERR, "tender review failed: reads={$state['reads']} drafts={$state['drafts']}; {$error->getMessage()}\n");
            exit(1);
        }
        echo json_encode($report), "\n";
    }
}
