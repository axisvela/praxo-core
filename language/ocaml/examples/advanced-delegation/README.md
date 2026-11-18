# OCaml Advanced Delegation

Application-level parent/child delegation plus six governance negative checks.

From `language/ocaml/`:

```bash
ocamlc -c praxo_core.mli
ocamlc -c praxo_core.ml
ocamlc -I . praxo_core.cmo examples/advanced-delegation/delegation.ml -o build/praxo-ocaml-delegation
ocamlrun build/praxo-ocaml-delegation
ocamlc -I . praxo_core.cmo examples/advanced-delegation/governance.ml -o build/praxo-ocaml-governance
ocamlrun build/praxo-ocaml-governance
```

Expected output:

```text
delegation: child recorded; parent scope enforced
deny: parent record blocked; child effect unchanged
OCaml advanced delegation governance: 6/6 passed
```

The checks cover child scope narrowing, parent/child policy composition, shared
sibling budgets, child-count and depth limits, cancellation before effects, and
final-argument reauthorization. They are application-owned; the Core does not
inherit authority automatically.
