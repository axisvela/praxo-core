<?php
/** CS-05 retail replenishment: fixed stock, deterministic reorder quantity and a review-only draft. */

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

final class ReplenishmentModel implements Model
{
    public function __construct(private readonly string $store)
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
                new ToolCall('stock-1', 'read_stock', ['store' => $this->store]),
            ]));
        }
        $stock = json_decode($results[0]->content ?? '{}', true);
        if (($stock['reorder_point_breached'] ?? false) !== true) {
            return new Response(Message::assistant(json_encode([
                'stock' => $stock,
                'draft' => null,
                'orders_placed' => 0,
            ]) ?: '{}'));
        }
        if (count($results) === 1) {
            return new Response(Message::assistant('', [
                new ToolCall('order-1', 'draft_order', [
                    'store' => $this->store,
                    'action' => 'replenish',
                ]),
            ]));
        }
        $draft = json_decode($results[count($results) - 1]->content ?? '{}', true);
        return new Response(Message::assistant(json_encode([
            'stock' => $stock,
            'draft' => $draft,
            'orders_placed' => 0,
        ]) ?: '{}'));
    }
}

final class ReplenishmentPolicy implements PolicyHook
{
    public function authorize(Action $action): Decision
    {
        if ($action->kind === 'model.generate') {
            return Decision::allow('deterministic replenishment');
        }
        if ($action->kind !== 'tool.invoke') {
            return Decision::deny('unsupported action');
        }
        if (($action->arguments['store'] ?? null) !== 'store-100') {
            return Decision::deny('only store-100 is in scope');
        }
        return match ($action->toolName) {
            'read_stock' => Decision::allow('fixed stock fixture'),
            'draft_order' => ($action->arguments['action'] ?? null) === 'replenish'
                ? Decision::allow('review-only replenishment draft')
                : Decision::deny('only replenish is allowed'),
            default => Decision::deny('unsupported tool'),
        };
    }
}

final class ReplenishmentTutorial
{
    /** @return array{0:?array<string,mixed>,1:array{reads:int,drafts:int},2:?Throwable} */
    public static function run(string $store = 'store-100', bool $failure = false): array
    {
        $state = ['reads' => 0, 'drafts' => 0];
        $registry = new ToolRegistry();
        $registry->register(new FuncTool('read_stock', 'Read fixed stock and compute reorder quantity.', static function (array $args) use (&$state, $failure): array {
            if (($args['store'] ?? null) !== 'store-100') {
                throw new RuntimeException('store not found');
            }
            $state['reads']++;
            if ($failure) {
                throw new RuntimeException('INVENTORY_UNAVAILABLE');
            }
            $onHand = 10;
            $reorderPoint = 20;
            $target = 50;
            return [
                'store' => 'store-100',
                'sku' => 'sku-100',
                'on_hand' => $onHand,
                'reorder_point' => $reorderPoint,
                'target' => $target,
                'reorder_point_breached' => $onHand < $reorderPoint,
                'reorder_quantity' => max(0, $target - $onHand),
                'source' => 'stock_fixture',
            ];
        }));
        $registry->register(new FuncTool('draft_order', 'Draft a review-only order; no purchase orders.', static function (array $args) use (&$state): array {
            $state['drafts']++;
            return [
                'draft_id' => 'order-100',
                'store' => $args['store'],
                'action' => $args['action'],
                'quantity' => 40,
                'status' => 'draft_only',
                'review_required' => true,
                'orders_placed' => 0,
            ];
        }));

        $options = new AgentOptions(new ReplenishmentModel($store));
        $options->tools = $registry;
        $options->allowedTools = ['read_stock', 'draft_order'];
        $options->policy = new ReplenishmentPolicy();
        $options->requirePolicy = true;
        $options->requireToolScope = true;
        $options->maxSteps = 4;
        try {
            $result = (new Agent($options))->run(
                new Session('retail-replenishment'),
                'Check fixed stock and draft a review-only replenishment order.',
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
        if (($report['stock']['reorder_quantity'] ?? null) !== 40
            || ($report['draft']['status'] ?? null) !== 'draft_only'
            || ($report['orders_placed'] ?? null) !== 0) {
            throw new RuntimeException('unexpected report: ' . json_encode($report));
        }
        [, $state, $error] = self::run('store-200');
        if (!$error instanceof PraxoException || $error->praxoCode !== 'AGENT_POLICY_DENIED'
            || $state !== ['reads' => 0, 'drafts' => 0]) {
            throw new RuntimeException('scope denial failed');
        }
        [, $state, $error] = self::run('store-100', true);
        if ($error === null || $state !== ['reads' => 1, 'drafts' => 0]) {
            throw new RuntimeException('dependency failure failed');
        }
        echo "PHP CS-05 retail-replenishment tutorial: success, denial and dependency failure passed\n";
    }
}

if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    if (($argv[1] ?? null) === '--test') {
        ReplenishmentTutorial::test();
    } else {
        $store = 'store-100';
        $index = array_search('--store', $argv, true);
        if ($index !== false && isset($argv[$index + 1])) {
            $store = $argv[$index + 1];
        }
        [$report, $state, $error] = ReplenishmentTutorial::run($store, in_array('--simulate-failure', $argv, true));
        if ($error !== null) {
            fwrite(STDERR, "retail replenishment failed: reads={$state['reads']} drafts={$state['drafts']}; {$error->getMessage()}\n");
            exit(1);
        }
        echo json_encode($report), "\n";
    }
}
