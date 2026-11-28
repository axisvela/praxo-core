# R Tutorials

Application tutorials live in `Tutorial/`, alongside focused `language/go/examples/`.

- [Data quality](data-quality/README.md): native R statistics, a fixed dataset,
  computed evidence and a structured quality report.

The tutorial runs in source mode from the repository root. It does not use the
shared business backend, a provider credential or a live model in deterministic
mode. Application-specific analysis remains outside Core.

## Article angle

Statistics-first Agents with review boundaries: data frames, CRAN and the separation between analysis and advice.

## Business scenarios

These R examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [R budget review (CT-07)](./budget-review/README.md)
- [R Data Quality Agent](./data-quality/README.md)
- [R fire spread (AE-02)](./fire-spread/README.md)
- [R hedge plan (AE-04)](./hedge-plan/README.md)
- [R marketing segmentation](./marketing-segmentation/README.md)
- [R property forecast (BE-05)](./property-forecast/README.md)
- [R wealth analysis](./wealth-analysis/README.md)
- [R weather anomaly (SC-05)](./weather-anomaly/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

R is built for statistics and data analysis, with data frames, modeling packages, visualization and a research-oriented CRAN ecosystem.

Language and ecosystem traits:

- First-class statistical modeling and data frames.
- Extensive CRAN packages and visualization.
- Strong fit for exploratory and publication-oriented analysis.

Trade-offs:

- General-purpose performance and software engineering are weaker.
- Production service patterns require additional tooling.

Praxo-specific fit: The Core seam fits existing R analysis; fixed fixtures do not establish statistical validity, advice or production reporting.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/evaluation/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by R, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
