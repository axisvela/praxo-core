# D Quantitative Risk (FC-02)

A bounded first slice of [FC-02](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a trading or execution system. It reads fixed portfolio/market data, computes
proposed-order exposure, enforces a stated risk limit outside the agent, and drafts
a review-only order. No trades, live market feed or latency claim.

Run from the repository root:

```bash
dmd -i -Ilanguage/d/source -run language/d/Tutorial/quant-risk/risk.d --test
dmd -i -Ilanguage/d/source -run language/d/Tutorial/quant-risk/risk.d
dmd -i -Ilanguage/d/source -run language/d/Tutorial/quant-risk/risk.d --account account-200
dmd -i -Ilanguage/d/source -run language/d/Tutorial/quant-risk/risk.d --simulate-failure
```

Expected test output:

```text
success: account-100 exposure=10000 within_limit=false status=draft_only trades=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: MARKET_DATA_UNAVAILABLE reads=1
```

Both negative commands exit nonzero.

`read_portfolio` returns 100 shares at price 50, a 5000 risk limit, a 200-share
proposed order, `exposure=10000` and `within_limit=false`; `draft_order` returns
`status=draft_only`, `review_required=true` and `trades_executed=0`. The D Core
policy exposes only the action kind, so account and final-action checks run inside
the tool seams before counters. `requirePolicy` and `requireToolScope` are enabled.

No brokerage, market data, position mutation, order routing or risk-engine
certification exists. Approval, staged execution and effect reconciliation belong
to the consumer.
