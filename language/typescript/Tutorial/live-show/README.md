# TypeScript Live Show (MD-07)

Replays fixed engagement events and drafts a review-only running order. No
audience profiling, coupon sends or stream control.

## Why this language and runtime?

- **Selection basis:** TypeScript fits live-production dashboards; the order
  review can stay in the existing operator app.
- **Demonstrated fit:** Five fixed events yield a draft-only three-segment order
  with no profiling.
- **Choose when:** Evaluating an operator-review seam before a live show.
- **Do not choose when:** Seeking stream control or audience profiling. Compare
  platform APIs and consent rules first.
- **Evidence limit:** Five fixed events only; no live stream, viewer identity,
  coupon or profiling claim.

## Run

```bash
npm ci
npm test
```

Expected output:

```text
TypeScript MD-07 live-show tutorial: all checks passed
```

No stream control, coupon send or audience profile is implemented. Operator
approval and consent belong to the consumer.
