# Python Clinical Guidelines (HC-01)

A bounded first slice of [HC-01](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not diagnosis or treatment advice. It retrieves fixed synthetic guideline
excerpts, cites the top match, drafts a review-only summary, and abstains when no
evidence matches. No patient records or live model are used.

From this directory:

```bash
python -m pip install -r requirements.txt
python app.py --test
python app.py
python app.py --query "unknown topic"
python app.py --scope private
python app.py --simulate-failure
```

Expected test output: `Python HC-01 clinical-guidelines tutorial: all checks passed`.
All four scenarios (success, abstain, denial, failure) are asserted.

`search_guidelines` returns `guideline-cardio` for the default query;
`draft_review` returns `status=draft_only`, `review_required=true` and
`clinical_decisions=0`. Policy limits the public scope and the final
`review_only` action. No matches returns `INSUFFICIENT_EVIDENCE` without drafting.
Tests also assert a private-scope denial with zero reads and a simulated index
outage after one read.

Real clinical records, guideline licensing, clinical validation and treatment
decisions belong to the consumer. No medical advice, diagnosis or production
clinical use is claimed.
