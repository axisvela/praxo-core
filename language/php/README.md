# PRAXO-CORE PHP SDK

PHP 8.2+ implementation of the PRAXO-CORE agent contract.

- `SPEC_VERSION`: `0.2.0`
- SDK version: `0.1.0`
- License: MIT
- Dependencies: none beyond the PHP standard library

## Scope

The SDK implements all eleven vector groups: toolcall, jsonschema, plugin,
checkpoint, event, memory, policy, stream, context, middleware, and agent loop.
It includes a public API snapshot and dependency-free tests. Provider adapters
are not included in `0.1.0`.

## Build and test

```bash
php language/php/conformance/run.php
php language/php/conformance/run.php --check-api
php language/php/tests/run.php
composer validate --strict --no-check-publish
```

Local toolchain used by the repository maintainers lives at `D:\dev\php`.

## Quickstart

```php
<?php

require __DIR__ . '/php/src/autoload.php';

use Praxo\Core\Agent;
use Praxo\Core\AgentOptions;
use Praxo\Core\Session;
use Praxo\Core\StaticModel;

$model = new StaticModel('hello');
$agent = new Agent(new AgentOptions($model));
$result = $agent->run(new Session('demo'), 'hello');
echo $result->output;
```

Tools use the same options object:

```php
use Praxo\Core\FuncTool;
use Praxo\Core\ToolRegistry;

$registry = new ToolRegistry();
$registry->register(new FuncTool('echo', 'Echo arguments', static fn (array $args): array => $args));

$options = new AgentOptions($model);
$options->tools = $registry;
$options->maxSteps = 8;
$agent = new Agent($options);
```

## Layout

- `src/` library (PSR-4 `Praxo\Core\`).
- `conformance/run.php` vector runner, API snapshot, and check mode.
- `tests/run.php` dependency-free core tests.
- `api/0.1.0.txt` checked-in public API snapshot.

## Release

Tag shape: `php/v0.1.0`. The tag targets `SPEC_VERSION` `0.2.0`.
