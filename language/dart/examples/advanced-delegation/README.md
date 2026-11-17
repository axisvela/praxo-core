# Dart Advanced Delegation

This example shows an application-level parent/child agent pattern combined with
six governance negative checks.

```bash
dart run language/dart/examples/advanced-delegation/delegation.dart
dart run language/dart/examples/advanced-delegation/governance.dart
```

Expected output:

```text
delegation: child recorded; parent scope enforced
deny: parent record blocked; child effect unchanged
Dart advanced delegation governance: 6/6 passed
```

The governance checks cover child scope narrowing, parent/child policy
composition, shared sibling budgets, child-count and depth limits, cancellation
before effects, and final-argument reauthorization. They are application-owned;
the Core does not inherit authority automatically.
