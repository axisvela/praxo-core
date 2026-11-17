# Julia Advanced Delegation

Application-level parent/child delegation plus six governance negative checks.

```bash
julia --project=language/julia language/julia/examples/advanced-delegation/delegation.jl
julia --project=language/julia language/julia/examples/advanced-delegation/governance.jl
```

Expected output:

```text
delegation: child recorded; parent scope enforced
deny: parent record blocked; child effect unchanged
Julia advanced delegation governance: 6/6 passed
```

The checks cover child scope narrowing, parent/child policy composition, shared
sibling budgets, child-count and depth limits, cancellation before effects, and
final-argument reauthorization. They are application-owned; the Core does not
inherit authority automatically.
