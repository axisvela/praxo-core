# COBOL Medical Coding Review (HC-04)

Checks three fixed records for completeness and drafts review-only codes. No
reimbursement optimization, billing submission or clinical decision.

## Why this language and runtime?

- **Selection basis:** Claims and record batches often remain in COBOL; a
  read-only quality check can sit beside that batch.
- **Demonstrated fit:** Fixed records yield two complete and one review case with
  draft-only codes and no submission.
- **Choose when:** Adding a record-completeness gate before a coding review.
- **Do not choose when:** Seeking reimbursement optimization or automatic coding.
  Compare coding policy and existing review first.
- **Evidence limit:** Three synthetic records only; no clinical validation, DRG
  grouper, payer rules or billing.

## Run

```bash
python language/cobol/Tutorial/medical-coding/run.py
```

Expected output:

```text
record=R1 complete=YES code=DRG-DRAFT-A status=draft_only
record=R2 complete=NO code=REVIEW status=review_required
record=R3 complete=YES code=DRG-DRAFT-A status=draft_only
total=0003 complete=0002 review=0001
COBOL HC-04 medical coding tutorial: passed (review-only draft codes)
```

No billing submission, reimbursement or clinical decision is implemented.
