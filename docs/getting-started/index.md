# Start Here

1. Decide whether the framework fits with the [overview](overview.md) and
   [When Not to Use PRAXO-CORE](when-not-to-use.md).
2. Run the [quickstart](quickstart.md) to connect a real model endpoint.
3. Choose a published-package [consumer starter](consumer-go.md) for your
   language.
4. Use the [adoption guide](adoption.md) to turn the first run into an
   application integration.
5. Follow the [public roadmap](../project/planning/roadmap.md) for prototype, embedding,
   hardening, and advanced paths.

## Task-to-Path Table

This is the canonical task-to-path table for the documentation. The landing page
and overview link here instead of keeping separate copies. Each row answers a
different question: can it run, is the package usable, is the integration safe to
operate, or is an advanced boundary exercised.

| Task | Path layer | Start here | What the path proves |
| --- | --- | --- | --- |
| Get a model or tool result quickly | Try | [Quickstart](quickstart.md), [Live Model Golden Path](live-model-golden-path.md) | The application starts and reaches an OpenAI-compatible endpoint; not package or production verification |
| Install a published package and prove allow/deny | Verify | [Consumer starters](consumer-go.md) for Go, Python, TypeScript, Java, Ruby, PHP, Elixir, or Lua | One allowed call and one denied call with zero effects against a published package |
| Add a model/tool loop to an existing application | Embed | [Adoption guide](adoption.md), [Application integration checklist](../guides/application-integration-checklist.md) | Core is embedded behind application-owned configuration, identity, persistence, and shutdown |
| Add verified identity, approvals, checkpoints, or recovery | Harden | [Identity and policy](../guides/identity-policy.md), [Checkpoint and continuation](../guides/checkpoint-continuation.md), [Long-running operations](../guides/long-running-operations.md) | The specific integration fails closed and can be upgraded, cancelled, and recovered |
| Add plugins, delegation, long-running operations, or workspace/embodied seams | Extend | [Advanced examples](../guides/advanced-examples.md), [Plugins](../guides/plugins.md), [Multi-agent patterns](../guides/multi-agent.md) | An advanced boundary is exercised; Core-enforced inheritance and production readiness are not implied |
| Browse runnable examples by task | Prototype | [Examples](examples.md), [Language Coverage](language-coverage.md) | Source entries and depth labels; execution depth varies by theme and language |
| Have a coding agent integrate Core | Verify | [For Coding Agents](coding-agents.md), [package map](agent-integration.json) | A version-checked package map and contract; not a hidden install channel or automatic skill |
| Use another supported language | Prototype | [Language implementations](../languages/index.md#what-you-can-build-today), [support and distribution](../languages/support.md) | What that language can build today; each implementation is independently versioned |
| Use durable graph workflows, exactly-once effects, or a managed sandbox | Decide | [When Not to Use PRAXO-CORE](when-not-to-use.md) first | Core supplies seams, not those products or guarantees |

Most developers should finish one layer before moving to the next. The layers
share contracts but answer different questions: "does it run?", "is the package
usable?", "is this specific integration safe to operate?", and "is an advanced
boundary actually exercised?".

Language entry points describe what you can build today rather than only a
contract tier. See [Language Implementations](../languages/index.md#what-you-can-build-today)
for the build-oriented language groups and [registry status](../languages/registry-status.md)
before assuming a package is installable.

## Continue by Task

| Task | Documentation |
| --- | --- |
| Browse runnable examples | [Examples](examples.md) |
| Wire your application | [Integration](../guides/integration.md), [recipes](../guides/recipes.md) |
| Add a provider or protocol | [Adapters](../integrations/index.md) |
| Author a plugin | [Plugin guide](../guides/plugins.md) |
| Delegate work | [Multi-agent patterns](../guides/multi-agent.md) |
| Inspect contracts | [Architecture](../reference/architecture.md), [primitives](../reference/primitives.md), [events](../reference/events.md) |
| Evaluate safety | [Security model](../security/index.md) |
| Upgrade | [Compatibility](../project/status/version-compatibility.md), [releases](../releases/index.md) |
| Contribute a Core implementation change | [Core design](../contributing/core-design.md), [language policy](../contributing/language-policy.md) |
