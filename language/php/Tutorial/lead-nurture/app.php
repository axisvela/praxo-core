<?php
/**
 * CS-02 lead nurture slice: rank fixed business profiles and draft opt-in
 * outreach. No crawling, scraping or unsolicited sends.
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

final class LeadModel implements Model
{
    public function __construct(private readonly string $campaign)
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
                new ToolCall('leads-1', 'read_leads', ['campaign' => $this->campaign]),
            ]));
        }
        if ($count === 1) {
            return new Response(Message::assistant('', [
                new ToolCall('outreach-1', 'draft_outreach', [
                    'campaign' => $this->campaign,
                    'action' => 'draft_outreach',
                ]),
            ]));
        }
        $leads = json_decode($results[0]->content ?? '{}', true);
        $outreach = json_decode($results[$count - 1]->content ?? '{}', true);
        $report = json_encode([
            'leads' => $leads,
            'outreach' => $outreach,
            'sends' => 0,
            'crawls' => 0,
        ]);
        return new Response(Message::assistant($report === false ? '{}' : $report));
    }
}

final class LeadPolicy implements PolicyHook
{
    public function authorize(Action $action): Decision
    {
        if ($action->kind === 'model.generate') {
            return Decision::allow('deterministic lead nurture');
        }
        if ($action->kind !== 'tool.invoke') {
            return Decision::deny('unsupported action');
        }
        if (($action->arguments['campaign'] ?? null) !== 'campaign-100') {
            return Decision::deny('only campaign-100 is in scope');
        }
        return match ($action->toolName) {
            'read_leads' => Decision::allow('read-only lead fixtures'),
            'draft_outreach' => ($action->arguments['action'] ?? null) === 'draft_outreach'
                ? Decision::allow('review-only opt-in outreach draft')
                : Decision::deny('only draft_outreach is allowed'),
            default => Decision::deny('unsupported tool'),
        };
    }
}

final class LeadTutorial
{
    /** @return array{0: ?array<string, mixed>, 1: array{reads: int, drafts: int}, 2: ?Throwable} */
    public static function run(string $campaign = 'campaign-100', bool $failure = false): array
    {
        $state = ['reads' => 0, 'drafts' => 0];
        $registry = new ToolRegistry();
        $registry->register(new FuncTool('read_leads', 'Rank fixed synthetic business profiles; no crawling.', static function (array $arguments) use (&$state, $failure): array {
            if (($arguments['campaign'] ?? null) !== 'campaign-100') {
                throw new RuntimeException('campaign not found');
            }
            $state['reads']++;
            if ($failure) {
                throw new RuntimeException('LEAD_INDEX_UNAVAILABLE');
            }
            return [
                'campaign' => 'campaign-100',
                'leads' => 3,
                'ranked' => ['lead-2', 'lead-1'],
                'opt_in' => 1,
                'source' => 'lead_fixture',
            ];
        }));
        $registry->register(new FuncTool('draft_outreach', 'Draft review-only opt-in outreach; never sends.', static function (array $arguments) use (&$state): array {
            $state['drafts']++;
            return [
                'outreach_id' => 'outreach-100',
                'campaign' => $arguments['campaign'],
                'action' => $arguments['action'],
                'lead' => 'lead-2',
                'drafts' => 1,
                'status' => 'draft_only',
                'review_required' => true,
                'sends' => 0,
                'crawls' => 0,
            ];
        }));

        $options = new AgentOptions(new LeadModel($campaign));
        $options->tools = $registry;
        $options->allowedTools = ['read_leads', 'draft_outreach'];
        $options->policy = new LeadPolicy();
        $options->requirePolicy = true;
        $options->requireToolScope = true;
        $options->maxSteps = 4;

        try {
            $result = (new Agent($options))->run(
                new Session('lead-nurture'),
                'Rank fixed leads and draft review-only opt-in outreach.',
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
        if (($report['leads']['ranked'] ?? null) !== ['lead-2', 'lead-1']
            || ($report['leads']['opt_in'] ?? null) !== 1
            || ($report['outreach']['status'] ?? null) !== 'draft_only'
            || ($report['sends'] ?? null) !== 0
            || ($report['crawls'] ?? null) !== 0) {
            throw new RuntimeException('unexpected report: ' . json_encode($report));
        }

        [, $state, $error] = self::run('campaign-200');
        if (!$error instanceof PraxoException || $error->praxoCode !== 'AGENT_POLICY_DENIED'
            || $state !== ['reads' => 0, 'drafts' => 0]) {
            throw new RuntimeException('scope denial failed: ' . $error?->getMessage());
        }

        [, $state, $error] = self::run('campaign-100', true);
        if ($error === null || $state !== ['reads' => 1, 'drafts' => 0]) {
            throw new RuntimeException('dependency failure failed: ' . $error?->getMessage());
        }

        echo "PHP CS-02 lead-nurture tutorial: success, denial and dependency failure passed\n";
    }
}

if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    if (($argv[1] ?? null) === '--test') {
        LeadTutorial::test();
    } else {
        $campaign = 'campaign-100';
        $index = array_search('--campaign', $argv, true);
        if ($index !== false && isset($argv[$index + 1])) {
            $campaign = $argv[$index + 1];
        }
        [$report, $state, $error] = LeadTutorial::run(
            $campaign,
            in_array('--simulate-failure', $argv, true),
        );
        if ($error !== null) {
            fwrite(STDERR, "lead nurture failed: reads={$state['reads']} drafts={$state['drafts']}; {$error->getMessage()}\n");
            exit(1);
        }
        echo json_encode($report), "\n";
    }
}
