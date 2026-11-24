# PHP copyright evidence (LJ-05)

A bounded first slice of [LJ-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a rights-enforcement service. It compares fixed authorized assets and drafts
a review-only evidence packet. No broad crawl, automatic DMCA notice or
infringement adjudication.

## Why this language and runtime?

- **Selection basis:** A PHP media or rights portal can keep evidence review beside its
  existing asset records. No rights-holder consumer is verified.
- **Demonstrated fit:** Fixed asset matches and a review-only evidence packet are
  produced; no crawl, notice filing or adjudication runs.
- **Choose when:** Learning the Core seam in an existing PHP content workflow.
- **Do not choose when:** Seeking infringement detection or takedown automation.
  Compare rights-management systems and counsel processes first.
- **Evidence limit:** Core integration fixture only; no crawl, DMCA notice, takedown,
  ownership proof or infringement judgment.

Run from the repository root:

```bash
php language/php/Tutorial/copyright-evidence/app.php --test
php language/php/Tutorial/copyright-evidence/app.php
php language/php/Tutorial/copyright-evidence/app.php --asset asset-200
php language/php/Tutorial/copyright-evidence/app.php --simulate-failure
```

Expected test output: `PHP LJ-05 copyright-evidence tutorial: success, denial and dependency failure passed`.
Both negative commands exit nonzero.

`read_assets` returns 2 fixed assets with 1 match, `restricted` license and US
jurisdiction for `asset-100`; `draft_packet` returns two evidence items with
`status=draft_only`, `review_required=true`, `dmca_notices=0` and
`adjudications=0`. Policy limits the asset and final `draft_evidence` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-asset denial, and one read/zero drafts for the simulated asset-index
outage. Real crawling, notice filing, takedown and legal judgment belong to the
rights holder and counsel.
