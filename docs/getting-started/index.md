# Start Here

1. Read the [overview](overview.md) to understand the framework boundary.
2. Choose a [consumer starter](consumer-go.md) for your language.
3. Run the [quickstart](quickstart.md).
4. Review the [adoption guide](adoption.md) before embedding it in a product.
5. If you are still deciding, read [When Not to Use PRAXO-CORE](when-not-to-use.md).

## Choose by Task

| Need | Start with | Important boundary |
| --- | --- | --- |
| Have a coding agent integrate Core | [For Coding Agents](coding-agents.md), [package map](agent-integration.json) | Concise contract and version-checked package map; not a hidden install channel or automatic skill |
| Add a model/tool loop to a Go, Python, TypeScript, or Java application | [Go](consumer-go.md), [Python](consumer-python.md), [TypeScript](consumer-typescript.md), or [Java](consumer-java.md) consumer starter | Uses a published package, deterministic model, explicit tool scope, and a denial test; your application owns identity, persistence, and isolation |
| Authorize tools and prove denial has no effects | The same consumer starters | A policy hook is an enforcement point, not an identity service or process sandbox |
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
