# PRAXO-CORE C++ Core

C++20 implementation of the PRAXO-CORE agent contract. The normative contract
is [`spec/`](../../spec/README.md); Go remains the reference implementation.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.4.0`
- Tier: core
- License: MIT
- Dependencies: C++20 standard library only

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](REGISTRY.md)
- Machine-readable entry: [llms.txt](llms.txt) and [llms.md](llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](../../docs/getting-started/coding-agents.md)
- Registry: Source / CMake

## Scope

The Core implements all eleven vector groups: toolcall, JSON Schema, plugin,
memory, event, stream, checkpoint, policy, context, middleware, the agent loop,
and human-in-the-loop interrupt decisions. It includes a public API snapshot and
a dependency-free test runner.

## Build and test

With CMake and a C++20 compiler:

```bash
cd language/cpp
cmake -S . -B build
cmake --build build
ctest --test-dir build --output-on-failure
python api-snapshot.py --check
```

With Zig on Windows:

```powershell
cd language/cpp
zig c++ -std=c++20 -Iinclude src/agent.cpp src/jsonschema.cpp src/middleware.cpp `
  src/plugin.cpp src/runtime.cpp src/toolcall.cpp conformance/main.cpp `
  conformance/run.cpp -o build/praxo-cpp-conformance.exe
.\build\praxo-cpp-conformance.exe
```

## Quickstart

```cpp
#include "praxo/agent.hpp"

praxo::AgentOptions options(std::make_shared<praxo::StaticModel>("hello"));
auto result = praxo::run_agent(
    std::move(options),
    praxo::Session{"demo", {}},
    "hello",
);
std::cout << result.output << "\n";
```

Tools register on the options object:

```cpp
auto registry = std::make_shared<praxo::ToolRegistry>();
registry->register_tool(std::make_shared<praxo::FuncTool>(
    "echo", "Echo arguments",
    [](const praxo::Json& arguments) { return arguments; }));
options.tools = registry;
```

## Runtime options

- `cancellation` is a predicate checked before model work and before and after
  each tool. Cancellation raises `AGENT_CANCELLED` after after-run cleanup.
- `on_stream` receives `StreamPart` values for `values` and `messages`. A
  callback error aborts the run instead of completing it.
- `max_parallel_tools` runs tool invocations with `std::async` within each batch
  and preserves result order. Tool implementations own their thread safety.
- `CallLimit::before_run` scopes counters by run ID so independent runs do not
  share limits.
- `parse_sse_stream` parses OpenAI-compatible server-sent-event text and throws
  `MODEL_STREAM` for truncation or malformed half packets.

## Layout

- `include/praxo/` public headers.
- `src/` implementation.
- `conformance/` vector runner.
- `tests/` core tests.
- `api-snapshot.py` and `api/` public API snapshot.

## Release

Tag shape: `cpp/v0.4.0`. The tag targets `SPEC_VERSION` `0.2.0`. See
[CHANGELOG.md](CHANGELOG.md) for per-release changes and compatibility notes.
