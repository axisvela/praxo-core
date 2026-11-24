<?php
/** OP-05 recruiting match: fixed candidates, deterministic ranking and a review-only shortlist. */

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

final class RecruitingModel implements Model
{
    public function __construct(private readonly string $role)
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
                new ToolCall('role-1', 'read_role', ['role' => $this->role]),
            ]));
        }
        $role = json_decode($results[0]->content ?? '{}', true);
        if (count($results) === 1) {
            return new Response(Message::assistant('', [
                new ToolCall('shortlist-1', 'draft_shortlist', [
                    'role' => $this->role,
                    'action' => 'shortlist',
                    'candidate' => $role['ranked'][0] ?? '',
                ]),
            ]));
        }
        $shortlist = json_decode($results[count($results) - 1]->content ?? '{}', true);
        $report = json_encode([
            'role' => $role,
            'shortlist' => $shortlist,
            'outreach_sent' => 0,
        ]);
        return new Response(Message::assistant($report === false ? '{}' : $report));
    }
}

final class RecruitingPolicy implements PolicyHook
{
    public function authorize(Action $action): Decision
    {
        if ($action->kind === 'model.generate') {
            return Decision::allow('deterministic matching');
        }
        if ($action->kind !== 'tool.invoke') {
            return Decision::deny('unsupported action');
        }
        if (($action->arguments['role'] ?? null) !== 'role-100') {
            return Decision::deny('only role-100 is in scope');
        }
        return match ($action->toolName) {
            'read_role' => Decision::allow('fixed candidate fixture'),
            'draft_shortlist' => ($action->arguments['action'] ?? null) === 'shortlist'
                ? Decision::allow('review-only shortlist')
                : Decision::deny('only shortlist is allowed'),
            default => Decision::deny('unsupported tool'),
        };
    }
}

final class RecruitingTutorial
{
    /** @return array{0:?array<string,mixed>,1:array{reads:int,drafts:int},2:?Throwable} */
    public static function run(string $role = 'role-100', bool $failure = false): array
    {
        $state = ['reads' => 0, 'drafts' => 0];
        $registry = new ToolRegistry();
        $registry->register(new FuncTool('read_role', 'Match fixed candidates against one role.', static function (array $args) use (&$state, $failure): array {
            if (($args['role'] ?? null) !== 'role-100') {
                throw new RuntimeException('role not found');
            }
            $state['reads']++;
            if ($failure) {
                throw new RuntimeException('ROLE_SOURCE_UNAVAILABLE');
            }
            $candidates = [
                ['id' => 'cand-1', 'skills' => ['go', 'sql'], 'years' => 5],
                ['id' => 'cand-2', 'skills' => ['python', 'ml'], 'years' => 3],
                ['id' => 'cand-3', 'skills' => ['go', 'sql', 'k8s'], 'years' => 7],
            ];
            $matched = array_values(array_filter($candidates, static function (array $c): bool {
                return empty(array_diff(['go', 'sql'], $c['skills'])) && $c['years'] >= 4;
            }));
            usort($matched, static fn (array $a, array $b): int => [$b['years'], $a['id']] <=> [$a['years'], $b['id']]);
            return [
                'role' => 'role-100',
                'required' => ['go', 'sql'],
                'min_years' => 4,
                'ranked' => array_column($matched, 'id'),
                'matched' => count($matched),
                'source' => 'candidate_fixture',
            ];
        }));
        $registry->register(new FuncTool('draft_shortlist', 'Draft a review-only shortlist; no outreach.', static function (array $args) use (&$state): array {
            $state['drafts']++;
            return [
                'shortlist_id' => 'shortlist-100',
                'role' => $args['role'],
                'candidate' => $args['candidate'],
                'action' => $args['action'],
                'status' => 'draft_only',
                'review_required' => true,
                'outreach_sent' => 0,
            ];
        }));

        $options = new AgentOptions(new RecruitingModel($role));
        $options->tools = $registry;
        $options->allowedTools = ['read_role', 'draft_shortlist'];
        $options->policy = new RecruitingPolicy();
        $options->requirePolicy = true;
        $options->requireToolScope = true;
        $options->maxSteps = 4;
        try {
            $result = (new Agent($options))->run(
                new Session('recruiting-match'),
                'Match fixed candidates and draft a review-only shortlist.',
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
        if (($report['role']['ranked'] ?? null) !== ['cand-3', 'cand-1']
            || ($report['role']['matched'] ?? null) !== 2
            || ($report['shortlist']['status'] ?? null) !== 'draft_only'
            || ($report['outreach_sent'] ?? null) !== 0) {
            throw new RuntimeException('unexpected report: ' . json_encode($report));
        }
        [, $state, $error] = self::run('role-200');
        if (!$error instanceof PraxoException || $error->praxoCode !== 'AGENT_POLICY_DENIED'
            || $state !== ['reads' => 0, 'drafts' => 0]) {
            throw new RuntimeException('scope denial failed');
        }
        [, $state, $error] = self::run('role-100', true);
        if ($error === null || $state !== ['reads' => 1, 'drafts' => 0]) {
            throw new RuntimeException('dependency failure failed');
        }
        echo "PHP OP-05 recruiting-match tutorial: success, denial and dependency failure passed\n";
    }
}

if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    if (($argv[1] ?? null) === '--test') {
        RecruitingTutorial::test();
    } else {
        $role = 'role-100';
        $index = array_search('--role', $argv, true);
        if ($index !== false && isset($argv[$index + 1])) {
            $role = $argv[$index + 1];
        }
        [$report, $state, $error] = RecruitingTutorial::run($role, in_array('--simulate-failure', $argv, true));
        if ($error !== null) {
            fwrite(STDERR, "recruiting failed: reads={$state['reads']} drafts={$state['drafts']}; {$error->getMessage()}\n");
            exit(1);
        }
        echo json_encode($report), "\n";
    }
}
