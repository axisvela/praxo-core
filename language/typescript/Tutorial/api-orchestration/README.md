# TypeScript API orchestration (SE-08)

A bounded first slice of [SE-08](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an integration platform. It maps two fixed synthetic APIs, validates the order
schema, and either drafts a review-only mapping or stops on a schema mismatch. No
network, credentials or partner system is accessed.

## Why this language and runtime?

- **Selection basis:** TypeScript/Node is commonly used for API gateways and
  integration services, where schema validation and orchestration logic already live.
- **Demonstrated fit:** Two async SDK tools return fixed customer/order responses; the
  model branches on schema validity and drafts only when reconciliation succeeds.
- **Choose when:** Learning an orchestration and validation boundary in an existing
  Node service.
- **Do not choose when:** Seeking live partner calls or retry semantics. Compare the
  existing integration layer, schema validator and failure policy first.
- **Evidence limit:** Fixed API fixtures only; no HTTP, credentials, retry, idempotency,
  partner sandbox or production integration.

From this directory:

```bash
npm ci
npm test
node app.js
node app.js --mismatch
node app.js --customer customer-200
node app.js --simulate-failure
```

Expected test output: `TypeScript api-orchestration tutorial: all checks passed`.
Negative commands exit nonzero.

The success path reads one customer and one order, validates `amount` as numeric, and
drafts `status=draft_only` with `writes=0`. `--mismatch` returns
`stage=schema_mismatch` with no draft. Policy limits both API identifiers and the
mapping action.
