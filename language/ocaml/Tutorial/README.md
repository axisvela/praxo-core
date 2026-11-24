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

OCaml fits document, compiler and rule-oriented tools that already value typed data and native executables.

- Examples cover contract redlines, BOM checks, code review and graph findings.
- Core policy and failure behavior stay in the OCaml process.

Trade-offs and limits:

- Findings are fixtures; no parser or rule counterexamples are tested.
- No formal verification or legal/engineering certification.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by Ocaml, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
