# PHP localization draft (CS-07)

A bounded first slice of [CS-07](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a legal or tax compliance system. It compares fixed localization rules and
drafts review-only localized product text. No legal/tax guarantee, live content
system or publication.

## Why this language and runtime?

- **Selection basis:** A PHP commerce or CMS portal can keep localization review beside
  its content pipeline. No localization vendor is verified.
- **Demonstrated fit:** Fixed market rules and a review-only localized draft are
  returned; no translation engine or publishing call runs.
- **Choose when:** Learning the tool/policy seam in an existing PHP content workflow.
- **Do not choose when:** Seeking translation quality or legal/tax validation. Compare
  localization platforms and the existing review process first.
- **Evidence limit:** Core integration fixture only; no translation engine, legal
  review, tax compliance, CMS write or publication.

Run from the repository root:

```bash
php language/php/Tutorial/localization-draft/app.php --test
php language/php/Tutorial/localization-draft/app.php
php language/php/Tutorial/localization-draft/app.php --product product-200
php language/php/Tutorial/localization-draft/app.php --simulate-failure
```

Expected test output: `PHP CS-07 localization-draft tutorial: success, denial and dependency failure passed`.
Both negative commands exit nonzero.

`read_terms` returns market `de` and rules `formal-address`/`unit-cm` for
`product-100`; `draft_localization` returns two segments with
`status=draft_only`, `review_required=true`, `legal_guarantees=0` and
`tax_claims=0`. Policy limits the product and final `draft_localized` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-product denial, and one read/zero drafts for the simulated terms-index
outage. Real translation quality, legal review and tax compliance belong to the
consumer.
