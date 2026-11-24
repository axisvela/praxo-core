# Order Support Agent

First deterministic native TypeScript Core integration slice. It shares the
synthetic order HTTP service with the Python example, not a remote Agent loop.
The `review_order` tool reads an order and creates a draft; final arguments are
restricted to `order-100` by Agent policy and checked again by service scope.

## Why this language and runtime?

- **Selection basis:** Node fits order-support APIs where HTTP handlers and the Agent
  can share one service process.
- **Demonstrated fit:** The tutorial exercises the shared synthetic orders service
  over loopback HTTP, with both Agent-policy and service-side denial paths.
- **Choose when:** Comparing the Node seam against the same business backend used by
  Python, Java and C# examples.
- **Do not choose when:** Seeking order mutation, refunds or production identity.
  Compare the existing order service and authorization model first.
- **Evidence limit:** Loopback demo backend and local tests; no production ERP, user
  identity, refund authority, hosted deployment or live model.

Clone the public [teaching backend](https://github.com/axisvela/agent-tutorial-services)
and run `python service/orders.py` from that repository in another terminal.
Then from this tutorial directory run:

```bash
npm ci
npm start
```

Output contains `draft_only`. Set `DEMO_ORDER=order-200` for Agent-side denial,
or `DEMO_TOKEN=demo-b-token` for independent service-side denial. Set
`DEMO_BASE_URL` to change the local business service origin.

This slice uses only a deterministic model, not a live provider or Web frontend.
The cross-language tests are in `agent-tutorial-services/tests/`. Core CI pins
the public backend revision and needs no private-repository token. Public source
availability is not a public hosted endpoint or independent reproduction claim.
Drafts are not refunds, durable operations, or production transactions. Shared
public tokens are fixture credentials only. Public hosting is not implemented.
