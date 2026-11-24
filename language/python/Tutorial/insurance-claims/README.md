# Python insurance claims triage

A native Python Core tutorial for review-only claim triage. Two fixed tools read
a synthetic claim file and draft a decision; the deterministic model packages the
tool-computed risk and payout into a schema-validated report. `StructuredOutput`
rejects a malformed report before the application sees it. This tutorial does not
execute a payment, adjudicate coverage, read arbitrary files, call a live model or
mutate a policy.

## Why this language and runtime?

- **Selection basis:** Python fits claims triage and document workflows where existing
  extraction and rules already run.
- **Demonstrated fit:** A fixed claim produces a draft-only decision validated by
  `StructuredOutput`; no adjudication or payment executes.
- **Choose when:** Learning structured-output and review boundaries in a Python tool.
- **Do not choose when:** Seeking claim adjudication or fraud detection. Compare the
  insurer's rules engine, compliance process and existing models first.
- **Evidence limit:** Core integration fixture only; no real claim data, adjudication,
  payment, fraud verdict or regulatory compliance.

## Run

From this directory:

```bash
python -m pip install -r requirements.txt
python app.py --test
python app.py
python app.py --claim claim-200
python app.py --simulate-failure
```

Expected test output:

```text
Python insurance-claims tutorial: all checks passed
```

`claim-200` is denied by policy before the claim tool runs and exits non-zero. A
simulated claim-store failure returns an error after one read.

## Path

1. `read_claim` reads the fixed `claim-100` file, computes the usage ratio `0.85`
   and marks the claim `elevated` (high ratio, thin evidence, late reporting, a
   prior claim).
2. `draft_decision` returns `status=draft_only`, `review_required=true`,
   recommended payout `8500` and `payment_executed=false`.
3. The deterministic model emits a JSON report with `claim_id`, `risk_level`,
   `recommended_payout`, `requires_human_review` and `mutating_actions`.
   `StructuredOutput` validates the report against the schema, so a malformed or
   hand-waved answer raises `StructuredOutputError` instead of reaching the
   application.

The application owns approval, payment, effect reconciliation and any wire to a
real claims system.

## Scope

This is source, local fixture and local structured-output evidence. It does not
establish a real claims system, coverage decision, payment, live provider, public
hosting or independent adoption. The tools and report fields are tutorial-local
and are not Core or wire API.
