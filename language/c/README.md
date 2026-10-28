# PRAXO-CORE C SDK

C11 implementation of the PRAXO-CORE Core contract with source tag `c/v0.2.0`.
The normative contract is [`spec/`](../../spec/README.md); Go remains the
reference implementation.

**Status:** C11 passes all eleven conformance vector groups. `include/praxo.h`
provides the wire-level JSON primitives, and `include/praxo_core.h` adds public
memory, event, checkpoint, policy, context, middleware, and agent APIs.

## Build and test

With GCC or Clang:

```bash
cd language/c
cmake -S . -B build
cmake --build build
ctest --test-dir build --output-on-failure
```

With Zig on Windows:

```powershell
cd language/c
zig cc -std=c11 -Iinclude -Isrc src/files.c src/json.c src/json_equals.c src/toolcall.c src/jsonschema.c src/plugin.c src/core.c src/core_context.c src/core_middleware.c src/vectors_core.c src/vectors_agent.c src/conformance.c src/main.c -o build/conformance.exe
.\build\conformance.exe
```

Outputs should be written under `language/c/build` (or another workspace directory), not
to a toolchain install root.

## Public API Snapshot

CTest registers the public-header snapshot check and its regression tests when
`BUILD_TESTING` is enabled (the default). These checks require Python 3.10 or newer
and GCC or Clang. Python is not required when configuring with `-DBUILD_TESTING=OFF`.
The checker uses only the Python standard library and the existing C compiler;
there are no Python packages to install.

```bash
python api-snapshot.py --check
python -m unittest discover -s tests -p test_api_snapshot.py -v
```

The checker syntax-checks the public headers, then uses C11 preprocessing and
source locations to retain only declarations and macros from `include/*.h`.
`api/0.2.0.txt` records the unchanged public headers for SDK version 0.2.0,
including header names, include dependencies, SDK/spec version macros, complete
function signatures, callback typedefs, struct/union fields, enums, and constants.
All header-defined macros, including include guards, are retained rather than
guessing which conditional defaults are private.
Whitespace and comments are ignored; declaration and member order are retained.
`PRAXO_SPEC_VERSION` must match `spec/SPEC_VERSION`, and `PRAXO_CORE_VERSION`
must match `PRAXO_SDK_VERSION`.

`--check` never writes files and fails for missing or changed snapshots, invalid
headers, version mismatches, or compiler failures. Without `--check`, the tool
creates a missing `api/<PRAXO_SDK_VERSION>.txt`; it refuses to overwrite a changed
existing baseline. Preserve historical snapshots and review API changes and
versioning before generating a new version. Use `--compiler PATH` to select a
GCC/Clang executable; otherwise it searches for `clang`, `gcc`, then `cc`.
The checker requires the GNU-style driver, not `clang-cl`. CMake automatically
passes GCC/GNU-style Clang; MSVC-front-end builds discover a separate compatible
driver for the API tests. The gate was added after `c/v0.2.0`; its baseline does
not change that tag or imply that the historical release included this checker.

This is a source-declaration gate, not an ABI or semantic compatibility proof.
It captures the active C11 preprocessing configuration, not every platform or
feature-macro branch, and does not record system-header declarations, binary
layout, calling conventions, runtime behavior, or evaluated numeric expressions.
It intentionally has no fallback parser: unsupported compiler/directive errors
fail the gate rather than silently weakening capture. Parity-table adapter names
are not all public header symbols, so this check does not validate parity rows.

## Contract Surface

| File | Contract |
| --- | --- |
| `include/praxo.h` | Arena, JSON value, and parse/stringify API |
| `include/praxo_core.h` | Memory, events, checkpoint, policy, context, middleware, and agent API |
| `src/core.c`, `src/core_context.c`, `src/core_middleware.c` | Public Core implementation |
| `src/toolcall.c` | Tool-call parsing and markup stripping |
| `src/jsonschema.c` | Documented JSON Schema subset |
| `src/plugin.c` | Manifest v1 parsing and validation |
| `src/conformance.c` | Vector groups |
| `src/main.c` | Conformance entry point |

Wire names preserve the Go casing, including `image_url` and `runId`.

The unreleased source runs all eleven vector groups through the public API,
including actual checkpoint serialization and model/tool history roundtrips.
Context messages currently support role/content text only, and policy path
checks are lexical, not filesystem or symlink containment. A null event-filter
predicate forwards all events; a non-null empty predicate forwards none.

The agent loop has no cancellation token or callback-abort path. A run is
bounded by its step limit, token limit, or a callback error, not by context
cancellation. `PxCallLimit` is mutable per-run state without synchronization;
do not share one instance across concurrent runs. Both limits are explicit
partial-parity surfaces until a versioned API change is designed.

## License

MIT. See [LICENSE](LICENSE).
