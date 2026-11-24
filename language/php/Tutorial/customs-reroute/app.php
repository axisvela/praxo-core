<?php
/**
 * TL-05 customs reroute slice: validate fixed document fields, compare routes
 * and draft a review-only reroute. No customs filing or network access.
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

final class CustomsModel implements Model
{
    public function __construct(private readonly string $shipment)
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
                new ToolCall('shipment-1', 'read_shipment', ['shipment' => $this->shipment]),
            ]));
        }
        if ($count === 1) {
            return new Response(Message::assistant('', [
                new ToolCall('customs-1', 'draft_customs', [
                    'shipment' => $this->shipment,
                    'action' => 'draft_reroute',
                ]),
            ]));
        }
        $shipment = json_decode($results[0]->content ?? '{}', true);
        $draft = json_decode($results[$count - 1]->content ?? '{}', true);
        $report = json_encode([
            'shipment' => $shipment,
            'draft' => $draft,
            'filings' => 0,
        ]);
        return new Response(Message::assistant($report === false ? '{}' : $report));
    }
}

final class CustomsPolicy implements PolicyHook
{
    public function authorize(Action $action): Decision
    {
        if ($action->kind === 'model.generate') {
            return Decision::allow('deterministic customs review');
        }
        if ($action->kind !== 'tool.invoke') {
            return Decision::deny('unsupported action');
        }
        if (($action->arguments['shipment'] ?? null) !== 'shipment-100') {
            return Decision::deny('only shipment-100 is in scope');
        }
        return match ($action->toolName) {
            'read_shipment' => Decision::allow('read-only shipment fixtures'),
            'draft_customs' => ($action->arguments['action'] ?? null) === 'draft_reroute'
                ? Decision::allow('review-only reroute draft')
                : Decision::deny('only draft_reroute is allowed'),
            default => Decision::deny('unsupported tool'),
        };
    }
}

final class CustomsTutorial
{
    /** @return array{0: ?array<string, mixed>, 1: array{reads: int, drafts: int}, 2: ?Throwable} */
    public static function run(string $shipment = 'shipment-100', bool $failure = false): array
    {
        $state = ['reads' => 0, 'drafts' => 0];
        $registry = new ToolRegistry();
        $registry->register(new FuncTool('read_shipment', 'Validate fixed customs fields; no filing.', static function (array $arguments) use (&$state, $failure): array {
            if (($arguments['shipment'] ?? null) !== 'shipment-100') {
                throw new RuntimeException('shipment not found');
            }
            $state['reads']++;
            if ($failure) {
                throw new RuntimeException('SHIPMENT_INDEX_UNAVAILABLE');
            }
            return [
                'shipment' => 'shipment-100',
                'documents' => 3,
                'missing' => ['certificate-of-origin'],
                'routes' => [
                    ['id' => 'direct', 'days' => 12],
                    ['id' => 'transship', 'days' => 16],
                ],
                'source' => 'shipment_fixture',
            ];
        }));
        $registry->register(new FuncTool('draft_customs', 'Draft a review-only reroute; never files documents.', static function (array $arguments) use (&$state): array {
            $state['drafts']++;
            return [
                'draft_id' => 'customs-100',
                'shipment' => $arguments['shipment'],
                'action' => $arguments['action'],
                'route' => 'transship',
                'status' => 'draft_only',
                'review_required' => true,
                'filings' => 0,
            ];
        }));

        $options = new AgentOptions(new CustomsModel($shipment));
        $options->tools = $registry;
        $options->allowedTools = ['read_shipment', 'draft_customs'];
        $options->policy = new CustomsPolicy();
        $options->requirePolicy = true;
        $options->requireToolScope = true;
        $options->maxSteps = 4;

        try {
            $result = (new Agent($options))->run(
                new Session('customs-reroute'),
                'Validate the fixed shipment and draft a review-only reroute.',
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
        if (($report['shipment']['missing'] ?? null) !== ['certificate-of-origin']
            || ($report['draft']['status'] ?? null) !== 'draft_only'
            || ($report['draft']['route'] ?? null) !== 'transship'
            || ($report['filings'] ?? null) !== 0) {
            throw new RuntimeException('unexpected report: ' . json_encode($report));
        }

        [, $state, $error] = self::run('shipment-200');
        if (!$error instanceof PraxoException || $error->praxoCode !== 'AGENT_POLICY_DENIED'
            || $state !== ['reads' => 0, 'drafts' => 0]) {
            throw new RuntimeException('scope denial failed: ' . $error?->getMessage());
        }

        [, $state, $error] = self::run('shipment-100', true);
        if ($error === null || $state !== ['reads' => 1, 'drafts' => 0]) {
            throw new RuntimeException('dependency failure failed: ' . $error?->getMessage());
        }

        echo "PHP TL-05 customs-reroute tutorial: success, denial and dependency failure passed\n";
    }
}

if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    if (($argv[1] ?? null) === '--test') {
        CustomsTutorial::test();
    } else {
        $shipment = 'shipment-100';
        $index = array_search('--shipment', $argv, true);
        if ($index !== false && isset($argv[$index + 1])) {
            $shipment = $argv[$index + 1];
        }
        [$report, $state, $error] = CustomsTutorial::run(
            $shipment,
            in_array('--simulate-failure', $argv, true),
        );
        if ($error !== null) {
            fwrite(STDERR, "customs reroute failed: reads={$state['reads']} drafts={$state['drafts']}; {$error->getMessage()}\n");
            exit(1);
        }
        echo json_encode($report), "\n";
    }
}
