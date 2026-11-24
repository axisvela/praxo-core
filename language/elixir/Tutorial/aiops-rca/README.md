# Elixir AIOps RCA (SE-06)

Fixed trace/metric/log signals yield suspect `checkout-api` and a review-only
rollback. No live telemetry or remediation.

## Why this language and runtime?

Elixir/BEAM fits concurrent operations services; the tutorial exercises the RCA
and draft boundary in that runtime.

Evidence limit: fixed signals only; no live telemetry, root-cause scoring,
remediation or supervision claim.
