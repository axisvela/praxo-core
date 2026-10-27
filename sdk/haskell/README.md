# PRAXO-CORE Haskell Wire SDK

An unreleased, native Haskell implementation of the declared wire subset.
It does not call Go or another SDK and does not implement an agent loop.

- Implementation type: Wire, not Core.
- Target: native Framework. The current Wire stage does not yet provide an
  agent loop; starting one still requires a named consumer and maintenance owner.
- Candidate package version: `0.1.0`; supported `SPEC_VERSION`: `0.2.0`.
- Local gate: 24 shared vectors across toolcall, JSON Schema, and plugin groups,
  plus native regression tests and source API/parity checks.
- Linux and Windows CI passed on commit `4273f47`. Release review remains pending;
  no release tag or Hackage publication is implied.

## Build and Test

Use GHC 9.0 or newer and Python 3.10 or newer. CI targets GHC 9.12.2 on Linux
and Windows. From the repository root:

```bash
python sdk/haskell/run-tests.py
python sdk/haskell/api-snapshot.py --check
```

Set `GHC` or pass `--compiler /path/to/ghc` to select the compiler. Python only
builds and launches the native programs; it does not implement their behavior.
Generated files stay under `sdk/haskell/build/`.

For a Cabal source build, from `sdk/haskell/`:

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
  as `SCHEMA_PATTERN_UNSUPPORTED` are SDK-local, not new wire error codes.
  Other `Left` diagnostic strings are also SDK-local rather than wire envelopes.
- Plugin checks cover declared manifest fields, entrypoint/isolation, limits,
  permissions, health, capabilities, and signature/SBOM declarations. They do
  not execute plugins, verify signatures, establish trust, or enforce OS confinement.
- There is no model provider, native agent loop, memory implementation,
  checkpoint runtime, asynchronous event stream, or plugin host in this SDK.
  Generic JSON can preserve wire field names; typed codecs for other contract
  envelopes are not claimed.

See the [normative specification](../../spec/README.md),
[parity inventory](../../spec/parity/haskell.md), and
[language policy](../../docs/contributing/language-policy.md).

## License

MIT. See [LICENSE](LICENSE). `base` and `containers` use BSD-style licenses;
GHC and its runtime are separate toolchain components, not vendored code.
