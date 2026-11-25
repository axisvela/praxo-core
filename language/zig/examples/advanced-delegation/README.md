# Zig Advanced Delegation

Application-level parent/child delegation plus six governance negative checks.

From `language/zig/`:

```bash
zig build-exe --dep praxo \
  -Mroot=language/go/examples/advanced-delegation/delegation.zig \
  -Mpraxo=src/praxo.zig -O ReleaseSafe -femit-bin=build/praxo-zig-delegation
./build/praxo-zig-delegation

zig build-exe --dep praxo \
  -Mroot=language/go/examples/advanced-delegation/governance.zig \
  -Mpraxo=src/praxo.zig -O ReleaseSafe -femit-bin=build/praxo-zig-governance
./build/praxo-zig-governance
```

On Windows, rename or copy the emitted binary to `.exe` before running it.

Expected output:

```text
delegation: child recorded; parent scope enforced
deny: parent record blocked; child effect unchanged
Zig advanced delegation governance: 6/6 passed
```

The checks cover child scope narrowing, parent/child policy composition, shared
sibling budgets, child-count and depth limits, cancellation before effects, and
final-argument reauthorization. They are application-owned; the Core does not
inherit authority automatically.
