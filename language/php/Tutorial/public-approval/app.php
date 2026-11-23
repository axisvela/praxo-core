<?php
/**
 * CT-03 cross-agency approval slice: validate a fixed application's documents
 * and draft parallel review tasks. No identity check or official approval.
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

final class ApprovalModel implements Model
{
    public function __construct(private readonly string $application)
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
                new ToolCall('application-1', 'read_application', ['application' => $this->application]),
            ]));
        }
        if ($count === 1) {
            return new Response(Message::assistant('', [
                new ToolCall('tasks-1', 'draft_review_tasks', [
                    'application' => $this->application,
                    'action' => 'parallel_review',
                ]),
            ]));
        }
        $application = json_decode($results[0]->content ?? '{}', true);
        $tasks = json_decode($results[$count - 1]->content ?? '{}', true);
        $report = json_encode([
            'stage' => 'review_tasks_drafted',
            'application' => $application,
            'tasks' => $tasks,
            'approvals' => 0,
        ]);
        return new Response(Message::assistant($report === false ? '{}' : $report));
    }
}

final class ApprovalPolicy implements PolicyHook
{
    public function authorize(Action $action): Decision
    {
        if ($action->kind === 'model.generate') {
            return Decision::allow('deterministic public approval');
        }
        if ($action->kind !== 'tool.invoke') {
            return Decision::deny('unsupported action');
        }
        if (($action->arguments['application'] ?? null) !== 'application-100') {
            return Decision::deny('only application-100 is in scope');
        }
        return match ($action->toolName) {
            'read_application' => Decision::allow('read-only application fixture'),
            'draft_review_tasks' => ($action->arguments['action'] ?? null) === 'parallel_review'
                ? Decision::allow('review-only task draft')
                : Decision::deny('only parallel_review is allowed'),
            default => Decision::deny('unsupported tool'),
        };
    }
}

final class ApprovalTutorial
{
    /** @return array{0: ?array<string, mixed>, 1: array{reads: int, drafts: int}, 2: ?Throwable} */
    public static function run(string $application = 'application-100', bool $failure = false): array
    {
        $state = ['reads' => 0, 'drafts' => 0];
        $registry = new ToolRegistry();
        $registry->register(new FuncTool('read_application', 'Validate a fixed application fixture; no writes.', static function (array $arguments) use (&$state, $failure): array {
            if (($arguments['application'] ?? null) !== 'application-100') {
                throw new RuntimeException('application not found');
            }
            $state['reads']++;
            if ($failure) {
                throw new RuntimeException('REGISTRY_UNAVAILABLE');
            }
            return [
                'application' => 'application-100',
                'documents' => ['id-card' => true, 'proof-of-address' => false, 'income' => true],
                'missing' => ['proof-of-address'],
                'agencies' => ['tax', 'housing'],
                'source' => 'registry_fixture',
            ];
        }));
        $registry->register(new FuncTool('draft_review_tasks', 'Draft review-only parallel agency tasks; never approves.', static function (array $arguments) use (&$state): array {
            $state['drafts']++;
            return [
                'tasks_id' => 'tasks-100',
                'application' => $arguments['application'],
                'action' => $arguments['action'],
                'status' => 'draft_only',
                'review_required' => true,
                'approvals' => 0,
            ];
        }));

        $options = new AgentOptions(new ApprovalModel($application));
        $options->tools = $registry;
        $options->allowedTools = ['read_application', 'draft_review_tasks'];
        $options->policy = new ApprovalPolicy();
        $options->requirePolicy = true;
        $options->requireToolScope = true;
        $options->maxSteps = 4;

        try {
            $result = (new Agent($options))->run(
                new Session('public-approval'),
                'Validate the fixed application and draft parallel review tasks.',
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
        if (($report['stage'] ?? null) !== 'review_tasks_drafted'
            || ($report['application']['missing'] ?? null) !== ['proof-of-address']
            || ($report['tasks']['status'] ?? null) !== 'draft_only'
            || ($report['approvals'] ?? null) !== 0) {
            throw new RuntimeException('unexpected report: ' . json_encode($report));
        }

        [, $state, $error] = self::run('application-200');
        if (!$error instanceof PraxoException || $error->praxoCode !== 'AGENT_POLICY_DENIED'
            || $state !== ['reads' => 0, 'drafts' => 0]) {
            throw new RuntimeException('scope denial failed: ' . $error?->getMessage());
        }

        [, $state, $error] = self::run('application-100', true);
        if ($error === null || $state !== ['reads' => 1, 'drafts' => 0]) {
            throw new RuntimeException('dependency failure failed: ' . $error?->getMessage());
        }

        echo "PHP CT-03 public-approval tutorial: success, denial and dependency failure passed\n";
    }
}

if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    if (($argv[1] ?? null) === '--test') {
        ApprovalTutorial::test();
    } else {
        $application = 'application-100';
        $index = array_search('--application', $argv, true);
        if ($index !== false && isset($argv[$index + 1])) {
            $application = $argv[$index + 1];
        }
        [$report, $state, $error] = ApprovalTutorial::run(
            $application,
            in_array('--simulate-failure', $argv, true),
        );
        if ($error !== null) {
            fwrite(STDERR, "public approval failed: reads={$state['reads']} drafts={$state['drafts']}; {$error->getMessage()}\n");
            exit(1);
        }
        echo json_encode($report), "\n";
    }
}
