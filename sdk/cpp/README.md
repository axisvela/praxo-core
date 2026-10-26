# PRAXO-CORE C++ SDK

C++20 implementation of the PRAXO-CORE agent contract. The normative contract
is [`spec/`](../../spec/README.md); Go remains the reference implementation.

- `SPEC_VERSION`: `0.2.0`
- SDK version: `0.1.0`
- Tier: core
- License: MIT
- Dependencies: C++20 standard library only

## Scope

The SDK implements all eleven vector groups: toolcall, JSON Schema, plugin,
memory, event, stream, checkpoint, policy, context, middleware, and the agent
loop. It includes a public API snapshot and a dependency-free test runner.

## Build and test

With CMake and a C++20 compiler:

```bash
cd sdk/cpp
cmake -S . -B build
cmake --build build
ctest --test-dir build --output-on-failure
python api-snapshot.py --check
```

With Zig on Windows:

```powershell
cd sdk/cpp
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

## Layout

- `include/praxo/` public headers.
- `src/` implementation.
- `conformance/` vector runner.
- `tests/` core tests.
- `api-snapshot.py` and `api/` public API snapshot.

## Release

Tag shape: `cpp/v0.1.0`. The tag targets `SPEC_VERSION` `0.2.0`.
