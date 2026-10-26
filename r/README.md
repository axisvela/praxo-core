# PRAXO-CORE R SDK

R implementation of the PRAXO-CORE wire contract.

- `SPEC_VERSION`: `0.2.0`
- SDK version: `0.1.0`
- Tier: wire (toolcall, JSON Schema, plugin manifest)
- License: MIT
- Dependencies: none (base R JSON parser/serializer)

## Scope

`0.1.0` implements the wire subset: tool-call parsing/stripping, the JSON
Schema subset, and plugin manifest validation. The core agent loop and provider
adapters are follow-up work.

## Build and test

```bat
Rscript r\conformance\run.R
Rscript r\tests\run_tests.R
```

Local toolchain used by the repository maintainers lives at `D:\dev\R`.

## Layout

- `R/` package source.
- `conformance/run.R` wire vector runner.
- `tests/run_tests.R` dependency-free tests.

## Release

Tag shape: `r/v0.1.0`. The tag targets `SPEC_VERSION` `0.2.0`.
