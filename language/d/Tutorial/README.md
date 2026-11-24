# D Tutorials

- [Quantitative Risk (FC-02)](quant-risk/README.md): source D Core, fixed
  exposure versus a stated risk limit and a review-only order draft; no trades.
- [Executive Brief (OP-07)](executive-brief/README.md): source D Core, fixed
  business variances and a review-only operating brief; no sends or live data.

See the [100-scenario catalog](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/)
for additional D candidate assignments. Those are planned targets, not implemented
tutorials.

## Article angle

Native tooling with explicit checks: embedding review where the data and calculations already live.

## Business scenarios

These D examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [D Executive Brief (OP-07)](./executive-brief/README.md)
- [D fleet map (TL-06)](./fleet-map/README.md)
- [D property forecast (BE-05)](./property-forecast/README.md)
- [D Quantitative Risk (FC-02)](./quant-risk/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

D targets native systems programming with optional safety checks, fast compilation and straightforward C interoperability.

Language and ecosystem traits:

- Compile-time metaprogramming and optional memory-safety features.
- Native code generation with C ABI access.
- Fast edit/compile cycles compared with some native toolchains.

Trade-offs:

- Smaller ecosystem, library choice and hiring pool.
- Toolchain and runtime conventions differ across teams.

Praxo-specific fit: The Core seam suits existing native D tools; the tutorial does not claim a general D advantage over Go, C++ or Python for business orchestration.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by D, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
