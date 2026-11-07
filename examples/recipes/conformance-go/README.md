# Adapter Conformance Recipe (Go)

This recipe uses `pkg/conformance` to validate custom model, streaming model,
tool, and retriever adapters against deterministic expectations. It runs without
provider credentials, network services, or a model.

**Evidence level: L1 contract/unit recipe.** It validates the adapter contracts
in `pkg/model`, `pkg/tool`, and `pkg/retriever`; it does not prove live provider
behavior, production credentials, or end-to-end agent quality. See the
[test and evidence taxonomy](../../../docs/project/test-taxonomy.md).

Run from this directory:

```sh
GOWORK=off go test -mod=readonly -run Conformance -v ./...
```

The checks are:

- `conformance.CheckModel` / `CheckStreamingModel` for generation and stream deltas.
- `conformance.CheckTool` for tool name, spec consistency, and invocation.
- `conformance.CheckRetriever` for retrieval results and result limits.

The recipe also asserts that mismatched expectations fail, so a passing run is
not just a happy-path smoke test. From the repository root,
`python scripts/test_go_conformance_recipe.py -v` repeats the checks in a fresh
temporary module using the published package.
