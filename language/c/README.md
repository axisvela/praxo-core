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
zig cc -std=c11 -Iinclude -Isrc src/files.c src/json.c src/json_equals.c src/toolcall.c src/jsonschema.c src/plugin.c src/core.c src/vectors_core.c src/vectors_agent.c src/conformance.c src/main.c -o build/conformance.exe
.\build\conformance.exe
```

Outputs should be written under `language/c/build` (or another workspace directory), not
to a toolchain install root.

## Contract Surface

| File | Contract |
| --- | --- |
| `include/praxo.h` | Arena, JSON value, and parse/stringify API |
| `include/praxo_core.h` | Memory, events, checkpoint, policy, context, middleware, and agent API |
| `src/core.c` | Public Core implementation |
| `src/toolcall.c` | Tool-call parsing and markup stripping |
| `src/jsonschema.c` | Documented JSON Schema subset |
| `src/plugin.c` | Manifest v1 parsing and validation |
| `src/conformance.c` | Vector groups |
| `src/main.c` | Conformance entry point |

Wire names preserve the Go casing, including `image_url` and `runId`.

## License

MIT. See [LICENSE](LICENSE).
