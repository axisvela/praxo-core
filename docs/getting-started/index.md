# Start Here

1. Decide whether the framework fits with the [overview](overview.md) and
   [When Not to Use PRAXO-CORE](when-not-to-use.md).
2. Run the [quickstart](quickstart.md) to connect a real model endpoint.
3. Choose a published-package [consumer starter](consumer-go.md) for your
   language.
4. Use the [adoption guide](adoption.md) to turn the first run into an
   application integration.
5. Follow the [public roadmap](../project/roadmap.md) for prototype, embedding,
   hardening, and advanced paths.

## Choose by Task

| Need | Start with | Important boundary |
| --- | --- | --- |
| Get a useful result quickly | [Quickstart](quickstart.md) | Connects an OpenAI-compatible endpoint; start with a low-risk tool and keep credentials in the application |
| Have a coding agent integrate Core | [For Coding Agents](coding-agents.md), [package map](agent-integration.json) | Concise contract and version-checked package map; not a hidden install channel or automatic skill |
| Add a model/tool loop to a Go, Python, TypeScript, or Java application | [Go](consumer-go.md), [Python](consumer-python.md), [TypeScript](consumer-typescript.md), or [Java](consumer-java.md) consumer starter | Uses a published package, deterministic model, explicit tool scope, and a denial test; your application owns identity, persistence, and isolation |
| Add an allow/deny model/tool loop in Ruby, PHP, Elixir, or Lua | [Ruby](consumer-ruby.md), [PHP](consumer-php.md), [Elixir](consumer-elixir.md), or [Lua](consumer-lua.md) consumer starter | Extended-language starters use a published package and deterministic allow/deny; the governed negative matrix remains scoped to the four pilot languages |
| Use another supported language | [Language implementations](../languages/index.md), [support and distribution](../languages/support.md) | Each language is independently versioned; check its installation and feature coverage instead of assuming the Go example applies unchanged |
| Authorize tools and prove denial has no effects | The same consumer starters | A policy hook is an enforcement point, not an identity service or process sandbox |
| Bind verified identity and policy | [Identity and policy recipe](../guides/identity-policy.md) | Application authenticates and supplies a trusted principal; model-provided roles are ignored |
| Add a long-running remote operation | [Long-running operations recipe](../guides/long-running-operations.md) | Run state, cancel request/confirmation, and remote effect evidence remain separate |
| Add human approval, checkpoints, or recovery | [Recipes](../guides/recipes.md), [adoption guide](adoption.md), [governed execution design](../reference/governed-execution.md) | Persistent approvals, leases, and effect reconciliation are integration responsibilities; the design is proposed, not a profile guarantee |
| Use durable graph workflows, exactly-once effects, or a managed sandbox | [When Not to Use PRAXO-CORE](when-not-to-use.md) first | Core supplies seams, not those products or guarantees |

## Continue by Task

| Task | Documentation |
| --- | --- |
| Wire your application | [Integration](../guides/integration.md), [recipes](../guides/recipes.md) |
| Add a provider or protocol | [Adapters](../integrations/index.md) |
| Author a plugin | [Plugin guide](../guides/plugins.md) |
| Delegate work | [Multi-agent patterns](../guides/multi-agent.md) |
| Inspect contracts | [Architecture](../reference/architecture.md), [primitives](../reference/primitives.md), [events](../reference/events.md) |
| Evaluate safety | [Security model](../security/index.md) |
| Upgrade | [Compatibility](../project/compatibility.md), [releases](../releases/index.md) |
| Contribute a Core implementation change | [Core design](../contributing/core-design.md), [language policy](../contributing/language-policy.md) |
