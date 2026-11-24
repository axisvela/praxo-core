# Perl news fact-check (MD-02)

A bounded first slice of MD-02, not a truth-verification service. It compares
fixed source excerpts for one synthetic article, cites a contradiction and
drafts a review-only fact-check. No live news crawl, publish or truth guarantee.

Run from the repository root:

```bash
perl language/perl/Tutorial/news-factcheck/app.pl --test
perl language/perl/Tutorial/news-factcheck/app.pl
perl language/perl/Tutorial/news-factcheck/app.pl --article article-200
perl language/perl/Tutorial/news-factcheck/app.pl --simulate-failure
```

Expected test output: `perl news-factcheck tutorial: all checks passed`.
Both negative commands exit nonzero.

`compare_sources` returns two fixed claims with one contradiction
(`source-2`), two sources and `confidence=uncertain` for `article-100`;
`draft_factcheck` returns `status=draft_only`, `review_required=1`,
`truth_verdicts=0` and `publishes=0`. Policy limits the article and final
`draft_review` action. The Perl Core reports a policy denial as `POLICY_ERROR`.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-article denial, and one read/zero drafts for the simulated source-index
outage. Real source retrieval, editorial judgment and publication belong to the
consumer.
