# Perl Tutorials

Application tutorials live in `Tutorial/`, alongside focused `examples/`.

- [Log triage](log-triage/README.md): native Perl Core, fixed log parsing, a
  scoped summary tool, and a deterministic report.

Tutorials use the native Perl Core and do not require a network or a model
endpoint in deterministic mode. Application business rules remain outside Core.

## Article angle

Text-heavy automation plus review: regex, CPAN and legacy operations without pretending to be a modern application platform.

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

Perl remains effective for text processing, regular expressions, log handling and long-lived system administration automation.

Language and ecosystem traits:

- Best-in-class text/regex handling and CPAN breadth.
- Excellent for glue code and legacy operations automation.
- Mature command-line and reporting conventions.

Trade-offs:

- Modern application structure and type safety are weaker.
- Long-term maintainability depends heavily on discipline.

Praxo-specific fit: The Core seam fits existing Perl operations scripts; the log fixture does not establish monitoring, alerting or correlation capability.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Perl, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
