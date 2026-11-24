# Octave Tutorials

Application tutorials live in `Tutorial/`, alongside focused `examples/`.

- [Water quality](water-quality/README.md): fixed oxygen/temperature thresholds
  with a review-only aeration branch; no sensor or actuator access.
- [Vibration review](vibration-review/README.md): native FFT/RMS comparison of
  normal and anomalous samples with a review-only inspection branch; no device access.
- [Signal trends](signal-trends/README.md): runs the shared MATLAB/Octave signal
  tutorial under GNU Octave with native core metrics and a scoped report.

Octave verification does not establish native MATLAB behavior. The shared source
lives under `language/matlab/Tutorial/signal-trends/`.

## Article angle

Primary direction: [vibration inspection](vibration-review/README.md) using FFT/RMS
and contrasting samples. See [runtime-aligned design](https://axisvela.github.io/praxo-core/getting-started/runtime-scenario-design/).

Free numerical workflows for MATLAB-style analysis, with a clear line between Octave results and MATLAB guarantees.

## Business scenarios

These Octave examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [Octave Signal Trends](./signal-trends/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

GNU Octave provides a free, largely MATLAB-compatible environment for matrix and signal work where licensing or offline use matters.

Language and ecosystem traits:

- MATLAB-like syntax and matrix operations without a license.
- Useful for teaching, local analysis and compatibility checks.
- Open-source deployment and scripting.

Trade-offs:

- Compatibility gaps and different toolbox coverage versus MATLAB.
- Performance and ecosystem are not equivalent to commercial MATLAB.

Praxo-specific fit: The Core seam fits Octave-based analysis; results must not be presented as native MATLAB evidence.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Octave, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
