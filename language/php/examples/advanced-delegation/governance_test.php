<?php

declare(strict_types=1);
require __DIR__ . '/../../src/autoload.php';

use Praxo\Core\Action;
use Praxo\Core\Agent;
use Praxo\Core\AgentOptions;
use Praxo\Core\BaseMiddleware;
use Praxo\Core\Decision;
use Praxo\Core\MiddlewareToolCall;
use Praxo\Core\Model;
use Praxo\Core\PolicyHook;
use Praxo\Core\PraxoException;
use Praxo\Core\Request;
use Praxo\Core\Response;
use Praxo\Core\Message;
use Praxo\Core\Roles;
use Praxo\Core\RunResult;
use Praxo\Core\Session;
use Praxo\Core\Tool;
use Praxo\Core\ToolCall;
use Praxo\Core\ToolRegistry;
final class BudgetExhausted extends \RuntimeException
{
}

final class DelegationError extends \RuntimeException
{
}
final class SharedBudget
{
    public function __construct(public int $remaining)
    {
    }

    public function available(): bool
    {
        return $this->remaining > 0;
    }
    public function take(): bool
    {
        if ($this->remaining <= 0) {
            return false;
        }
        $this->remaining--;
        return true;
    }
}

final class FuncPolicy implements PolicyHook
{
    private \Closure $function;
    public function __construct(callable $function)
    {
        $this->function = \Closure::fromCallable($function);
    }

    public function authorize(Action $action): Decision
    {
        return ($this->function)($action);
    }
}
final class ComposedPolicy implements PolicyHook
{
    /** @var list<PolicyHook> */
    private array $hooks;

    public function __construct(?PolicyHook ...$hooks)
    {
        $this->hooks = array_values(array_filter(
            $hooks,
            static fn (?PolicyHook $hook): bool => $hook !== null,
        ));
    }
    public function authorize(Action $action): Decision
    {
        foreach ($this->hooks as $hook) {
            $decision = $hook->authorize($action);
            if (!$decision->allowed) {
                return $decision;
            }
        }
        return Decision::allow('delegation policy chain allowed');
    }
}

final class BudgetedTool implements Tool
{
    public ?array $parameters;
    public ?string $risk;
    public function __construct(
        private readonly Tool $inner,
        private readonly SharedBudget $budget,
    ) {
        $this->parameters = property_exists($inner, 'parameters') ? $inner->parameters : null;
        $this->risk = property_exists($inner, 'risk') ? $inner->risk : null;
    }

    public function name(): string
    {
        return $this->inner->name();
    }
    public function description(): string
    {
        return $this->inner->description();
    }

    public function invoke(array $arguments): mixed
    {
        if (!$this->budget->take()) {
            throw new BudgetExhausted('delegation budget exhausted');
        }
        return $this->inner->invoke($arguments);
    }
}
final class Authority
{
    public function __construct(
        public array $allowed,
        public array $delegable,
        public int $maxDepth,
        public int $maxChildren,
        public int $depth = 0,
        public ?SharedBudget $budget = null,
        public ?PolicyHook $policy = null,
    ) {
        $this->budget ??= new SharedBudget(1);
    }
}

final class ChildScope
{
    public function __construct(
        public Authority $authority,
        public \Closure $release,
    ) {
    }
    public function release(): void
    {
        ($this->release)();
    }

    public function run(
        Model $model,
        ToolRegistry $tools,
        string $prompt,
        array $options = [],
    ): RunResult {
        $names = $this->authority->allowed;
        sort($names);
        $scoped = new ToolRegistry();
        foreach ($names as $name) {
            $scoped->register(new BudgetedTool(
                $tools->get($name),
                $this->authority->budget,
            ));
        }
        $agentOptions = new AgentOptions($model);
        $agentOptions->tools = $scoped;
        $agentOptions->maxSteps = 3;
        $agentOptions->allowedTools = $names;
        $agentOptions->policy = $this->authority->policy;
        $agentOptions->middleware = $options['middleware'] ?? [];
        $agentOptions->cancellation = $options['cancellation'] ?? null;
        $agentOptions->requirePolicy = true;
        $agentOptions->requireToolScope = true;
        return (new Agent($agentOptions))->run(
            new Session('governed-delegation-child'),
            $prompt,
        );
    }
}
final class Governor
{
    private int $active = 0;

