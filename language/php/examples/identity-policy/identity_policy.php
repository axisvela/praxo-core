<?php

declare(strict_types=1);

$autoload = __DIR__ . '/vendor/autoload.php';
if (is_file($autoload)) {
    require $autoload;
} else {
    require __DIR__ . '/../../src/autoload.php';
}

use Praxo\Core\Action;
use Praxo\Core\Decision;
use Praxo\Core\PolicyHook;

final class IdentityPolicy implements PolicyHook
{
    public function __construct(private readonly ?array $principal)
    {
    }

    public function authorize(Action $action): Decision
    {
        if ($this->principal === null) {
            return Decision::deny('trusted principal is missing');
        }
        if (!$this->principal['active']) {
            return Decision::deny('trusted principal is inactive');
        }
        if ($action->kind === 'model.generate') {
            return Decision::allow('model generation');
        }
        if ($this->principal['role'] !== 'operator') {
            return Decision::deny('role is not permitted');
        }
        if (($action->arguments['tenant'] ?? null) !== $this->principal['tenant']) {
            return Decision::deny('tenant mismatch');
        }
        if ($action->toolName !== 'record') {
            return Decision::deny('operation is not permitted');
        }
        return Decision::allow('verified operator');
    }
}

$operator = ['tenant' => 'acme', 'role' => 'operator', 'active' => true];
$policy = new IdentityPolicy($operator);
if (!$policy->authorize(new Action('model.generate', 's1'))->allowed) {
    throw new RuntimeException('model generation should be allowed');
}
if (!$policy->authorize(new Action('tool.invoke', 's1', 'record', ['tenant' => 'acme']))->allowed) {
    throw new RuntimeException('record should be allowed');
}
$viewer = new IdentityPolicy(['tenant' => 'acme', 'role' => 'viewer', 'active' => true]);
if ($viewer->authorize(new Action('tool.invoke', 's1', 'record', ['tenant' => 'acme']))->allowed) {
    throw new RuntimeException('viewer should be denied');
}
if ($policy->authorize(new Action('tool.invoke', 's1', 'record', ['tenant' => 'other']))->allowed) {
    throw new RuntimeException('tenant mismatch should be denied');
}
if ((new IdentityPolicy(null))->authorize(new Action('model.generate', 's1'))->allowed) {
    throw new RuntimeException('missing principal should be denied');
}

echo "PHP identity policy example passed\n";
