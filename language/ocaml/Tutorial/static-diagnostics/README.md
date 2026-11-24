# OCaml Static Diagnostics Review (SE-05)

A bounded static-analysis review tutorial. It parses structured diagnostic lines,
counts high/low rules and returns source locations. Core chooses a review level from
the actual counts and drafts findings without editing source.

## Why this language and runtime?

- **Selection basis:** OCaml is used for compilers, analyzers and typed syntax tools,
  where structured diagnostics and source locations are first-class data.
- **Demonstrated fit:** `split_colon` parses actual `file:line:rule:message` records;
  malformed lines return a typed parse error, and clean input changes the review
  branch from high to low.
- **Choose when:** An existing OCaml analyzer needs a governed review boundary.
- **Do not choose when:** A full analyzer, security scanner or license audit is needed.
  This does not parse OCaml source or perform AST analysis.
- **Evidence limit:** Tiny line format and fixture only; no compiler integration,
  parser combinators, security completeness, patch generation or live model.

## Run

From **this directory**:

```bash
ocaml unix.cma review.ml --test
ocaml unix.cma review.ml
ocaml unix.cma review.ml --scope repo-200
ocaml unix.cma review.ml --invalid
ocaml unix.cma review.ml --simulate-failure
```

Expected test output ends with:

```text
OCaml static-diagnostics tutorial: all checks passed
```

Default diagnostics contain 3 records: 2 `unsafe_shell` (high) and 1 `missing_test`;
the review action is `review_high`. Clean input produces `review_low`. Tests also
cover scope denial, source failure and a malformed diagnostic line.
