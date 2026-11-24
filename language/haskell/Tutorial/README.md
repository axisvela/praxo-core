# Haskell Tutorials

- [Literature Review (SC-01)](literature-review/README.md): source Haskell Core,
  fixed synthetic paper corpus and an explicitly unverified hypothesis draft; no
  live search or scientific-validity claim.

See the [100-scenario catalog](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/)
for additional Haskell candidate assignments. Those are planned targets, not
implemented tutorials.

## Article angle

Typed seams for research and compiler tooling: explicit effects and errors without claiming formal proof.

## Business scenarios

These Haskell examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [Haskell Literature Review (SC-01)](./literature-review/README.md)
- [Haskell policy simulation (OG-02)](./policy-simulation/README.md)
- [Haskell test generation (SE-04)](./test-generation/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

Haskell offers strong static types, purity and equational reasoning, and is used for compilers, parsers, formal tooling and research prototypes.

Language and ecosystem traits:

- Algebraic data types and exhaustive pattern matching.
- Purity and explicit effects aid reasoning and refactoring.
- Mature parser/compiler libraries and GHC tooling.

Trade-offs:

- Learning curve and laziness can complicate operational reasoning.
- Smaller industry hiring and application ecosystem.

Praxo-specific fit: The Core seam fits existing Haskell research tools; the tutorial does not turn types into proof or establish literature-review quality.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Haskell, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
