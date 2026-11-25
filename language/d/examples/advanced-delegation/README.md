# D Advanced Delegation

Application-level parent/child delegation plus six governance negative checks.

```bash
dmd -i -Isource -O -release language/go/examples/advanced-delegation/delegation.d -of=build/praxo-d-delegation.exe
./build/praxo-d-delegation

dmd -i -Isource -O -release language/go/examples/advanced-delegation/governance.d -of=build/praxo-d-governance.exe
./build/praxo-d-governance
```

Expected output:

```text
delegation: child recorded; parent scope enforced
deny: parent record blocked; child effect unchanged
D advanced delegation governance: 6/6 passed
```

The checks cover child scope narrowing, parent/child policy composition, shared
sibling budgets, child-count and depth limits, cancellation before effects, and
final-argument reauthorization. They are application-owned; the Core does not
inherit authority automatically.
