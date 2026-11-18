# Swift Advanced Delegation

Application-level parent/child delegation plus six governance negative checks.

From `language/swift/` (or the repository root with `--package-path`):

```bash
swift run --package-path language/swift praxo-governance-example
```

Expected output:

```text
Swift advanced delegation governance: 6/6 passed
```

The checks cover child scope narrowing, parent/child policy composition, shared
sibling budgets, child-count and depth limits, cancellation before effects, and
final-argument reauthorization. They are application-owned; the Core does not
inherit authority automatically.
