# Julia Tutorials

Application tutorials live in `Tutorial/`, alongside focused `examples/`.

- [Experiment comparison](experiment-comparison/README.md): native Julia
  computations over fixed experiment results, with the model packaging computed
  evidence rather than inventing metrics.

The tutorial runs in source mode from the repository root and does not use a
provider credential or a live model in deterministic mode.

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

Julia fits numerical research where experiment comparison already happens in the same runtime.

- Native means and deltas are computed over a fixed sample set.
- The report records no mutating actions.

Trade-offs and limits:

- No lab system, notebook integration or statistical validation.
- No package-ecosystem or performance claim is made.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Julia, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
