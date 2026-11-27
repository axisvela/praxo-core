# Java Wealth Review Service

A native Java Core tutorial for a review-only wealth workflow. The Agent has two
fixed tools: `read_portfolio` reads synthetic account `acct-100`, and
`draft_rebalance` produces a `draft_only` allocation proposal for human review.
It never places a trade, transfers cash or changes a portfolio.

## Why this language and runtime?

- **Selection basis:** Java fits enterprise wealth and banking services that already
  run on the JVM with HTTP entry, identity and mature tooling.
- **Demonstrated fit:** A Java service exposes risk analysis and a review-only proposal
  over a fixed portfolio; no market feed, transfer or trade executes.
- **Choose when:** Adding a governed review seam to an existing Java financial service.
- **Do not choose when:** Seeking market data, execution or advice. Compare the bank's
  risk engine, order controls and existing Java APIs first.
- **Evidence limit:** Fixed portfolio and HTTP demo; no live market data, trading,
  suitability assessment, regulatory approval or advisory claim.

## Run

Requires JDK 21+ and Maven. From this directory:

```bash
mvn -q test
mvn -q compile exec:java
```

The CLI prints JSON with `draft.status=draft_only`, the current/target equity
percentages, citations and an empty `executed_trades` list. It uses Maven Central
`com.axisvela:praxo-core:0.12.3`, with no local Core replacement.

## HTTP Entry

```bash
mvn -q compile exec:java -Dexec.args=--serve
```

The service binds to `127.0.0.1:8090`. Health is `GET /healthz`; the fixed review
route is `POST /review/acct-100`.

```bash
curl.exe -X POST http://127.0.0.1:8090/review/acct-100 -H "Authorization: Bearer demo-wealth-token"
```

Missing credentials return 401 before the Agent. A downstream failure returns
503. The fixture bearer token is not production authentication.

## What the Tests Cover

- Native Agent result: two fixed reads, `draft_only` status, `review_required`
  action, no executed trades.
- Account `acct-200` denied by Agent policy before tool execution.
- Simulated portfolio dependency failure returns an error and no successful report.
- Web boundary: health, missing-credential 401, authenticated 200 with a draft,
  and downstream 503.

## Boundaries

- The portfolio is synthetic and fixed; no real account, trade, transfer, market
  data or brokerage integration exists.
- The draft is advice for human review, not an order, transaction, suitability
  assessment or fiduciary recommendation.
- Identity, approvals, durable audit, retention, risk limits and effect
  reconciliation remain application-owned. This tutorial does not operate an
  identity provider or trading system.
- Local compilation is recorded, but this workstation's JVM launcher blocks
  runtime execution. Linux CI is the runtime gate.
- No live model, public hosting, production finance integration or independent
  consumer evidence is claimed.
