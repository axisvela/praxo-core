# TypeScript Tutorials

Application-shaped tutorials live here, alongside `examples/`, which keeps
mechanism checks and focused integration examples. Tutorial is intentionally
capitalized in directory paths.

- [Order support](order-review/README.md): native Core, policy and HTTP tools over
  a shared synthetic service; deterministic slice, not a Web frontend.
- [Customer support](customer-support/README.md): native Core, fixed order/policy
  tools, SSE streaming and loopback HTTP; no reply sends or live model.
- [Travel booking](travel-booking/README.md): native Core, fixed inventory and a
  review-only fare hold; no payment, ticketing or inventory write.
- [Retail replenishment](retail-replenishment/README.md): native Core, fixed stock
  and pricing fixture with a review-only purchase-order draft.

Shared business backends live in the public
[agent-tutorial-services](https://github.com/axisvela/agent-tutorial-services)
repository; they are not part of the Core package or wire spec.
