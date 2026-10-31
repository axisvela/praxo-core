# PRAXO-CORE Haskell Core

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its
native Haskell Core. It implements all eleven declared vector groups and does not
call Go or another Core. It includes a native callback-based agent loop with
tools, policy hooks, typed events, memory, checkpoints, context budgets,
middleware, JSON Schema validation, plugin manifest parsing, and runtime helpers.

- Implementation type: Core.
- Package version: `0.2.0`; supported `SPEC_VERSION`: `0.2.0`.
- Local gate: all eleven shared vector groups, native regression tests, and
  source API/parity checks.
- Linux and Windows CI run the full suite. Hackage publication and production
  readiness are not implied by the source tag.

## Build and Test

Use GHC 9.0 or newer and Python 3.10 or newer. CI targets GHC 9.12.2 on Linux
and Windows. From the repository root:

```bash
python language/haskell/run-tests.py
python language/haskell/api-snapshot.py --check
```

Set `GHC` or pass `--compiler /path/to/ghc` to select the compiler. Python only
builds and launches the native programs; it does not implement their behavior.
Generated files stay under `language/haskell/build/`.

For a Cabal source build, from `language/haskell/`:

```bash
cabal build --offline all
cabal test --offline
cabal run --offline praxo-haskell-conformance -- ../../spec
```

The library depends only on GHC's `base` and `containers` packages. No provider,
JSON, or regular-expression package is downloaded by the native test driver.
Offline Cabal builds require those boot packages to be available with GHC.

## Usage

```haskell
import Praxo.Json
import Praxo.JsonSchema
import Praxo.ToolCall

main :: IO ()
main = do
    print (parseToolCall "{\"name\":\"echo\",\"input\":{\"text\":\"hello\"}}")
    print (validateSchema (JObject [("type", JString "string")]) (JNumber 42))
    print (encodeJson (JObject [("runId", JString "run-1")]))
```

Public declarations are inventoried in [`api/0.1.0.txt`](api/0.1.0.txt).
This is a source declaration check, not a binary ABI promise. Intentional API
changes require review and regeneration with `python api-snapshot.py`.

## Declared Scope and Limits

- JSON parsing is strict, rejects malformed escapes and lone surrogates, and
  bounds input to 1,048,576 Haskell characters and nesting to 64. Numbers use
  exact rationals with bounded decimal spelling/exponents. Encoding rejects
  non-terminating decimal rationals and invalid Unicode scalars.
- JSON object equality is order-independent and uses the last duplicate key.
  Plugin manifests additionally reject duplicate fields to avoid ambiguity.
- Tool calls support canonical JSON, closed XML-style blocks, closed dotted
  tags, and dotted plain lines. Governance metadata is preserved as strings.
  No call ID is generated. DSML, invoke, todo, and skill-install formats are not
  implemented. Tool-call input is limited to 262,144 characters; oversized input
  is not parsed, and the stripping helper returns it unchanged. This helper is
  not a security sanitizer. Do not infer full Go parser parity from the vectors.
- JSON Schema supports object properties/required fields, array items and
  lengths, scalar types, enum, numeric bounds, and Unicode code-point lengths.
  The reference's zero-bound behavior is preserved. Unknown keywords are ignored.
- Patterns support ASCII literals, dot, ranges/classes, anchors, `*`, `+`, `?`,
  and basic escaped classes. This is not full RE2. Unsupported syntax fails
  explicitly; work is bounded by pattern and input size. Pattern failures such
  as `SCHEMA_PATTERN_UNSUPPORTED` are Core-local, not new wire error codes.
  Other `Left` diagnostic strings are also Core-local rather than wire envelopes.
- Plugin checks cover declared manifest fields, entrypoint/isolation, limits,
  permissions, health, capabilities, and signature/SBOM declarations. They do
  not execute plugins, verify signatures, establish trust, or enforce OS confinement.
- The loop accepts model, tool, and event callbacks returning explicit errors.
  It runs tools sequentially, preserves message history, and enforces step and
  cumulative input/output token budgets. Negative model-reported input or output
  counts fail with the Core-local `AGENT_INVALID_USAGE` error and a `run.failed`
  event before that response's tools run, even when the token budget is disabled.
  The loop relies on callbacks to report accurate non-negative usage; it cannot
  independently verify counts. Callbacks must return errors rather
  than throw exceptions; exceptions are not converted to agent errors. Tool
  lookup and validation are the caller's responsibility. Events contain only
  their kind, not full wire event envelopes. There is no asynchronous streaming
  runtime, cancellation, or concurrent session management.
- `Praxo.Runtime` provides memory, event sinks, checkpoints, lexical path policy,
  context compaction, and stream-kind constants. `Praxo.Middleware` provides PII
  redaction, structured-output validation, call limits, tool selection, and
  fallback helpers. The callback-based agent loop does not automatically apply
  these opt-in helpers.
- There is no model provider, asynchronous event stream, or plugin host in this
  Core. Generic JSON can preserve wire field names; typed codecs for other
  contract envelopes are not claimed.

See the [normative specification](../../spec/README.md),
[parity inventory](../../spec/parity/haskell.md), and
[language policy](../../docs/contributing/language-policy.md).
The parity inventory records the implemented Core surfaces.
See [SETUP.md](SETUP.md) for local setup and test commands.

## License

MIT. See [LICENSE](LICENSE). `base` and `containers` use BSD-style licenses;
GHC and its runtime are separate toolchain components, not vendored code.
