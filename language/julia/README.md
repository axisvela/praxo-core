# PRAXO-CORE Julia Core

Julia implementation of the PRAXO-CORE contract.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.2.0`
- Tier: core
- License: MIT
- Dependency: JSON.jl

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](REGISTRY.md)
- Machine-readable entry: [llms.txt](llms.txt) and [llms.md](llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](../../docs/getting-started/coding-agents.md)
- Registry: [Julia General (pending)](https://github.com/axisvela/praxo-core-julia)

## Scope

`0.2.0` implements all eleven conformance vector groups: tool-call parsing, JSON
Schema, plugin manifests, memory, events, stream kinds, checkpoint envelopes,
path policy, context budgets, middleware, and the agent loop. Provider adapters
remain follow-up work.

## Build and test

```bash
julia --project=language/julia -e 'using Pkg; Pkg.instantiate()'
julia --project=language/julia language/julia/conformance/run.jl
julia --project=language/julia language/julia/api-snapshot.jl --check
julia --project=language/julia language/julia/test/runtests.jl
```

Local toolchain used by the repository maintainers lives at `D:\dev\julia`.

## Layout

- `src/` package source.
- `conformance/run.jl` vector runner.
- `api-snapshot.jl` and `api/` public API snapshot.
- `test/runtests.jl` Julia test suite.

## Release

Tag shape: `julia/v0.2.0`. The tag targets `SPEC_VERSION` `0.2.0`. The mirror `axisvela/praxo-core-julia` registers the package through
JuliaRegistrator; see [PUBLISHING.md](PUBLISHING.md).
