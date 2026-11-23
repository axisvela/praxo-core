# TypeScript Retail Replenishment (CS-05)

A bounded first slice of [CS-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not live pricing or procurement. It checks a fixed SKU's stock and pricing fixture
and drafts a review-only purchase order. No network, credentials or live model are
used.

Run from this directory:

```bash
npm install --ignore-scripts --no-audit --no-fund
npm test
node app.js
node app.js --sku sku-200
node app.js --simulate-failure
```

Expected test output:

```text
TypeScript retail-replenishment tutorial: all checks passed
```

Both negative commands exit nonzero.

The deterministic model plans three steps and consumes each result:
`check_inventory` returns stock `4`, reorder point `10`, needs-replenishment
`true`, suggested quantity `27` and a competitor gap; `draft_purchase_order`
returns `status=draft_only`, `review_required=true`, `orders_sent=0` and
`quantity=27`. Policy limits the SKU and the final `replenish` action;
`requirePolicy` and `requireToolScope` are enabled.

Tests assert one inventory read and one draft on success, zero reads/drafts for a
cross-SKU denial, and one read/zero drafts for the simulated inventory outage.

Real inventory, pricing, supplier APIs, approvals, idempotency and effect
reconciliation belong to the consumer. No live provider, publication, independent
consumer or production pricing change is claimed.
