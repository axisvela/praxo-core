# PRAXO-CORE PHP Core

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its
native PHP Core: an agent loop with tool registration and dispatch, policy
hooks, typed events, memory, checkpoints, context budgets, middleware, JSON
Schema validation, and plugin manifest parsing.

Use it when an existing PHP application needs a governed model/tool loop without
adding a Python or Go sidecar. It is not an HTTP user agent, crawler, hosted
agent service, or model provider.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.10.0`
- The latest Packagist package is `axisvela/praxo-core@0.10.0`
- License: MIT
- Dependencies: none beyond the PHP standard library
- Runtime: use a patched PHP release. On Windows use `8.2.35-1`, `8.3.36-1`,
  `8.4.27-1`, `8.5.12-1`, or newer (Brotli 1.2.1, CVE-2026-111497)

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/php/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/php/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/php/llms.md)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/php/examples): runnable language-specific examples.
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [Packagist](https://packagist.org/packages/axisvela/praxo-core)
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761) · [LinkedIn](https://www.linkedin.com/company/axisvela/) · [Facebook](https://www.facebook.com/profile.php?id=61596905732406) · [YouTube](https://www.youtube.com/@axisvela) · [Discord](https://discord.com/channels/1575163993767809064/1575164343148875977) · [GitHub Discussions](https://github.com/axisvela/praxo-core/discussions) · [GitHub Issues](https://github.com/axisvela/praxo-core/issues) · [Documentation](https://axisvela.github.io/praxo-core/) · [Architect](https://axisvela.architect.pub)

## Get started

Install the published package:

```bash
composer require axisvela/praxo-core:0.10.0
```

Then run the smallest deterministic example:

- [Consumer starter](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/consumer): explicit tool scope and a deny check.
- [Live model](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/live-model): connect an OpenAI-compatible endpoint and register `get_time`.

See the [PHP documentation](https://axisvela.github.io/praxo-core/languages/php/) for the full API and the
[language matrix](https://axisvela.github.io/praxo-core/languages/matrix/) for
current scope.

## Examples

Runnable examples live under [`language/php/examples`](https://github.com/axisvela/praxo-core/tree/main/language/php/examples).

| Goal | Example |
| --- | --- |
| Install and deny one unsafe call | [consumer](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/consumer) |
| Connect a real model | [live-model](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/live-model) |
| Connect MCP tools | [mcp](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/mcp) |
| Validate structured output | [structured-output](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/structured-output) |
| Stream a response | [streaming](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/streaming) |
| Add identity and policy | [identity-policy](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/identity-policy) |
| Persist checkpoints | [checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/checkpoint) |
| Run behind HTTP | [service](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/service) |
| Approve or edit a tool call | [hitl](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/hitl) |
| Resume a multi-turn session | [session-checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/session-checkpoint) |
| Retry transient failures | [retry](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/retry) |
| Add provider fallback | [provider-fallback](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/provider-fallback) |
| Observe agent events | [event-sink](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/event-sink) |

## Install

```bash
composer require axisvela/praxo-core:0.10.0
```

## Scope

The Core implements all eleven vector groups: toolcall, jsonschema, plugin,
checkpoint, event, memory, policy, stream, context, middleware, agent loop, and
human-in-the-loop interrupt decisions. It includes a public API snapshot and
dependency-free tests. The package includes Composer autoload metadata and the optional
`Praxo\Core\Adapters\OpenAICompatible`, `Anthropic`, and `Gemini` adapters.

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

## Model Adapters

- `Praxo\Core\Adapters\OpenAICompatible` for OpenAI, DeepSeek, Kimi/Moonshot,
  and other OpenAI-compatible endpoints.
- `Praxo\Core\Adapters\Anthropic` for the Anthropic Messages API, including `generateStream` SSE reassembly.
- `Praxo\Core\Adapters\Gemini` for the Gemini generateContent API.

Each adapter accepts an injectable transport callable. `OpenAICompatible`
implements `StreamingModel`; `generateStream` sets `stream: true`, parses SSE,
reassembles content, fragmented tool calls, usage, and `finish_reason`, and
calls the delta callback. Pass a `streamTransport` returning raw SSE text, or
use `Agent::runStream`.

## MCP Client

`Praxo\Core\Adapters\MCPClient` implements a stdio JSON-RPC MCP session with
initialize, paginated tool listing, tool calls, timeouts, and cancellation
notifications. `StdioMCPTransport` starts a child process; tests can implement
`MCPTransport` directly.

## Harmovela Event Sink

`Praxo\Core\Adapters\HarmovelaSink` implements `EventSink` and posts to
`{baseUrl}/events`.

```php
use Praxo\Core\Adapters\HarmovelaSink;

