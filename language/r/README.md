# PRAXO-CORE R Core

R implementation of the PRAXO-CORE contract.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.5.0`
- Tier: core
- License: MIT
- Dependencies: none (base R JSON parser/serializer)

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/r/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/r/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/r/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [r-universe](https://axisvela.r-universe.dev/praxocore)

## Scope

`0.5.0` implements all eleven conformance vector groups: tool-call parsing, JSON
Schema, plugin manifests, memory, events, stream kinds, checkpoint envelopes,
path policy, context budgets, middleware, the agent loop, and human-in-the-loop
interrupt decisions. Provider adapters remain follow-up work.

## OpenAI-Compatible Adapter

`R/openaicompat.R` adds a non-streaming OpenAI-compatible adapter over the
native model seam. It posts to `{base_url}/chat/completions` and maps assistant
content, tool calls, and token usage. Supply `transport` to run without network
access; the function receives `(path, payload)` and returns decoded JSON.

```r
adapter <- openai_compatible("https://api.example.com/v1", "model-id",
                             api_key = Sys.getenv("API_KEY"))
result <- openai_compatible_generate(adapter, request(
  messages = list(message(roles$user, "hi"))
))
model <- openai_compatible_model(adapter)
```

Provider HTTP failures raise `praxo_error` with code `PROVIDER_HTTP`; invalid
tool-argument JSON raises `PROVIDER_JSON`. Streaming is not implemented.

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

Tag shape: `r/v0.5.0`. The tag targets `SPEC_VERSION` `0.2.0`. r-universe
builds from the repository; CRAN submission uses `R CMD check --as-cran`. See
[PUBLISHING.md](PUBLISHING.md) and [CHANGELOG.md](CHANGELOG.md).
