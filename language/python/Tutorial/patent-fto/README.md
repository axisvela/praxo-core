# Python patent FTO (LJ-02)

A bounded first slice of [LJ-02](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a freedom-to-operate or patentability opinion. It compares fixed synthetic
claims and drafts review-only questions for counsel. No live patent search, legal
advice or non-infringement conclusion.

## Why this language and runtime?

- **Selection basis:** A Python legal-operations workflow can add a review step around
  fixed research material. No patent or counsel consumer is verified.
- **Demonstrated fit:** Core tools return fixed claim-overlap counts and draft counsel
  questions; no patent corpus is searched or parsed.
- **Choose when:** Learning the Core seam in an existing Python research workflow.
- **Do not choose when:** Seeking FTO analysis or legal conclusions. Compare existing
  patent databases, claim charts and qualified counsel first.
- **Evidence limit:** Core integration fixture only; no exhaustive search, claim
  construction, legal opinion or infringement determination.

From this directory:

```bash
python app.py --test
python app.py
python app.py --portfolio portfolio-200
python app.py --simulate-failure
```

Expected test output: `Python LJ-02 patent-fto tutorial: all checks passed`.
Both negative commands exit nonzero.

`compare_claims` returns 3 families, 2 overlapping claims, 1 expiring soon and
jurisdictions US/EP for `portfolio-100`; `draft_counsel_questions` returns three
questions with `status=draft_only`, `review_required=true` and
`legal_opinions=0`. Policy limits the portfolio and final
`draft_counsel_questions` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-portfolio denial, and one read/zero drafts for the simulated patent-index
outage. Exhaustive search, claim-chart analysis and legal opinions belong to
qualified counsel.
