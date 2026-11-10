# PRAXO-CORE PHP Core

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its
native PHP Core: an agent loop with tool registration and dispatch, policy
hooks, typed events, memory, checkpoints, context budgets, middleware, JSON
Schema validation, and plugin manifest parsing.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.4.1`
- The latest Packagist package is `axisvela/praxo-core@0.4.1`
- License: MIT
- Dependencies: none beyond the PHP standard library

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/php/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/php/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/php/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [Packagist](https://packagist.org/packages/axisvela/praxo-core)

## Install

```bash
composer require axisvela/praxo-core
```

## Scope

The Core implements all eleven vector groups: toolcall, jsonschema, plugin,
checkpoint, event, memory, policy, stream, context, middleware, agent loop, and
human-in-the-loop interrupt decisions. It includes a public API snapshot and
dependency-free tests. `0.4.1` adds Composer autoload metadata and the optional
`Praxo\Core\Adapters\OpenAICompatible` adapter; other provider adapters are not
included.

`maxParallelTools` and `batchToolInvoker` add caller-provided cooperative
parallel tool dispatch. The Core prepares and authorizes each call, then the
batch invoker owns execution and returns results in call order. The native test
uses PHP Fibers; the Core itself does not create threads.

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
- `api/0.4.1.txt` checked-in public API snapshot.

## Release

Tag shape: `php/v0.4.1`. The tag targets `SPEC_VERSION` `0.2.0`. See
[CHANGELOG.md](CHANGELOG.md) for per-release changes and compatibility notes.
