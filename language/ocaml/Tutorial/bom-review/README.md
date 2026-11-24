# OCaml Drawing/BOM Review (IN-05)

A bounded first slice of [IN-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not CAD/BIM parsing or engineering certification. It reads a fixed parsed drawing,
reports one clearance conflict, and drafts a review-only BOM. No CAD access or live
model.

## Why this language and runtime?

- **Selection basis:** OCaml fits engineering tools that parse structured formats and
  need typed graph or rule processing in a native binary.
- **Demonstrated fit:** A fixed parsed-drawing graph yields a review-only BOM; no CAD
  parser, vision system or engineering certification runs.
- **Choose when:** Learning the Core seam in an existing OCaml engineering tool.
- **Do not choose when:** Seeking CAD/BIM parsing or certified BOM output. Compare the
  CAD import pipeline and engineering review process first.
- **Evidence limit:** Core integration fixture only; no CAD/BIM input, graph repair,
  engineering validation, manufacturing or certification.

Run from **this directory**:

```bash
cd language/ocaml/Tutorial/bom-review
ocaml unix.cma review.ml --test
ocaml unix.cma review.ml
ocaml unix.cma review.ml --drawing drawing-200
ocaml unix.cma review.ml --simulate-failure
```

Expected test output:

```text
success: drawing-100 components=3 conflicts=1 status=draft_only revisions=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: DRAWING_SOURCE_UNAVAILABLE reads=1
```

Both negative commands exit nonzero.

`read_drawing` returns three components, one `clearance_conflict` and a fixed cost
estimate; `draft_bom` returns `status=draft_only`, `review_required=true` and
`revisions_applied=0`. The action policy limits the drawing and final `publish_bom`
action. Tests assert one read and one draft on success, zero reads/drafts for a
cross-drawing denial, and one read/zero drafts for the simulated drawing-source
outage.

Real CAD/BIM parsing, engineering rules, manufacturing review and BOM publication
belong to the consumer. Run from the tutorial directory; `#use` resolves against
the current working directory and `unix.cma` must be loaded.
