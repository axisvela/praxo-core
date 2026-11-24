# PowerShell FinOps Review (SE-07)

A bounded cloud cost-review tutorial. It reads fixed resource costs, computes the
highest-cost resource below a 5% utilization threshold, and drafts a review-only
action. No cloud API is called and no resource is terminated.

## Why this language and runtime?

- **Selection basis:** PowerShell is common for Windows and cloud operations where
  cost reports and resource inventories are already queried.
- **Demonstrated fit:** Native PowerShell tooling reads fixed costs; the calculation
  selects `vm-1` at 420 under 5% utilization and chooses `review_termination`.
- **Choose when:** An existing PowerShell operations runbook needs a governed review
  seam for idle-resource cleanup.
- **Do not choose when:** Live cloud billing or resource mutation is required. Compare
  provider APIs and existing FinOps controls first.
- **Evidence limit:** Fixed resources only; no cloud credentials, billing API,
  termination, savings guarantee or live model.

## Run

From the repository root:

```powershell
pwsh -NoProfile -File language/powershell/Tutorial/finops-review/finops.ps1 -SourceMode -Test
pwsh -NoProfile -File language/powershell/Tutorial/finops-review/finops.ps1 -SourceMode
pwsh -NoProfile -File language/powershell/Tutorial/finops-review/finops.ps1 -SourceMode -Deny
pwsh -NoProfile -File language/powershell/Tutorial/finops-review/finops.ps1 -SourceMode -SimulateFailure
```

Expected test output:

```text
PowerShell SE-07 finops-review tutorial: success, denial and dependency failure passed
```

The success path reads once, drafts once, selects `vm-1`, and reports zero
terminations. `-Deny` is rejected before the cost tool runs; `-SimulateFailure`
returns `BILLING_UNAVAILABLE` after one read and no draft.