$options->events = new HarmovelaSink('http://127.0.0.1:8790/aep/api');
```

The constructor also accepts `source`, `specVersion`, `transport`, `clock`, and
`timeout`. A 2xx status is success; other statuses throw `HARMOVELA_HTTP` with a
bounded body. The sink adds no authentication, retries, buffering, ordering, or
exactly-once delivery. Use HTTPS and filter sensitive event data first.

## Layout

- `src/` library (PSR-4 `Praxo\Core\`).
- `conformance/run.php` vector runner, API snapshot, and check mode.
- `tests/run.php` dependency-free core tests.
- `api/0.9.0.txt` checked-in public API snapshot.

## Release

Tag shape: `php/v0.9.0`. The tag targets `SPEC_VERSION` `0.2.0`. See
[CHANGELOG.md](CHANGELOG.md) for per-release changes and compatibility notes.


## Tutorials and Reference Applications

Language-specific scenario tutorials and reference applications for PHP.

### Scenario Tutorials

| Tutorial | What it shows |
| --- | --- |
| [api-orchestration](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/api-orchestration) | A bounded first slice of [SE-08](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a general integration platform. It reads two synthetic upstream API... |
| [copyright-evidence](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/copyright-evidence) | A bounded first slice of [LJ-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a rights-enforcement service. It compares fixed authorized assets a... |
| [customer-support](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/customer-support) | Routes one fixed ticket and drafts a review-only billing reply. No CRM send, refund or account change. |
| [customs-reroute](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/customs-reroute) | A bounded first slice of [TL-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a customs-filing system. It validates fixed document fields, compar... |
| [internal-service-desk](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/internal-service-desk) | A bounded first slice of [OP-01](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an identity or provisioning system. It reads a fixed employee reque... |
| [lead-nurture](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/lead-nurture) | A bounded first slice of [CS-02](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not an outreach-automation product. It ranks fixed synthetic business p... |
| [localization-draft](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/localization-draft) | A bounded first slice of [CS-07](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a legal or tax compliance system. It compares fixed localization ru... |
| [public-approval](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/public-approval) | A bounded first slice of [CT-03](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a government identity or approval system. It validates a fixed appl... |
| [recruiting-match](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/recruiting-match) | Matches fixed candidates against one role and drafts a review-only shortlist. No outreach, ranking model or hiring decision. |
| [retail-replenishment](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/retail-replenishment) | Computes a reorder quantity from fixed stock and drafts a review-only order. No purchase order or supplier call. |
| [tender-review](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/tender-review) | A bounded first slice of [BE-04](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a bid-submission or collusion-detection system. It validates fixed... |

Index: [language/php/Tutorial](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial).

### Reference Applications

| Application | What it shows |
| --- | --- |
| [ai-editorial-studio](https://github.com/axisvela/praxo-core/tree/main/language/php/application/ai-editorial-studio) | A Laravel 12 content-portal application where the agent drives the primary editorial workflow: an editor submits a brief, the agent retrieves related content, drafts an article... |
| [content-review](https://github.com/axisvela/praxo-core/tree/main/language/php/application/content-review) | A Laravel 12 content portal that routes one existing draft article through a governed PRAXO-CORE agent. The agent reads the article through an application-owned content store, d... |

Index: [language/php/application](https://github.com/axisvela/praxo-core/tree/main/language/php/application).

Planning context: [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/), [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), and [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/). Chinese: [教程计划](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/), [候选场景](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/), [教程目录](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/).

## Community

- X: <https://x.com/axisvela>
- Weibo: <https://weibo.com/u/1936025761>
- LinkedIn: <https://www.linkedin.com/company/axisvela/>
- Facebook: <https://www.facebook.com/profile.php?id=61596905732406>
- YouTube: <https://www.youtube.com/@axisvela>
- Discord: <https://discord.com/channels/1575163993767809064/1575164343148875977>
- GitHub Discussions: <https://github.com/axisvela/praxo-core/discussions>
- GitHub Issues: <https://github.com/axisvela/praxo-core/issues>
- Documentation: <https://axisvela.github.io/praxo-core/>
- Architect: <https://axisvela.architect.pub>