    public function __construct(private readonly Authority $authority)
    {
    }
    public function delegate(
        array $allowed,
        ?array $delegable = null,
        ?PolicyHook $policy = null,
    ): ChildScope {
        $delegable ??= [];
        if ($this->authority->depth + 1 > $this->authority->maxDepth) {
            throw new DelegationError('delegation depth exceeded');
        }
        if ($allowed === []) {
            throw new DelegationError('delegation tool scope is empty');
        }
        foreach ($allowed as $name) {
            if (!in_array($name, $this->authority->delegable, true)
                || !in_array($name, $this->authority->allowed, true)) {
                throw new DelegationError('delegation scope exceeds parent');
            }
        }
        foreach ($delegable as $name) {
            if (!in_array($name, $this->authority->delegable, true)) {
                throw new DelegationError('child delegable scope exceeds parent');
            }
        }
        if (!$this->authority->budget->available()) {
            throw new BudgetExhausted('delegation budget exhausted');
        }
        if ($this->active >= $this->authority->maxChildren) {
            throw new DelegationError('delegation child limit exceeded');
        }
        $this->active++;
        $released = false;
        $release = function () use (&$released): void {
            if ($released) {
                return;
            }
            $released = true;
            $this->active--;
        };
        $child = new Authority(
            allowed: $allowed,
            delegable: $delegable,
            maxDepth: $this->authority->maxDepth,
            maxChildren: $this->authority->maxChildren,
            depth: $this->authority->depth + 1,
            budget: $this->authority->budget,
            policy: new ComposedPolicy($this->authority->policy, $policy),
        );
        return new ChildScope($child, $release);
    }
}

final class FixtureModel implements Model
{
    public int $calls = 0;
    public function __construct(
        private readonly string $toolName,
        private readonly array $arguments,
        private readonly string $final,
        private readonly mixed $onGenerate = null,
    ) {
    }

    public function generate(Request $request): Response
    {
        $this->calls++;
        if ($this->onGenerate !== null) {
            ($this->onGenerate)();
        }
        $last = $request->messages[count($request->messages) - 1];
        if ($last->role === Roles::TOOL) {
            return new Response(Message::assistant($this->final));
        }
        return new Response(Message::assistant('', [
            new ToolCall('call-1', $this->toolName, $this->arguments),
        ]));
    }
}
final class RecordTool implements Tool
{
    public int $calls = 0;

    public array $parameters = [
        'type' => 'object',
        'required' => ['target'],
        'properties' => ['target' => ['type' => 'string']],
    ];
    public string $risk = 'write';

    public function name(): string
    {
        return 'record';
    }
    public function description(): string
    {
        return 'Record a delegated effect.';
    }

    public function invoke(array $arguments): mixed
    {
        $this->calls++;
        return 'recorded:' . (string) ($arguments['target'] ?? '');
    }
}
final class ParentOnlyTool implements Tool
{
    public int $calls = 0;

    public function name(): string
    {
        return 'parent_only';
    }
    public function description(): string
    {
        return 'A tool that must remain outside the child scope.';
    }

    public function invoke(array $arguments): mixed
    {
        $this->calls++;
        return 'parent-effect';
    }
}
final class MutatingMiddleware extends BaseMiddleware
{
    public function beforeTool(MiddlewareToolCall $call): void
    {
        $call->call->arguments['target'] = 'blocked';
    }
}

function allowAll(Action $action): Decision
{
    return Decision::allow('root');
}
function recordPolicy(Action $action): Decision
{
    if ($action->kind !== 'tool.invoke') {
        return Decision::allow('non-tool action');
    }
    if ($action->toolName !== 'record') {
        return Decision::deny('child may only record');
    }
    if (($action->arguments['target'] ?? '') === 'blocked') {
        return Decision::deny('blocked target');
    }
    return Decision::allow('record allowed');
}

function check(bool $condition, string $message): void
{
    if (!$condition) {
        throw new \RuntimeException($message);
    }
}
function expectError(string $class, callable $function, string $message): \Throwable
{
    try {
        $function();
    } catch (\Throwable $error) {
        if ($error instanceof $class) {
            return $error;
        }
        throw $error;
    }
    throw new \RuntimeException($message);
}

$passed = 0;
$record = new RecordTool();
$parentOnly = new ParentOnlyTool();
$tools = new ToolRegistry();
$tools->register($record);
$tools->register($parentOnly);
$root = new Governor(new Authority(
    allowed: ['record', 'parent_only'],
    delegable: ['record'],
    maxDepth: 1,
    maxChildren: 2,
    budget: new SharedBudget(2),
    policy: new FuncPolicy(allowAll(...)),
));
expectError(
    DelegationError::class,
    static fn () => $root->delegate(['parent_only']),
    'scope escalation was not rejected',
);
check($record->calls === 0 && $parentOnly->calls === 0, 'scope escalation produced effects');
$root->delegate(['record'], null, new FuncPolicy(recordPolicy(...)))->release();
$passed++;

