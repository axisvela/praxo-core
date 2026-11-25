# Julia Tutorials

Application tutorials live in `Tutorial/`, alongside focused `language/go/examples/`.

- [Dispatch review](dispatch-review/README.md): native Julia bounded dispatch
  optimization with plan/shortfall branches; no grid commands.
- [Experiment comparison](experiment-comparison/README.md): native Julia
  computations over fixed experiment results, with the model packaging computed
  evidence rather than inventing metrics.

The tutorial runs in source mode from the repository root and does not use a
provider credential or a live model in deterministic mode.

## Article angle

Primary planned direction: constrained energy-dispatch review using numerical
optimization. See [runtime-aligned design](https://axisvela.github.io/praxo-core/getting-started/runtime-scenario-design/).

Numerical research plus a review boundary: multiple dispatch, scientific libraries and explicit non-goals.

## Business scenarios

These Julia examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [Julia Experiment Comparison Agent](./experiment-comparison/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

Julia targets technical computing with multiple dispatch, JIT-compiled numerical code and a growing scientific package ecosystem.

Language and ecosystem traits:

- Multiple dispatch and expressive numerical code.
- Performance close to compiled languages for many numeric workloads.
- Strong plotting, optimization and scientific libraries.

Trade-offs:

- Compilation latency and package maturity vary by domain.
- General service and operations tooling are less established.

Praxo-specific fit: The Core seam fits existing Julia analysis; the fixed comparison is not evidence of numerical validation or platform performance.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Julia, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
