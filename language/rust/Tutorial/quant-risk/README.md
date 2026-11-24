# Rust Quant Risk (FC-02)

Replays fixed prices, enforces a deterministic exposure limit and drafts a
review-only order. No trade or latency claim.

## Why this language and runtime?

- **Selection basis:** Rust fits deterministic risk checks near execution
  tooling without a runtime.
- **Demonstrated fit:** Fixed exposure 120 exceeds limit 100 and drafts a
  review-only reduction with zero trades.
- **Choose when:** Evaluating a pre-trade risk seam under fixed limits.
- **Do not choose when:** Seeking execution or millisecond guarantees. Compare
  the risk engine and broker controls first.
- **Evidence limit:** Fixed prices only; no market feed, order router, trade or
  latency measurement. Local validation used `cargo check`; CI is configured and
  pending.

## Run

```bash
cargo run --quiet --locked -- --test
```

Expected output:

```text
success: portfolio-100 exposure=120 limit=100 status=draft_only trades=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: PRICE_DATA_UNAVAILABLE reads=1
```

No trade or order submission is implemented. Risk approval belongs to the
consumer.
