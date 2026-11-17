# Nim Advanced Delegation

This example shows an application-level parent/child agent pattern combined with
six governance negative checks.

```bash
nim c --path:language/nim/src --hints:off \
  -o:build/praxo-nim-delegation language/nim/examples/advanced-delegation/delegation.nim
./build/praxo-nim-delegation

nim c --path:language/nim/src --hints:off \
  -o:build/praxo-nim-governance language/nim/examples/advanced-delegation/governance.nim
./build/praxo-nim-governance
```

Expected output:

```text
delegation: child recorded; parent scope enforced
deny: parent record blocked; child effect unchanged
Nim advanced delegation governance: 6/6 passed
```

The governance checks cover child scope narrowing, parent/child policy
composition, shared sibling budgets, child-count and depth limits, cancellation
before effects, and final-argument reauthorization. They are application-owned;
the Core does not inherit authority automatically.
