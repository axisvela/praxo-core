# Haskell Advanced Delegation

Application-level parent/child delegation plus six governance negative checks.

From `language/haskell/`:

```bash
ghc -isrc examples/advanced-delegation/delegation.hs -o build/praxo-hs-delegation
./build/praxo-hs-delegation
ghc -isrc examples/advanced-delegation/governance.hs -o build/praxo-hs-governance
./build/praxo-hs-governance
```

Expected output:

```text
delegation: child recorded; parent scope enforced
deny: parent record blocked; child effect unchanged
Haskell advanced delegation governance: 6/6 passed
```

The checks cover child scope narrowing, parent/child policy composition, shared
sibling budgets, child-count and depth limits, cancellation before effects, and
final-argument reauthorization. They are application-owned; the Core does not
inherit authority automatically.
