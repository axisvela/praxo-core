# COBOL Budget Review (CT-07)

Flags fixed budget variances and milestone mismatches. No audit conclusion or
official determination.

## Why this language and runtime?

- **Selection basis:** Public-budget execution reports often come from COBOL
  batches; the variance check can stay near the source records.
- **Demonstrated fit:** Three fixed items produce two review flags, including a
  milestone mismatch with zero variance.
- **Choose when:** Adding a variance pre-check before human budget review.
- **Do not choose when:** Seeking an audit conclusion or official finding.
  Compare the finance rulebook and existing review first.
- **Evidence limit:** Three synthetic items only; no ledger, official audit or
  jurisdictional rule claim.

## Run

```bash
python language/cobol/Tutorial/budget-review/run.py
```

Expected output:

```text
item=B1 variance=+000000800 status=review
item=B2 variance=-000000200 status=ok
item=B3 variance=+000000000 status=review
total=0003 flagged=0002
COBOL CT-07 budget review tutorial: passed (variance flags only, no audit conclusion)
```

No audit conclusion, official finding or budget adjustment is implemented.
