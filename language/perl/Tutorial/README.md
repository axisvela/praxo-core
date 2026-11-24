# Perl Tutorials

Application tutorials live in `Tutorial/`, alongside focused `examples/`.

- [Log triage](log-triage/README.md): native Perl Core, fixed log parsing, a
  scoped summary tool, and a deterministic report.

Tutorials use the native Perl Core and do not require a network or a model
endpoint in deterministic mode. Application business rules remain outside Core.

## Business scenarios

These Perl examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [Perl Log Triage](./log-triage/README.md)
- [Perl news fact-check (MD-02)](./news-factcheck/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

Perl fits existing text-processing, log and legacy automation environments.

- Native severity counts and structured reports are produced locally.
- Examples cover log triage and news source comparison.

Trade-offs and limits:

- No log ingestion, alerting, live crawl or truth verification.
- No CPAN dependency or production monitoring claim.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Perl, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
