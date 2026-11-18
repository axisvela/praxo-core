# MATLAB / Octave Advanced Delegation

Application-level parent/child delegation plus six governance negative checks.

From the repository root:

```bash
octave-cli language/octave/examples/advanced-delegation/run_delegation.m
octave-cli language/octave/examples/advanced-delegation/run_governance.m
```

Expected output:

```text
delegation: child recorded; parent scope enforced
deny: parent record blocked; child effect unchanged
MATLAB/Octave advanced delegation governance: 6/6 passed
```

The checks cover child scope narrowing, parent/child policy composition, shared
sibling budgets, child-count and depth limits, cancellation before effects, and
final-argument reauthorization. They are application-owned; the Core does not
inherit authority automatically. Native MATLAB execution remains unverified.
