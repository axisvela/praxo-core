# OCaml Tutorials

- [Drawing/BOM Review (IN-05)](bom-review/README.md): source OCaml Core, fixed
  drawing conflicts and a review-only BOM; no CAD access.
- [Contract Review (FC-05)](contract-review/README.md): source OCaml Core, fixed
  clause redlines and a review-only revision; no document store or legal advice.
  Run from the tutorial directory with `ocaml unix.cma review.ml --test`.
- [Code Review (SE-05)](code-review/README.md): source OCaml Core, fixed diff and
  manifest evidence with a review-only comment draft; no host writes or
  vulnerability-database claim.

See the [100-scenario catalog](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/)
for additional OCaml candidate assignments. Those are planned targets, not
implemented tutorials.

## Article angle

Primary planned direction: executable static-analysis diagnostic review.
See [runtime-aligned design](https://axisvela.github.io/praxo-core/getting-started/runtime-scenario-design/).

Typed analysis tools with review-only findings: parsers, graphs and rules without overstating formal verification.

## Business scenarios

These Ocaml examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [OCaml architecture graph (OG-01)](./architecture-graph/README.md)
- [OCaml Drawing/BOM Review (IN-05)](./bom-review/README.md)
- [OCaml Code Review (SE-05)](./code-review/README.md)
- [OCaml Contract Review (FC-05)](./contract-review/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

OCaml pairs strong static types and pattern matching with native compilation, and is used for compilers, analyzers, finance and formal tooling.

Language and ecosystem traits:

- Expressive algebraic types and exhaustive matching.
- Native and bytecode compilation with predictable performance.
- Strong fit for parsers, compilers and rule-heavy tools.

Trade-offs:

- Smaller ecosystem and hiring pool than mainstream languages.
- Parallelism and tooling require more deliberate choices.

Praxo-specific fit: The Core seam fits existing OCaml analysis tools; the tutorials return fixed findings rather than exercising parsers, rules or formal verification.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Ocaml, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
