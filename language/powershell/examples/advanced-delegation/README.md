# PowerShell Advanced Delegation

Application-level parent/child delegation plus six governance negative checks.

From `language/powershell/`:

```powershell
pwsh -NoProfile -File examples/advanced-delegation/governance.ps1
```

Expected output:

```text
PowerShell advanced delegation governance: 6/6 passed
```

The checks cover child scope narrowing, parent/child policy composition, shared
sibling budgets, child-count and depth limits, cancellation before effects, and
final-argument reauthorization. They are application-owned; the Core does not
inherit authority automatically.
