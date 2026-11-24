# Python Credit Diligence (FC-03)

A bounded first slice of [FC-03](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a credit decision or fraud adjudication system. It computes fixed ratios for
one synthetic applicant and drafts a review-only memo. No bureau call, decision or
live model is used.

## Why this language and runtime?

- **Selection basis:** Python fits finance analytics and diligence workflows that
  already compute ratios and draft memos from structured data.
- **Demonstrated fit:** Fixed records are reconciled and a review-only credit memo is
  drafted; no credit decision or market feed is involved.
- **Choose when:** Learning evidence and review boundaries in an existing Python tool.
- **Do not choose when:** Seeking credit approval or fraud adjudication. Compare the
  bank's underwriting rules, risk models and compliance process first.
- **Evidence limit:** Core integration fixture only; no live financial data, credit
  decision, fraud verdict, regulatory approval or advice.

From this directory:

```bash
python -m pip install -r requirements.txt
python app.py --test
python app.py
python app.py --applicant applicant-200
python app.py --simulate-failure
```

Expected test output: `Python FC-03 credit-diligence tutorial: all checks passed`.
Both negative commands exit nonzero.

`read_financials` returns revenue 1,200,000, debt 900,000, `debt_ratio=0.75`,
related-party ratio 0.21, two delinquencies and `risk=elevated`;
`draft_memo` returns `status=draft_only`, `review_required=true` and
`credit_decisions=0`. Policy limits the applicant and final `review_only` action;
`require_policy` and `require_tool_scope` are enabled.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-applicant denial, and one read/zero drafts for the simulated bureau outage.
Real bureau data, KYC, fraud graphs, credit policy and decisions belong to the
consumer. No production credit decision is claimed.
