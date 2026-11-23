<?php
/**
 * OP-01 internal service desk slice: read a fixed employee request, classify
 * risk, and draft a review-only approval. No provisioning or account changes.
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

final class ServiceDeskModel implements Model
{
    public function __construct(private readonly string $employee)
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
                new ToolCall('request-1', 'read_request', ['employee' => $this->employee]),
            ]));
        }
        if ($count === 1) {
            $requestData = json_decode($results[0]->content ?? '{}', true);
            if (isset($requestData['error'])) {
                return new Response(Message::assistant((string) $requestData['error']));
            }
            return new Response(Message::assistant('', [
                new ToolCall('approval-1', 'draft_approval', [
                    'employee' => $this->employee,
                    'action' => 'approve',
                ]),
            ]));
        }
        $requestData = json_decode($results[0]->content ?? '{}', true);
        $approval = json_decode($results[$count - 1]->content ?? '{}', true);
        $report = json_encode([
            'stage' => 'approval_drafted',
            'request' => $requestData,
            'approval' => $approval,
            'provisions' => 0,
        ]);
        return new Response(Message::assistant($report === false ? '{}' : $report));
    }
}

final class ServiceDeskPolicy implements PolicyHook
{
    public function authorize(Action $action): Decision
    {
        if ($action->kind === 'model.generate') {
            return Decision::allow('deterministic service desk');
        }
        if ($action->kind !== 'tool.invoke') {
            return Decision::deny('unsupported action');
        }
        $employee = $action->arguments['employee'] ?? null;
        if ($employee !== 'employee-100') {
            return Decision::deny('only employee-100 is in service scope');
        }
        return match ($action->toolName) {
            'read_request' => Decision::allow('read-only request fixture'),
            'draft_approval' => ($action->arguments['action'] ?? null) === 'approve'
                ? Decision::allow('review-only approval draft')
                : Decision::deny('only an approve draft is allowed'),
            default => Decision::deny('unsupported tool'),
        };
    }
}

final class ServiceDeskTutorial
{
    /** @return array{0: ?array<string, mixed>, 1: array{reads: int, drafts: int}, 2: ?Throwable} */
    public static function run(string $employee = 'employee-100', bool $failure = false): array
    {
        $state = ['reads' => 0, 'drafts' => 0];
        $registry = new ToolRegistry();
        $registry->register(new FuncTool('read_request', 'Read a fixed employee request fixture; no writes.', static function (array $arguments) use (&$state, $failure): array {
            if (($arguments['employee'] ?? null) !== 'employee-100') {
                throw new RuntimeException('employee not found');
            }
            $state['reads']++;
            if ($failure) {
                throw new RuntimeException('REQUEST_SOURCE_UNAVAILABLE');
            }
            return [
                'request_id' => 'req-100',
                'employee' => 'employee-100',
                'type' => 'software_install',
                'target' => 'spreadsheet-tool',
                'risk' => 'low',
                'source' => 'request_fixture',
            ];
        }));
        $registry->register(new FuncTool('draft_approval', 'Draft a review-only approval; never provisions.', static function (array $arguments) use (&$state): array {
            $state['drafts']++;
            return [
                'approval_id' => 'approval-100',
                'employee' => $arguments['employee'],
                'action' => $arguments['action'],
                'status' => 'draft_only',
                'review_required' => true,
                'provisions' => 0,
            ];
        }));

        $options = new AgentOptions(new ServiceDeskModel($employee));
        $options->tools = $registry;
        $options->allowedTools = ['read_request', 'draft_approval'];
        $options->policy = new ServiceDeskPolicy();
        $options->requirePolicy = true;
        $options->requireToolScope = true;
        $options->maxSteps = 4;

        try {
            $result = (new Agent($options))->run(
                new Session('internal-service-desk'),
                'Read the fixed employee request and draft a review-only approval.',
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
        if (($report['stage'] ?? null) !== 'approval_drafted'
            || ($report['request']['risk'] ?? null) !== 'low'
            || ($report['approval']['status'] ?? null) !== 'draft_only'
            || ($report['provisions'] ?? null) !== 0) {
            throw new RuntimeException('unexpected report: ' . json_encode($report));
        }

        [, $state, $error] = self::run('employee-200');
        if (!$error instanceof PraxoException || $error->praxoCode !== 'AGENT_POLICY_DENIED'
            || $state !== ['reads' => 0, 'drafts' => 0]) {
            throw new RuntimeException('scope denial failed: ' . $error?->getMessage());
        }

        [, $state, $error] = self::run('employee-100', true);
        if ($error === null || $state !== ['reads' => 1, 'drafts' => 0]) {
            throw new RuntimeException('dependency failure failed: ' . $error?->getMessage());
        }

        echo "PHP OP-01 internal-service-desk tutorial: success, denial and dependency failure passed\n";
    }
}

if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    if (($argv[1] ?? null) === '--test') {
        ServiceDeskTutorial::test();
    } else {
        $employee = 'employee-100';
        $index = array_search('--employee', $argv, true);
        if ($index !== false && isset($argv[$index + 1])) {
            $employee = $argv[$index + 1];
        }
        [$report, $state, $error] = ServiceDeskTutorial::run(
            $employee,
            in_array('--simulate-failure', $argv, true),
        );
        if ($error !== null) {
            fwrite(STDERR, "service desk failed: reads={$state['reads']} drafts={$state['drafts']}; {$error->getMessage()}\n");
            exit(1);
        }
        echo json_encode($report), "\n";
    }
}
