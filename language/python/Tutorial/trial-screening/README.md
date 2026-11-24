# Python Trial Screening (HC-03)

A bounded first slice of [HC-03](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not patient recruitment or eligibility adjudication. It evaluates fixed synthetic
patients against trial criteria and drafts a review-only screening note. No real
patient data, enrollment or live model.

## Why this language and runtime?

- **Selection basis:** A Python clinical-data workflow can keep screening evidence and
  the review boundary together. No patient or trial consumer is verified.
- **Demonstrated fit:** Core tools evaluate three fixed synthetic patients against
  simple criteria and draft a screening note.
- **Choose when:** Learning the tool/policy seam beside existing Python data handling.
- **Do not choose when:** Seeking eligibility adjudication or patient search. Compare
  deterministic criteria code and the existing clinical system first.
- **Evidence limit:** Synthetic fixture and Core integration; no real patient data,
  consent workflow, validated eligibility logic, enrollment or clinical claim.

From this directory:

```bash
python -m pip install -r requirements.txt
python app.py --test
python app.py
python app.py --trial trial-200
python app.py --simulate-failure
```

Expected test output: `Python HC-03 trial-screening tutorial: all checks passed`.
Both negative commands exit nonzero.

`evaluate_eligibility` screens three patients, returns `eligible=["patient-1"]`,
excludes patient-2 (biomarker) and patient-3 (consent), and records one unknown
(`lab-availability`); `draft_screening` returns `status=draft_only`,
`review_required=true` and `enrollments=0`. Policy limits trial and final `screen`
action.

Tests assert one read and one draft on success, zero reads/drafts for a cross-trial
denial, and one read/zero drafts for the simulated criteria outage. Real patient
records, consent management, clinical eligibility and enrollment belong to the
consumer.
