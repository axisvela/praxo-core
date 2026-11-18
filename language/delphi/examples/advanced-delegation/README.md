# Delphi / Free Pascal Advanced Delegation

Application-level parent/child delegation plus six governance negative checks.

From `language/delphi/`:

```bash
fpc -Mobjfpc -Scghi -O2 -Fu. -FEbuild examples/advanced-delegation/governance.pas
./build/governance
```

Expected output:

```text
Delphi advanced delegation governance: 6/6 passed
```

The checks cover child scope narrowing, parent/child policy composition, shared
sibling budgets, child-count and depth limits, cancellation before effects, and
final-argument reauthorization. They are application-owned; the Core does not
inherit authority automatically. Validated with Free Pascal 3.2.2; commercial
Delphi compatibility remains unverified.
