<?php
/** CS-01 customer support: fixed tickets, deterministic routing and a review-only reply draft. */

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

final class SupportModel implements Model
{
    public function __construct(private readonly string $ticket)
    {
    }

    public function generate(Request $request): Response
    {
        $results = array_values(array_filter(
            $request->messages,
            static fn (Message $m): bool => $m->role === Roles::TOOL,
        ));
        if (count($results) === 0) {
            return new Response(Message::assistant('', [
                new ToolCall('ticket-1', 'read_ticket', ['ticket' => $this->ticket]),
            ]));
        }
        $ticket = json_decode($results[0]->content ?? '{}', true);
        if (($ticket['category'] ?? null) !== 'billing') {
            return new Response(Message::assistant(json_encode([
                'ticket' => $ticket,
                'route' => 'human_queue',
                'draft' => null,
                'refunds_issued' => 0,
            ]) ?: '{}'));
        }
        if (count($results) === 1) {
            return new Response(Message::assistant('', [
                new ToolCall('reply-1', 'draft_reply', [
                    'ticket' => $this->ticket,
                    'action' => 'reply',
                ]),
            ]));
        }
        $draft = json_decode($results[count($results) - 1]->content ?? '{}', true);
        return new Response(Message::assistant(json_encode([
            'ticket' => $ticket,
            'route' => 'billing_review',
            'draft' => $draft,
            'refunds_issued' => 0,
        ]) ?: '{}'));
    }
}

final class SupportPolicy implements PolicyHook
{
    public function authorize(Action $action): Decision
    {
        if ($action->kind === 'model.generate') {
            return Decision::allow('deterministic routing');
        }
        if ($action->kind !== 'tool.invoke') {
            return Decision::deny('unsupported action');
        }
        if (($action->arguments['ticket'] ?? null) !== 'ticket-100') {
            return Decision::deny('only ticket-100 is in scope');
        }
        return match ($action->toolName) {
            'read_ticket' => Decision::allow('fixed ticket fixture'),
            'draft_reply' => ($action->arguments['action'] ?? null) === 'reply'
                ? Decision::allow('review-only reply draft')
                : Decision::deny('only reply is allowed'),
            default => Decision::deny('unsupported tool'),
        };
    }
}

final class SupportTutorial
{
    /** @return array{0:?array<string,mixed>,1:array{reads:int,drafts:int},2:?Throwable} */
    public static function run(string $ticket = 'ticket-100', bool $failure = false): array
    {
        $state = ['reads' => 0, 'drafts' => 0];
        $registry = new ToolRegistry();
        $registry->register(new FuncTool('read_ticket', 'Read one fixed ticket; no CRM call.', static function (array $args) use (&$state, $failure): array {
            if (($args['ticket'] ?? null) !== 'ticket-100') {
                throw new RuntimeException('ticket not found');
            }
            $state['reads']++;
            if ($failure) {
                throw new RuntimeException('CRM_UNAVAILABLE');
            }
            return [
                'ticket' => 'ticket-100',
                'category' => 'billing',
                'priority' => 'high',
                'open_questions' => 1,
                'order_ref' => 'order-100',
                'source' => 'ticket_fixture',
            ];
        }));
        $registry->register(new FuncTool('draft_reply', 'Draft a review-only reply; no refunds or sends.', static function (array $args) use (&$state): array {
            $state['drafts']++;
            return [
                'draft_id' => 'reply-100',
                'ticket' => $args['ticket'],
                'action' => $args['action'],
                'status' => 'draft_only',
                'review_required' => true,
                'refunds_issued' => 0,
            ];
        }));

        $options = new AgentOptions(new SupportModel($ticket));
        $options->tools = $registry;
        $options->allowedTools = ['read_ticket', 'draft_reply'];
        $options->policy = new SupportPolicy();
        $options->requirePolicy = true;
        $options->requireToolScope = true;
        $options->maxSteps = 4;
        try {
            $result = (new Agent($options))->run(
                new Session('customer-support'),
                'Route one fixed ticket and draft a review-only reply.',
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
        if (($report['ticket']['category'] ?? null) !== 'billing'
            || ($report['route'] ?? null) !== 'billing_review'
            || ($report['draft']['status'] ?? null) !== 'draft_only'
            || ($report['refunds_issued'] ?? null) !== 0) {
            throw new RuntimeException('unexpected report: ' . json_encode($report));
        }
        [, $state, $error] = self::run('ticket-200');
        if (!$error instanceof PraxoException || $error->praxoCode !== 'AGENT_POLICY_DENIED'
            || $state !== ['reads' => 0, 'drafts' => 0]) {
            throw new RuntimeException('scope denial failed');
        }
        [, $state, $error] = self::run('ticket-100', true);
        if ($error === null || $state !== ['reads' => 1, 'drafts' => 0]) {
            throw new RuntimeException('dependency failure failed');
        }
        echo "PHP CS-01 customer-support tutorial: success, denial and dependency failure passed\n";
    }
}

if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    if (($argv[1] ?? null) === '--test') {
        SupportTutorial::test();
    } else {
        $ticket = 'ticket-100';
        $index = array_search('--ticket', $argv, true);
        if ($index !== false && isset($argv[$index + 1])) {
            $ticket = $argv[$index + 1];
        }
        [$report, $state, $error] = SupportTutorial::run($ticket, in_array('--simulate-failure', $argv, true));
        if ($error !== null) {
            fwrite(STDERR, "customer support failed: reads={$state['reads']} drafts={$state['drafts']}; {$error->getMessage()}\n");
            exit(1);
        }
        echo json_encode($report), "\n";
    }
}
