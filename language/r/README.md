# PRAXO-CORE R Core

R implementation of the PRAXO-CORE contract.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.5.0`
- Tier: core
- License: MIT
- Dependencies: none (base R JSON parser/serializer)

## Scope

`0.5.0` implements all eleven conformance vector groups: tool-call parsing, JSON
Schema, plugin manifests, memory, events, stream kinds, checkpoint envelopes,
path policy, context budgets, middleware, the agent loop, and human-in-the-loop
interrupt decisions. Provider adapters remain follow-up work.

## Build and test

```bat
Rscript r\conformance\run.R
Rscript r\api-snapshot.R --check
Rscript r\tests\run_tests.R
```

Local toolchain used by the repository maintainers lives at `D:\dev\R`.

## Layout

- `R/` package source.
- `conformance/run.R` vector runner.
- `api-snapshot.R` and `api/` public API snapshot.
- `tests/run_tests.R` dependency-free tests.

## Release

Tag shape: `r/v0.5.0`. The tag targets `SPEC_VERSION` `0.2.0`. See
[CHANGELOG.md](CHANGELOG.md) for per-release changes and compatibility notes.
