# OCaml Representative Chain

Deterministic representative chain covering MCP record, final-argument
authorization, governed child delegation, OTel/Harmovela events, and an edited
denial with zero effects.

From `language/ocaml/`:

```bash
ocamlc -c src/praxo_core.mli
ocamlc -c src/praxo_core.ml
ocamlc -I src src/praxo_core.cmo language/go/examples/representative-chain/chain.ml -o build/praxo-ocaml-chain
ocamlrun build/praxo-ocaml-chain
```

Expected output:

```text
output: DONE
effects: parent=1 child=1
child calls: 2
otel spans: 10
harmovela events: 10
denied effects: 0
```

Deterministic models and in-memory transports only; no live provider, remote
MCP/Harmovela, identity, isolation, exactly-once, or production evidence.
