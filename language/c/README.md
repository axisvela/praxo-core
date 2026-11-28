# PRAXO-CORE C Core

C11 implementation of the PRAXO-CORE Core contract with source version `0.12.0`.
The normative contract is [`spec/`](../../spec/README.md); Go remains the
reference implementation.

**Status:** C11 passes all eleven conformance vector groups. `include/praxo.h`
provides the wire-level JSON primitives, and `include/praxo_core.h` adds public
memory, event, checkpoint, policy, context, middleware, and agent APIs.

PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed agent framework for C, with tool calling, policy hooks, human-in-the-loop approval, checkpoints, and execution events. Use the language-specific scope and verification evidence below; a package listing does not establish Go feature parity or production readiness.

## Registry and Coding-Agent Entry

- Get started, prerequisites, and installation: [language documentation](https://axisvela.github.io/praxo-core/languages/c/)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/c/examples): runnable language-specific examples; see each README for prerequisites and verification.
- [Scenario tutorials](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial): read the scope and validation status; source is not portfolio acceptance.
- Reference applications: no language-specific accepted end-to-end application recorded; see the [tutorial catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/).
- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/c/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/c/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/c/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [xmake](https://packages.xmake.io/packages/praxo-core)
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761) · [LinkedIn](https://www.linkedin.com/company/axisvela/) · [Facebook](https://www.facebook.com/profile.php?id=61596905732406) · [YouTube](https://www.youtube.com/@axisvela) · [Discord](https://discord.com/channels/1575163993767809064/1575164343148875977) · [GitHub Discussions](https://github.com/axisvela/praxo-core/discussions) · [GitHub Issues](https://github.com/axisvela/praxo-core/issues) · [Documentation](https://axisvela.github.io/praxo-core/) · [Architect](https://axisvela.architect.pub)

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

## Install

With xmake:

```bash
xrepo install praxo-core
```

Or build and install with CMake:

```bash
cmake -S . -B build -DCMAKE_INSTALL_PREFIX=/tmp/praxo-c
cmake --build build
cmake --install build
```

The install prefix receives `include/praxo.h`, `include/praxo_core.h`, and the
static `praxo_core` library. CI compiles and runs `tests/install_consumer.c`
against that prefix, without repository include paths. The install does not yet
provide pkg-config metadata, a CMake package config, shared libraries, or ABI
guarantees.

## Harmovela Event Sink

```c
PxHarmovelaSink sink = px_harmovela_sink(
    "http://127.0.0.1:8790/aep/api", "praxo-core", "0.2",
    my_transport, transport_context);
const char *error = NULL;
if (!px_harmovela_emit(&arena, &sink, &event, &error)) {
    fprintf(stderr, "%s\n", error);
}
```

`px_harmovela_emit` posts to `{baseURL}/events` with
`content-type: application/json` and the documented `spec_version`, `id`,
`type`, `source`, `created_at`, and merged `payload` envelope. `include/praxo.h`
does not bundle an HTTP client, so callers provide a `PxHarmovelaTransport`.
Pass a `PxHarmovelaClock` to make timestamps deterministic. A 2xx status is
success; any other status returns false with an error containing the status and
a bounded response body.

The sink adds no authentication, retries, buffering, ordering, or
exactly-once-delivery guarantee. Apply caller-side filtering because event data
may contain sensitive content, and use HTTPS for remote endpoints.

## Process plugin host

`px_plugin_process_start` / `px_plugin_process_invoke` /
`px_plugin_process_stop` implement the JSON-Lines process plugin contract on
Windows and POSIX with token authentication, health handshake, invocation timeout, and
typed call errors.

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
`api/0.4.0.txt` records the public headers for Core version 0.4.0,
including header names, include dependencies, Core/spec version macros, complete
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

The agent loop supports cooperative cancellation through the
`PxAgentOptions.cancelled` callback, which is checked between steps and before
tool batches. It cannot abort an in-flight model or tool callback, so a run is
also bounded by its step limit, token limit, or a callback error.
`PxCallLimit` is mutable per-run state without synchronization; do not share one
instance across concurrent runs. Both limits are explicit partial-parity
surfaces until a versioned API change is designed.

## OpenAI-Compatible Adapter

`src/openai.c` with declarations in `src/openai.h` is an in-tree
transport-seam adapter. It maps role/content messages, assistant tool calls,
tool results, and tool specs to the OpenAI request shape, and maps
`message.content`, `message.tool_calls`, `usage`, and `finish_reason` back to
the Core response object. Tool arguments are parsed from the provider JSON
string and invalid JSON is rejected. It is not part of the installed public
headers or the public API snapshot.

`px_openai_generate_stream` sets `stream: true`, parses the SSE response,
reassembles content, fragmented tool calls, usage, and `finish_reason`, and
invokes the `on_delta` callback for each text delta. The transport still returns
the complete SSE body; true incremental network reads depend on the caller's
transport implementation. The delta callback receives the same context pointer
passed to the agent, so callers that need separate state should branch on the
callback's own arguments or use `transport_ctx` for the adapter.

No HTTP client is bundled. The transport callback is the only network seam, so
production use requires a caller-provided POST implementation. Adding one is a
separate dependency decision: a reviewed libcurl build (MIT-style license) or a
platform socket client (Winsock/POSIX, platform-specific and not portable)
would each need its own build, licensing, and error-mapping review. Tests use an
injected fake transport and make no network calls. A transport failure returns
`NULL` from `px_openai_generate` and surfaces as `MODEL_ERROR` through the agent
callback; call `px_openai_parse_response` directly for a `PROVIDER_JSON` status.
Truncated or malformed streams return `MODEL_STREAM`; invalid streamed tool
arguments return `PROVIDER_JSON`.

```c
#include "openai.h"

static const char *post(const char *url, const char *body, const char *api_key,
        void *ctx, const char **error) {
    (void)url; (void)body; (void)api_key; (void)ctx; (void)error;
    return "{\"choices\":[{\"message\":{\"content\":\"hello\"}}]}";
}

PxOpenAICompatible adapter = {
    .base_url = "https://api.example/v1",
    .model = "provider-model",
    .api_key = "",
    .transport = post,
    .transport_ctx = NULL,
};
options.generate = px_openai_generate;
options.generate_stream = px_openai_generate_stream;
options.ctx = &adapter;
```

## Anthropic and Gemini Adapters

`src/anthropic.c` and `src/gemini.c` provide the same transport-seam contract
for the Anthropic Messages and Gemini generateContent APIs.
`px_anthropic_generate_stream` reassembles Anthropic SSE content, tool calls,
usage, and finish reason; both Anthropic and Gemini reassemble SSE.

```c
#include "anthropic.h"
#include "gemini.h"

PxAnthropic claude = {
    .base_url = "https://api.anthropic.com",
    .model = "claude-sonnet-4-5",
    .api_key = "ak",
    .version = "2023-06-01",
    .max_tokens = 1024,
    .transport = post,
};
PxGemini gemini = {
    .base_url = "https://generativelanguage.googleapis.com",
    .model = "gemini-2.5-pro",
    .api_key = "gk",
    .transport = post,
};
```

Both adapters map tool calls, tools schemas, usage, finish reasons, and provider
errors. Callers supply the HTTP transport.

## Release Notes

See [CHANGELOG.md](CHANGELOG.md) for per-release changes and compatibility
notes, and [PARALLEL.md](PARALLEL.md) for the parallel-tool design and platform
limits.


## Tutorials and Reference Applications

Language-specific scenario tutorials and reference applications for C.

### Scenario Tutorials

| Tutorial | What it shows |
| --- | --- |
| [aquaculture-water](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/aquaculture-water) | Computes fixed oxygen/temperature indicators and drafts a bounded review action. No aerator or feeder command. |
| [device-diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/device-diagnostics) | A scoped device tutorial over the native MIT C Core. It reads one fixed `device-100` diagnostic snapshot through an application-owned `PxDeviceAdapter` function pointer and draf... |
| [hvac-settings](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/hvac-settings) | Reads fixed building conditions and drafts review-only HVAC/lighting settings. No BMS command or verified energy savings. |
| [lab-loop](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/lab-loop) | Simulates one fixed parameter/result cycle and drafts review-only next parameters. No actuator, chemical handling or autonomous experiment. |
| [livestock-monitor](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/livestock-monitor) | Summarizes fixed animal observations and drafts a review-only veterinary request. No diagnosis, isolation or feeding control. |
| [npc-narrative](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/npc-narrative) | Reads fixed character state and drafts one scoped host action with an observed result. No arbitrary host commands. |
| [world-economy](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/world-economy) | Simulates one fixed economy tick and drafts a review-only balance action. No long-term equilibrium or scale guarantee. |

Index: [language/c/Tutorial](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial).

### Reference Applications

No accepted end-to-end reference application is recorded for this language yet. Candidate goals are tracked in the [Reference Application Portfolio](https://axisvela.github.io/praxo-core/project/planning/roadmap/#reference-application-portfolio).

Planning context: [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/), [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), and [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/). Chinese: [教程计划](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/), [候选场景](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/), [教程目录](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/).

## Community

- X: <https://x.com/axisvela>
- Weibo: <https://weibo.com/u/1936025761>
- LinkedIn: <https://www.linkedin.com/company/axisvela/>
- Facebook: <https://www.facebook.com/profile.php?id=61596905732406>
- YouTube: <https://www.youtube.com/@axisvela>
- Discord: <https://discord.com/channels/1575163993767809064/1575164343148875977>
- GitHub Discussions: <https://github.com/axisvela/praxo-core/discussions>
- GitHub Issues: <https://github.com/axisvela/praxo-core/issues>
- Documentation: <https://axisvela.github.io/praxo-core/>
- Architect: <https://axisvela.architect.pub>


## License

MIT. See [LICENSE](LICENSE).
