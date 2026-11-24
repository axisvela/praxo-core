# C# Tutorials

Application tutorials live in `Tutorial/`, alongside focused `examples/`.

- [Order service desk](order-review/README.md): ASP.NET Core, a native Core
  Agent, scoped business tools and the public synthetic order service.

The shared MIT backend is [agent-tutorial-services](https://github.com/axisvela/agent-tutorial-services).
Business APIs are teaching contracts, not additions to Core's public API.

## Business scenarios

These C# examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [C# airport recovery (TL-07)](./airport-recovery/README.md)
- [C# healthcare scheduling](./healthcare-scheduling/README.md)
- [C# medical coding (HC-04)](./medical-coding/README.md)
- [C# Order Service Desk](./order-review/README.md)
- [C# Sales / CRM Service Desk](./sales-crm/README.md)
- [C# test generation (SE-04)](./test-generation/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

C# fits .NET services and desktop operations where identity, HTTP entry and the Agent can share one process and deployment model.

- ASP.NET Core and console hosts are represented.
- The published Core package is used through ordinary project references.

Trade-offs and limits:

- Backends are synthetic and loopback-only in these examples.
- No production OIDC, ERP, billing or hosted endpoint is verified.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by C#, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
