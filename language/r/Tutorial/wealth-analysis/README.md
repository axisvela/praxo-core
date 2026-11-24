# R wealth analysis

A native R Core tutorial for review-only portfolio analysis. It computes
weighted risk and concentration over a fixed `acct-100` fixture, recommends a
rebalance, and drafts a review-only proposal that executes no trades. The model
packages computed evidence instead of inventing numbers. This tutorial does not
trade, transfer cash, use market data, read arbitrary files or call a live model.

## Why this language and runtime?

- **Selection basis:** An R analytics workflow can keep portfolio calculations and
  the review boundary in one statistical runtime. No wealth-management consumer is
  verified here.
- **Demonstrated fit:** Native R computes weights, weighted risk and concentration
  from a fixed portfolio; the test checks the numbers and draft-only output.
- **Choose when:** Exploring a review workflow around calculations already in R.
- **Do not choose when:** Seeking investment advice, market integration or validated
  risk models. A direct R analysis may suffice without an Agent.
- **Evidence limit:** Native calculation plus Core integration on a tiny fixture;
  no market data, trading, suitability assessment or advisory claim.

Run from the repository root:

```bash
Rscript language/r/Tutorial/wealth-analysis/wealth.R --test
Rscript language/r/Tutorial/wealth-analysis/wealth.R
Rscript language/r/Tutorial/wealth-analysis/wealth.R --account acct-200
Rscript language/r/Tutorial/wealth-analysis/wealth.R --simulate-failure
```

Expected test output:

```text
R wealth-analysis tutorial: all checks passed
```

`--account acct-200` is denied by policy before the analysis tool runs (reads=0)
and exits non-zero. `--simulate-failure` reads once, reports the failure and exits
non-zero.

## Path

1. `analyze_portfolio` computes total value `100000`, weighted risk `0.54`,
   concentration `0.60` and per-asset weights over three fixed holdings, then
   recommends `rebalance`.
2. `draft_rebalance` returns `status=draft_only`, `review_required=true` and
   `trades_executed=0`.
3. The deterministic model packages both tool results into a JSON report with
   `trades_executed=0`.

The application owns suitability checks, approvals, order routing, settlement and
any real trade.

## Scope

This is source and local fixture evidence. It does not establish a real portfolio,
market data feed, trading system, financial advice, live provider, public hosting
or independent adoption. The tools and report fields are tutorial-local and are
not Core or wire API.
