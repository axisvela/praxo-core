# MATLAB Tutorials

Application tutorials live in `Tutorial/`, alongside focused `language/go/examples/`.

- [Data quality](data-quality/README.md): fixed mean/median/outlier statistics and
  a review-only outlier branch; local evidence is GNU Octave.
- [Signal trends](signal-trends/README.md): native signal metrics, threshold
  anomalies, and a structured report over a fixed signal.

Octave reuses the same tutorial sources through
`language/octave/Tutorial/signal-trends/`. Native MATLAB runtime verification is
not claimed when only GNU Octave has been run.

## Article angle

Engineering analysis with review-only output, and why Octave evidence must be separated from native MATLAB claims.

## Business scenarios

These Matlab examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [Signal Trends Agent](./signal-trends/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

MATLAB is matrix-first and widely used in engineering, control and signal analysis, backed by toolboxes and Simulink-style workflows.

Language and ecosystem traits:

- Matrix/vector syntax and numerical toolboxes.
- Strong engineering visualization and simulation ecosystem.
- Common in control, signal and research workflows.

Trade-offs:

- Commercial licensing and deployment constraints.
- General software engineering and package management differ from open stacks.

Praxo-specific fit: The Core seam fits existing MATLAB analysis; local evidence is GNU Octave, so native MATLAB and toolbox behavior remain unverified.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/evaluation/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Matlab, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
