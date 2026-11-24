# PHP customs reroute (TL-05)

A bounded first slice of [TL-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a customs-filing system. It validates fixed document fields, compares two
routes and drafts a review-only reroute. No customs filing, network access or
compliance determination.

## Why this language and runtime?

- **Selection basis:** A PHP logistics portal could keep a review workflow in its
  existing runtime rather than adding a separate Agent service.
- **Demonstrated fit:** PHP CLI tools and policy checks return fixed shipment data
  and a preselected reroute. No portal, document validator or route solver runs.
- **Choose when:** Learning native Core integration for an existing PHP application.
- **Do not choose when:** Seeking customs compliance or route optimization. Compare
  direct business rules and existing logistics services against actual requirements.
- **Evidence limit:** Core integration fixture only; no named consumer, web entry,
  customs API or comparative PHP advantage is established.

Run from the repository root:

```bash
php language/php/Tutorial/customs-reroute/app.php --test
php language/php/Tutorial/customs-reroute/app.php
php language/php/Tutorial/customs-reroute/app.php --shipment shipment-200
php language/php/Tutorial/customs-reroute/app.php --simulate-failure
```

Expected test output: `PHP TL-05 customs-reroute tutorial: success, denial and dependency failure passed`.
Both negative commands exit nonzero.

`read_shipment` returns 3 documents with `certificate-of-origin` missing and
routes `direct` (12 days)/`transship` (16 days) for `shipment-100`; `draft_customs`
returns `route=transship`, `status=draft_only`, `review_required=true` and
`filings=0`. Policy limits the shipment and final `draft_reroute` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-shipment denial, and one read/zero drafts for the simulated shipment-index
outage. Real document submission, customs compliance and route execution belong to
the consumer.