$depthRoot = new Governor(new Authority(
    allowed: ['record'],
    delegable: ['record'],
    maxDepth: 1,
    maxChildren: 1,
    budget: new SharedBudget(2),
    policy: new FuncPolicy(allowAll(...)),
));
$depthChild = $depthRoot->delegate(['record'], null, new FuncPolicy(recordPolicy(...)));
expectError(
    DelegationError::class,
    static fn () => (new Governor($depthChild->authority))->delegate(['record']),
    'grandchild depth was not rejected',
);
$depthChild->release();
$passed++;
$childLimit = new Governor(new Authority(
    allowed: ['record'],
    delegable: ['record'],
    maxDepth: 1,
    maxChildren: 1,
    budget: new SharedBudget(2),
    policy: new FuncPolicy(allowAll(...)),
));
$firstChild = $childLimit->delegate(['record'], null, new FuncPolicy(recordPolicy(...)));
expectError(
    DelegationError::class,
    static fn () => $childLimit->delegate(['record']),
    'child count limit was not enforced',
);
$firstChild->release();
$childLimit->delegate(['record'], null, new FuncPolicy(recordPolicy(...)))->release();
$passed++;

$budgetRecord = new RecordTool();
$budgetTools = new ToolRegistry();
$budgetTools->register($budgetRecord);
$budgetRoot = new Governor(new Authority(
    allowed: ['record'],
    delegable: ['record'],
    maxDepth: 1,
    maxChildren: 2,
    budget: new SharedBudget(1),
    policy: new FuncPolicy(allowAll(...)),
));
$budgetFirst = $budgetRoot->delegate(['record'], null, new FuncPolicy(recordPolicy(...)));
$budgetSecond = $budgetRoot->delegate(['record'], null, new FuncPolicy(recordPolicy(...)));
$budgetFirst->run(
    new FixtureModel('record', ['target' => 'first'], 'first-done'),
    $budgetTools,
    'record once',
);
expectError(
    BudgetExhausted::class,
    static fn () => $budgetSecond->run(
        new FixtureModel('record', ['target' => 'second'], 'second-done'),
        $budgetTools,
        'record twice',
    ),
    'sibling budget was not shared',
);
check($budgetRecord->calls === 1, 'sibling budget effect count was not one');
$budgetFirst->release();
$budgetSecond->release();
$passed++;
$cancelRecord = new RecordTool();
$cancelTools = new ToolRegistry();
$cancelTools->register($cancelRecord);
$cancelRoot = new Governor(new Authority(
    allowed: ['record'],
    delegable: ['record'],
    maxDepth: 1,
    maxChildren: 1,
    budget: new SharedBudget(1),
    policy: new FuncPolicy(allowAll(...)),
));
$cancelChild = $cancelRoot->delegate(['record'], null, new FuncPolicy(recordPolicy(...)));
$cancelled = false;
$cancelError = expectError(
    PraxoException::class,
    static fn () => $cancelChild->run(
        new FixtureModel(
            'record',
            ['target' => 'safe'],
            'unexpected',
            static function () use (&$cancelled): void {
                $cancelled = true;
            },
        ),
        $cancelTools,
        'cancel before effect',
        ['cancellation' => static function () use (&$cancelled): bool {
            return $cancelled;
        }],
    ),
    'cancellation did not stop the child run',
);
check($cancelError->praxoCode === 'AGENT_CANCELLED', 'cancellation code');
check($cancelRecord->calls === 0, 'cancellation produced an effect');
$cancelChild->release();
$passed++;

$editRecord = new RecordTool();
$editTools = new ToolRegistry();
$editTools->register($editRecord);
$editRoot = new Governor(new Authority(
    allowed: ['record'],
    delegable: ['record'],
    maxDepth: 1,
    maxChildren: 1,
    budget: new SharedBudget(1),
    policy: new FuncPolicy(allowAll(...)),
));
$editChild = $editRoot->delegate(['record'], null, new FuncPolicy(recordPolicy(...)));
$editError = expectError(
    PraxoException::class,
    static fn () => $editChild->run(
        new FixtureModel('record', ['target' => 'safe'], 'unexpected'),
        $editTools,
        'record safely',
        ['middleware' => [new MutatingMiddleware()]],
    ),
    'final argument reauthorization did not fail',
);
check($editError->praxoCode === 'AGENT_POLICY_DENIED', 'final argument policy code');
check($editRecord->calls === 0, 'final argument produced an effect');
$editChild->release();
$passed++;
echo "PHP governance delegation checks passed ({$passed})\n";
