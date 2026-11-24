# Go customs reroute

A scoped customs tutorial over the Go reference Core. It validates fixed document
fields for one shipment, compares two routes and drafts a review-only reroute. The
source and model are deterministic fixtures. This tutorial does not file customs
documents, call a live system or make a legal determination.

## Why this language and runtime?

- **Selection basis:** The reference Core suits Go logistics services that need one
  deployable binary and explicit application-owned boundaries.
- **Demonstrated fit:** Go tools validate fixed fields and draft a reroute; no customs
  API, filing, or route solver is invoked.
- **Choose when:** Learning the reference tool/policy loop for a shipment workflow.
- **Do not choose when:** Seeking customs compliance or route optimization. Compare
  direct business rules and existing logistics services first.
- **Evidence limit:** Core integration fixture only; no network access, filing,
  document validation quality or compliance determination.

Run from the repository root:

```bash
go run ./language/go/Tutorial/customs-reroute --test
go run ./language/go/Tutorial/customs-reroute --shipment shipment-200
go run ./language/go/Tutorial/customs-reroute --simulate-failure
```

Expected test output:

```text
success: shipment-100 documents=3 missing=1 route=transship status=draft_only filings=0 reads=1
deny: policy denied reads=0
failure: SHIPMENT_INDEX_UNAVAILABLE reads=1
```

`shipment-200` is denied by policy before the source is called and exits `1`.
`--simulate-failure` reads once, reports `SHIPMENT_INDEX_UNAVAILABLE`, and exits
`1`. The package also has a Go test
(`go test ./language/go/Tutorial/customs-reroute`).

`read_shipment` returns 3 documents with `certificate-of-origin` missing and
routes `direct` (12 days)/`transship` (16 days); `draft_customs` returns
`route=transship`, `status=draft_only`, `review_required=true` and `filings=0`.
Policy limits the shipment and final `draft_reroute` action.

Real document submission, customs compliance and route execution belong to the
consumer.
