<?php
/**
 * SE-08 API orchestration slice: read two synthetic upstream APIs, validate the
 * mapping, and draft an integration record. No real network calls or writes.
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

final class OrchestrationModel implements Model
{
    public function __construct(private readonly string $customer)
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
                new ToolCall('customer-1', 'read_customer', ['customer' => $this->customer]),
            ]));
        }
        if ($count === 1) {
            return new Response(Message::assistant('', [
                new ToolCall('order-1', 'read_order', ['order' => 'order-100']),
            ]));
        }
        if ($count === 2) {
            $customer = json_decode($results[0]->content ?? '{}', true);
            return new Response(Message::assistant('', [
                new ToolCall('mapping-1', 'draft_integration', [
                    'mapping_id' => 'map-100',
                    'customer' => $customer['customer_id'] ?? 'customer-100',
                    'order' => 'order-100',
                ]),
            ]));
        }
        $customer = json_decode($results[0]->content ?? '{}', true);
        $order = json_decode($results[1]->content ?? '{}', true);
        $mapping = json_decode($results[2]->content ?? '{}', true);
        $report = json_encode([
            'stage' => 'integration_drafted',
            'customer' => $customer,
            'order' => $order,
            'integration' => $mapping,
            'writes' => 0,
        ]);
        return new Response(Message::assistant($report === false ? '{}' : $report));
    }
}

final class OrchestrationPolicy implements PolicyHook
{
    public function authorize(Action $action): Decision
    {
        if ($action->kind === 'model.generate') {
            return Decision::allow('deterministic orchestration');
        }
        if ($action->kind !== 'tool.invoke') {
            return Decision::deny('unsupported action');
        }
        return match ($action->toolName) {
            'read_customer' => ($action->arguments['customer'] ?? null) === 'customer-100'
                ? Decision::allow('only customer-100 is in scope')
                : Decision::deny('customer outside orchestration scope'),
            'read_order' => ($action->arguments['order'] ?? null) === 'order-100'
                ? Decision::allow('only order-100 is in scope')
                : Decision::deny('order outside orchestration scope'),
            'draft_integration' => ($action->arguments['mapping_id'] ?? null) === 'map-100'
                ? Decision::allow('review-only integration draft')
                : Decision::deny('invalid mapping draft'),
            default => Decision::deny('unsupported tool'),
        };
    }
}

final class OrchestrationTutorial
{
    /** @return array{0: ?array<string, mixed>, 1: array{reads: int, drafts: int}, 2: ?Throwable} */
    public static function run(string $customer = 'customer-100', bool $failure = false): array
    {
        $state = ['reads' => 0, 'drafts' => 0];
        $registry = new ToolRegistry();
        $registry->register(new FuncTool('read_customer', 'Read a synthetic CRM record.', static function (array $arguments) use (&$state, $failure): array {
            if (($arguments['customer'] ?? null) !== 'customer-100') {
                throw new RuntimeException('customer not found');
            }
            $state['reads']++;
            if ($failure) {
                throw new RuntimeException('CUSTOMER_API_UNAVAILABLE');
            }
            return ['customer_id' => 'customer-100', 'name' => 'Acme', 'tier' => 'gold', 'source' => 'crm_fixture'];
        }));
        $registry->register(new FuncTool('read_order', 'Read a synthetic ERP order.', static function (array $arguments) use (&$state): array {
            if (($arguments['order'] ?? null) !== 'order-100') {
                throw new RuntimeException('order not found');
            }
            $state['reads']++;
            return ['order_id' => 'order-100', 'customer_id' => 'customer-100', 'total' => 1250.0, 'source' => 'erp_fixture'];
        }));
        $registry->register(new FuncTool('draft_integration', 'Draft an integration mapping; never writes an upstream system.', static function (array $arguments) use (&$state): array {
            $state['drafts']++;
            return [
                'mapping_id' => $arguments['mapping_id'],
                'customer_id' => $arguments['customer'],
                'order_id' => $arguments['order'],
                'status' => 'draft_only',
                'review_required' => true,
                'writes' => 0,
            ];
        }));

        $options = new AgentOptions(new OrchestrationModel($customer));
        $options->tools = $registry;
        $options->allowedTools = ['read_customer', 'read_order', 'draft_integration'];
        $options->policy = new OrchestrationPolicy();
        $options->requirePolicy = true;
        $options->requireToolScope = true;
        $options->maxSteps = 5;

        try {
            $result = (new Agent($options))->run(
                new Session('api-orchestration'),
                'Orchestrate the fixed customer and order APIs into one reviewed mapping.',
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
        if ($error !== null || $state !== ['reads' => 2, 'drafts' => 1]) {
            throw new RuntimeException('success failed: ' . $error?->getMessage());
        }
        if (($report['stage'] ?? null) !== 'integration_drafted'
            || ($report['integration']['status'] ?? null) !== 'draft_only'
            || ($report['writes'] ?? null) !== 0) {
            throw new RuntimeException('unexpected report: ' . json_encode($report));
        }
        if (($report['customer']['customer_id'] ?? null) !== 'customer-100'
            || (float) ($report['order']['total'] ?? 0) !== 1250.0) {
            throw new RuntimeException('wrong upstream mapping: ' . json_encode($report));
        }

        [, $state, $error] = self::run('customer-200');
        if (!$error instanceof PraxoException || $error->praxoCode !== 'AGENT_POLICY_DENIED'
            || $state !== ['reads' => 0, 'drafts' => 0]) {
            throw new RuntimeException('scope denial failed: ' . $error?->getMessage());
        }

        [, $state, $error] = self::run('customer-100', true);
        if ($error === null || $state !== ['reads' => 1, 'drafts' => 0]) {
            throw new RuntimeException('dependency failure failed: ' . $error?->getMessage());
        }

        echo "PHP SE-08 API-orchestration tutorial: success, denial and dependency failure passed\n";
    }
}

if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    if (($argv[1] ?? null) === '--test') {
        OrchestrationTutorial::test();
    } else {
        $customer = 'customer-100';
        $index = array_search('--customer', $argv, true);
        if ($index !== false && isset($argv[$index + 1])) {
            $customer = $argv[$index + 1];
        }
        [$report, $state, $error] = OrchestrationTutorial::run(
            $customer,
            in_array('--simulate-failure', $argv, true),
        );
        if ($error !== null) {
            fwrite(STDERR, "orchestration failed: reads={$state['reads']} drafts={$state['drafts']}; {$error->getMessage()}\n");
            exit(1);
        }
        echo json_encode($report), "\n";
    }
}
