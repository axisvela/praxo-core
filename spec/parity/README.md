# Per-Language Parity Inventories

`spec/parity.md` remains the inventory for the original core languages. New
languages add a file here.

Each file declares:

```text
- Tier: core | wire | bridge | sample
- SPEC_VERSION: <contract version>

| Go symbol | <Language> symbol | Status | Phase |
```

Status values: `planned`, `partial`, `parity`, `n/a`.
Phase values: `P1`, `P2`, `P3`, `P4`, `n/a`.

Rules:

- A `parity` row must name a language symbol.
- Every Go symbol must exist in `api/<version>.txt`.
- A language may declare no rows while it is planned.
- The Go linter validates structure; the language SDK validates behavior with
  `spec/vectors`.
