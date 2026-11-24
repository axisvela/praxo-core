# R Compliance Tracking (FC-06)

Compares fixed policy versions and drafts review-only remediation. No audit
conclusion or submission.

## Why this language and runtime?

- **Selection basis:** R often supports control testing and policy analytics; the
  comparison can stay beside existing scripts.
- **Demonstrated fit:** Native R reports two changed controls, one missing
  control and a draft-only remediation.
- **Choose when:** Adding a read-only policy diff to an R compliance workflow.
- **Do not choose when:** Seeking audit assurance or automatic filing. Compare
  the control framework and reviewer process first.
- **Evidence limit:** Two fixed policy versions only; no repository, audit
  opinion or submission.

## Run

```bash
Rscript language/r/Tutorial/compliance-tracking/compliance_tracking.R --test
```

Expected output:

```text
R compliance-tracking tutorial: all checks passed
```

No audit conclusion, filing or control change is implemented. Evidence and
approval belong to the consumer.
