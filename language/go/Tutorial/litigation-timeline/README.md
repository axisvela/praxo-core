# Go litigation timeline

A scoped litigation-support tutorial over the Go reference Core. It builds a
cited timeline from fixed synthetic documents, flags one contradiction and drafts
a review-only evidence outline. The source and model are deterministic fixtures.
This tutorial does not give legal advice, rule on admissibility, call a live model
or touch real case files.

## Why this language and runtime?

- **Selection basis:** A Go legal-operations service can keep evidence handling and
  the review boundary in one deployable component. No firm consumer is verified.
- **Demonstrated fit:** Fixed documents produce a cited timeline and review-only
  outline; no document store, privilege review or legal analysis runs.
- **Choose when:** Learning the reference tool/policy loop around evidence review.
- **Do not choose when:** Seeking legal advice or admissibility decisions. Compare
  document-review platforms and counsel workflows first.
- **Evidence limit:** Core integration fixture only; no real case files, privilege
  handling, citation validation, legal advice or admissibility claim.

Run from the repository root:

```bash
go run ./language/go/Tutorial/litigation-timeline --test
go run ./language/go/Tutorial/litigation-timeline --matter matter-200
go run ./language/go/Tutorial/litigation-timeline --simulate-failure
```

Expected test output:

```text
success: matter-100 documents=3 events=4 contradictions=1 status=draft_only advice=0 reads=1
deny: policy denied reads=0
failure: DOCUMENT_INDEX_UNAVAILABLE reads=1
```

`matter-200` is denied by policy before the source is called and exits `1`.
`--simulate-failure` reads once, reports `DOCUMENT_INDEX_UNAVAILABLE`, and exits
`1`. The package also has a Go test
(`go test ./language/go/Tutorial/litigation-timeline`).

`read_documents` returns 3 documents, 4 events and one contradiction between
`doc-1` and `doc-3`; `draft_outline` returns `timeline_events=4`, `flagged=1`,
`status=draft_only`, `review_required=true`, `legal_advice=0` and
`admissibility=0`. Policy limits the matter and final `draft_timeline` action.

Real evidence handling, privilege review, legal analysis and admissibility
belong to counsel.
