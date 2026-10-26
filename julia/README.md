# PRAXO-CORE Julia SDK

Julia implementation of the PRAXO-CORE wire contract.

- `SPEC_VERSION`: `0.2.0`
- SDK version: `0.1.0`
- Tier: wire (toolcall, JSON Schema, plugin manifest)
- License: MIT
- Dependency: JSON.jl

## Scope

`0.1.0` implements the wire subset: tool-call parsing/stripping, the JSON
Schema subset, and plugin manifest validation. The core agent loop and provider
adapters are follow-up work.

## Build and test

```bash
julia --project=julia -e 'using Pkg; Pkg.instantiate()'
julia --project=julia julia/conformance/run.jl
julia --project=julia julia/test/runtests.jl
```

Local toolchain used by the repository maintainers lives at `D:\dev\julia`.

## Layout

- `src/` package source.
- `conformance/run.jl` wire vector runner.
- `test/runtests.jl` Julia test suite.

## Release

Tag shape: `julia/v0.1.0`. The tag targets `SPEC_VERSION` `0.2.0`.
