# PRAXO-CORE C++ Core

C++20 implementation of the PRAXO-CORE agent contract. The normative contract
is [`spec/`](../../spec/README.md); Go remains the reference implementation.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.6.0`
- Tier: core
- License: MIT
- Dependencies: C++20 standard library only

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/cpp/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/cpp/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/cpp/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: Source / CMake

## Scope

The Core implements all eleven vector groups: toolcall, JSON Schema, plugin,
memory, event, stream, checkpoint, policy, context, middleware, the agent loop,
and human-in-the-loop interrupt decisions. It includes a public API snapshot and
a dependency-free test runner.

## Harmovela Event Sink

```cpp
#include "praxo/harmovela.hpp"

praxo::HarmovelaSink sink(
    "http://127.0.0.1:8790/aep/api", "praxo-core", "0.2", transport, clock);
praxo::Event event;
event.type = "tool.call";
event.session_id = "s1";
event.run_id = "run-1";
event.data = praxo::Json::object();
event.data["name"] = "echo";
sink.emit(event);
```

`HarmovelaSink` posts to `{baseUrl}/events` with
`content-type: application/json` and the documented `spec_version`, `id`,
`type`, `source`, `created_at`, and merged `payload` envelope. The C++ Core
bundles no HTTP client, so callers provide a `HarmovelaTransport`; a
`HarmovelaClock` makes timestamps deterministic. A 2xx status is success; any
other status throws `HARMOVELA_HTTP` with the status and a bounded response
body.

The sink adds no authentication, retries, buffering, ordering, or
exactly-once-delivery guarantee. Apply caller-side filtering because event data
may contain sensitive content, and use HTTPS for remote endpoints.

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

## OpenAI-Compatible Adapter

`praxo/openai_compat.hpp` provides a non-streaming `Model` with an injected
transport. It maps role/content messages, assistant tool calls, tool results,
and tool specs to the OpenAI request shape, and maps `message.content`,
`message.tool_calls` (arguments parsed from the provider JSON string), `usage`,
and `finish_reason` back to `praxo::Response`. Invalid tool arguments throw
`PROVIDER_JSON`; a missing base URL throws `PROVIDER_HTTP` before any transport
call.

No HTTP client is bundled. The transport callback is the only network seam, so
production use requires a caller-provided POST implementation. Adding one is a
separate dependency decision: a reviewed libcurl build (MIT-style license) or a
platform socket client (Winsock/POSIX, platform-specific) would each need its
own build, licensing, and error-mapping review. Tests inject a fake transport
and make no network calls. Streaming is not implemented.

```cpp
#include "praxo/openai_compat.hpp"

praxo::OpenAICompatibleOptions config;
config.base_url = "https://api.example/v1";
config.model = "provider-model";

praxo::OpenAICompatible adapter(config,
    [](const std::string& url, const praxo::Json& payload,
       const std::map<std::string, std::string>& headers) {
        return post_json(url, payload.dump(), headers);
    });
auto response = adapter.generate(request);
```

## Anthropic and Gemini Adapters

`praxo/anthropic.hpp` and `praxo/gemini.hpp` provide the same transport-seam
contract for Anthropic Messages and Gemini generateContent.

```cpp
#include "praxo/anthropic.hpp"
#include "praxo/gemini.hpp"

praxo::AnthropicOptions claude_options;
claude_options.model = "claude-sonnet-4-5";
claude_options.api_key = "ak";
praxo::Anthropic claude(claude_options, transport);

praxo::GeminiOptions gemini_options;
gemini_options.model = "gemini-2.5-pro";
gemini_options.api_key = "gk";
praxo::Gemini gemini(gemini_options, transport);
```

Both adapters map tool calls, tools schemas, usage, finish reasons, and provider
errors. Callers provide the HTTP transport.

## Layout

- `include/praxo/` public headers.
- `src/` implementation.
- `conformance/` vector runner.
- `tests/` core tests.
- `api-snapshot.py` and `api/` public API snapshot.

## Release

Tag shape: `cpp/v0.4.0`. The tag targets `SPEC_VERSION` `0.2.0`. See
[CHANGELOG.md](CHANGELOG.md) for per-release changes and compatibility notes.
