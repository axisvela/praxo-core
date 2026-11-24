# MATLAB Tutorials

Application tutorials live in `Tutorial/`, alongside focused `examples/`.

- [Signal trends](signal-trends/README.md): native signal metrics, threshold
  anomalies, and a structured report over a fixed signal.

Octave reuses the same tutorial sources through
`language/octave/Tutorial/signal-trends/`. Native MATLAB runtime verification is
not claimed when only GNU Octave has been run.

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

MATLAB fits signal-processing and engineering workflows where analysis and review should remain in the same environment.

- The signal example computes fixed metrics and returns a report.
- No device control or threshold mutation occurs.

Trade-offs and limits:

- Local execution evidence currently comes from GNU Octave.
- Native MATLAB and toolbox behavior are unverified.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Matlab, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
