# TypeScript localization draft (CS-07)

A bounded first slice of [CS-07](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a legal or tax compliance system. It compares fixed localization rules and
drafts review-only localized product text. No legal/tax guarantee, live content
system or publication.

## Why this language and runtime?

- **Selection basis:** A Node content service can keep localization review near its
  existing publishing code. No localization consumer is verified.
- **Demonstrated fit:** Core tools return fixed market rules and a draft; no content
  management system, translator or publication path is used.
- **Choose when:** Learning the tool/policy seam for a Node content workflow.
- **Do not choose when:** Seeking translation quality or legal/tax validation.
  Compare existing localization platforms and review processes first.
- **Evidence limit:** Core integration fixture only; no live content, legal review,
  tax compliance, publication or translation-quality claim.

From this directory:

```bash
npm ci
npm test
node app.js
node app.js --product product-200
node app.js --simulate-failure
```

Expected test output: `TypeScript localization-draft tutorial: all checks passed`.
Both negative commands exit nonzero.

`read_terms` returns market `de` and rules `formal-address`/`unit-cm` for
`product-100`; `draft_localization` returns two segments with
`status=draft_only`, `review_required=true`, `legal_guarantees=0` and
`tax_claims=0`. Policy limits the product and final `draft_localized` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-product denial, and one read/zero drafts for the simulated terms-index
outage. Real translation quality, legal review and tax compliance belong to the
consumer.
