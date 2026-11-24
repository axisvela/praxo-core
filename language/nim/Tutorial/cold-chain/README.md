# Nim Cold-Chain Review (TL-04)

Computes fixed temperature excursions and drafts a review-only transfer. No
refrigeration change or clinical cargo guarantee.

## Why this language and runtime?

- **Selection basis:** A Nim utility can run beside logistics gateways without a
  larger runtime.
- **Demonstrated fit:** Native callbacks evaluate two fixed excursions and draft
  one transfer review.
- **Choose when:** Adding a review-only alert to an existing Nim shipment tool.
- **Do not choose when:** Seeking refrigeration control or cargo suitability
  certification. Compare cold-chain validation procedures first.
- **Evidence limit:** Fixed temperature series only; no logger, reefer control,
  spoilage model or clinical claim. Local validation used `nim check` only; CI is
  configured and pending.

## Build and run

```bash
nim check --path:language/nim/src --hints:off language/nim/Tutorial/cold-chain/coldchain.nim
nim c --path:language/nim/src --hints:off --out:build/nim-cold-chain language/nim/Tutorial/cold-chain/coldchain.nim
./build/nim-cold-chain --test
./build/nim-cold-chain
./build/nim-cold-chain --shipment shipment-200
./build/nim-cold-chain --simulate-failure
```

Expected test output:

```text
success: shipment-100 excursions=2 max_c=12 status=draft_only changes=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: TEMPERATURE_DATA_UNAVAILABLE reads=1
```

No logger ingestion, refrigeration change or cargo release is implemented.
Shipment identity, quality approval and effect reconciliation belong to the
consumer.
