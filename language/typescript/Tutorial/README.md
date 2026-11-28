# TypeScript Tutorials

Application-shaped tutorials live here, alongside `language/go/examples/`, which keeps
mechanism checks and focused integration examples. Tutorial is intentionally
capitalized in directory paths.

- [Order support](order-review/README.md): native Core, policy and HTTP tools over
  a shared synthetic service; deterministic slice, not a Web frontend.
- [Customer support](customer-support/README.md): native Core, fixed order/policy
  tools, SSE streaming and loopback HTTP; no reply sends or live model.
- [Travel booking](travel-booking/README.md): native Core, fixed inventory and a
  review-only fare hold; no payment, ticketing or inventory write.
- [Retail replenishment](retail-replenishment/README.md): native Core, fixed stock
  and pricing fixture with a review-only purchase-order draft.

Shared business backends live in the public
[agent-tutorial-services](https://github.com/axisvela/agent-tutorial-services)
repository; they are not part of the Core package or wire spec.

## Article angle

One language across Node services and browser clients, with runtime validation behind erased types.

## Business scenarios

These TypeScript examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [TypeScript Customer Support Streaming](./customer-support/README.md)
- [TypeScript localization draft (CS-07)](./localization-draft/README.md)
- [TypeScript negotiation interpretation (OG-03)](./negotiation-interpretation/README.md)
- [Order Support Agent](./order-review/README.md)
- [TypeScript Retail Replenishment (CS-05)](./retail-replenishment/README.md)
- [TypeScript travel booking](./travel-booking/README.md)
- [TypeScript workspace plan (SE-01)](./workspace-plan/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

TypeScript adds static typing to the JavaScript ecosystem, covering Node services and browser code while retaining npm reach and tooling.

Language and ecosystem traits:

- Static types over the huge JavaScript/npm ecosystem.
- One language for Node services and browser clients.
- Strong editor, refactoring and framework support.

Trade-offs:

- Types are erased at runtime; boundaries still need validation.
- Build tooling, dependencies and runtime behavior vary by platform.

Praxo-specific fit: The Core seam fits existing Node/web products; the tutorials are CLI or local SSE demos, not browser UI or payment/ticketing integrations.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/evaluation/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by TypeScript, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
