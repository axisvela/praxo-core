# Objective-C Advanced Delegation

Application-level parent/child delegation plus six governance negative checks.

From `language/objc/`, compile all `src/Praxo*.m` files plus
`language/go/examples/advanced-delegation/governance.m` with the GNUstep flags from
`run-tests.py`, then run the binary with the GNUstep runtime directory on
`PATH`. Expected output:

```text
Objective-C advanced delegation governance: 6/6 passed
```

The checks cover child scope narrowing, parent/child policy composition, shared
sibling budgets, child-count and depth limits, cancellation before effects, and
final-argument reauthorization. They are application-owned; the Core does not
inherit authority automatically.
