# PHP lead nurture (CS-02)

A bounded first slice of [CS-02](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an outreach-automation product. It ranks fixed synthetic business profiles and
drafts review-only opt-in outreach. No crawling, scraping or unsolicited sends.

## Why this language and runtime?

- **Selection basis:** A PHP CRM or marketing portal can keep lead review near existing
  campaign data. No marketing consumer is verified.
- **Demonstrated fit:** Fixed ranked leads and an opt-in draft are returned; no crawl,
  scoring model or send path runs.
- **Choose when:** Learning the Core seam in an existing PHP campaign workflow.
- **Do not choose when:** Seeking prospecting, consent enforcement or delivery. Compare
  the CRM's existing rules and consent records first.
- **Evidence limit:** Core integration fixture only; no scraping, enrichment, consent
  validation, send or conversion claim.

Run from the repository root:

```bash
php language/php/Tutorial/lead-nurture/app.php --test
php language/php/Tutorial/lead-nurture/app.php
php language/php/Tutorial/lead-nurture/app.php --campaign campaign-200
php language/php/Tutorial/lead-nurture/app.php --simulate-failure
```

Expected test output: `PHP CS-02 lead-nurture tutorial: success, denial and dependency failure passed`.
Both negative commands exit nonzero.

`read_leads` returns 3 leads ranked `lead-2`/`lead-1` with 1 opt-in for
`campaign-100`; `draft_outreach` returns one draft with `status=draft_only`,
`review_required=true`, `sends=0` and `crawls=0`. Policy limits the campaign and
final `draft_outreach` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-campaign denial, and one read/zero drafts for the simulated lead-index
outage. Real prospecting data, consent management and message delivery belong to
the consumer.
