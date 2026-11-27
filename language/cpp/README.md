# PRAXO-CORE C++ Core

C++20 implementation of the PRAXO-CORE agent contract. The normative contract
is [`spec/`](../../spec/README.md); Go remains the reference implementation.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.10.0`
- Tier: core
- License: MIT
- Dependencies: C++20 standard library; the optional `ProcessPluginHost` links
  the C Core library

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/cpp/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/cpp/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/cpp/llms.md)
- [Examples](https://github.com/axisvela/praxo-core/tree/main/language/cpp/examples): runnable language-specific examples.
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [xmake](https://packages.xmake.io/packages/praxo-core-cpp)
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761) · [LinkedIn](https://www.linkedin.com/company/axisvela/) · [Facebook](https://www.facebook.com/profile.php?id=61596905732406) · [YouTube](https://www.youtube.com/@axisvela) · [Discord](https://discord.com/channels/1575163993767809064/1575164343148875977) · [GitHub Discussions](https://github.com/axisvela/praxo-core/discussions) · [GitHub Issues](https://github.com/axisvela/praxo-core/issues) · [Documentation](https://axisvela.github.io/praxo-core/) · [Architect](https://axisvela.architect.pub)

## Install

With xmake:

```bash
xrepo install praxo-core-cpp
```

Or build from source with CMake as shown below.

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

`praxo/openai_compat.hpp` provides a `Model` with an injected transport. It maps
role/content messages, assistant tool calls, tool results, and tool specs to the
OpenAI request shape, and maps `message.content`, `message.tool_calls`
(arguments parsed from the provider JSON string), `usage`, and `finish_reason`
back to `praxo::Response`. Invalid tool arguments throw `PROVIDER_JSON`; a
missing base URL throws `PROVIDER_HTTP` before any transport call.

An optional `OpenAICompatibleStreamTransport` returning SSE text enables
`generate_stream`. Content, fragmented tool calls, usage, and `finish_reason`
are reassembled, and each text delta is forwarded to
`AgentOptions::on_delta`. `Model::generate_stream` defaults to `generate` for
models that do not stream.

No HTTP client is bundled. The transport callback is the only network seam, so
production use requires a caller-provided POST implementation. Adding one is a
separate dependency decision: a reviewed libcurl build (MIT-style license) or a
platform socket client (Winsock/POSIX, platform-specific) would each need its
own build, licensing, and error-mapping review. Tests inject a fake transport
and make no network calls. The Anthropic adapter supports SSE streaming via an
optional `AnthropicStreamTransport` and `GeminiStreamTransport`; both providers reassemble SSE.
`MODEL_STREAM` reports truncated or malformed SSE input.

```cpp
#include "praxo/openai_compat.hpp"

praxo::OpenAICompatibleOptions config;
config.base_url = "https://api.example/v1";
config.model = "provider-model";

praxo::OpenAICompatible adapter(config,
    [](const std::string& url, const praxo::Json& payload,
       const std::map<std::string, std::string>& headers) {
        return post_json(url, payload.dump(), headers);
    },
    [](const std::string& url, const praxo::Json& payload,
       const std::map<std::string, std::string>& headers) {
        return post_sse(url, payload.dump(), headers);
    });
auto response = adapter.generate(request);
```

Set `AgentOptions::on_delta` to have the agent call the streaming path.

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


## Tutorials and Reference Applications

Language-specific scenario tutorials and reference applications for C++.

### Scenario Tutorials

| Tutorial | What it shows |
| --- | --- |
| [bom-review](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/bom-review) | A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [construction-safety](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/construction-safety) | A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [container-yard](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/container-yard) | A bounded first slice of TL-02, not a terminal operating system. It replans fixed synthetic container jobs under resource constraints and drafts a review-only schedule. No crane... |
| [drone-fleet-plan](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/drone-fleet-plan) | A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [dubbing-plan](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/dubbing-plan) | A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [eda-placement](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/eda-placement) | A bounded first slice of OG-05, not a foundry-valid physical-design flow. It reads a fixed synthetic placement grid and drafts a review-only placement with stated PPA proxies. N... |
| [fleet-map](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/fleet-map) | A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [household-robot](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/household-robot) | A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [industrial-edge](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/industrial-edge) | A scoped industrial tutorial over the native MIT C++ Core. It reads one fixed `edge-100` snapshot through an application-owned `DeviceAdapter` interface and drafts an operator m... |
| [materials-design](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/materials-design) | A bounded first slice of SC-04, not a validated materials-discovery pipeline. It evaluates fixed synthetic candidate properties and drafts the next review-only simulation. No va... |
| [mesh-review](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/mesh-review) | A bounded first slice of MD-05, not a CAD kernel or manufacturing-certification flow. It compares fixed synthetic mesh descriptors against stated constraints and drafts a review... |
| [mining-slope](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/mining-slope) | A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [molecule-screen](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/molecule-screen) | A bounded first slice of SC-02, not drug discovery. It ranks fixed synthetic molecular descriptors under stated constraints and drafts a review-only assessment. No efficacy, tox... |
| [ocean-routing](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/ocean-routing) | A bounded first slice of TL-03, not a navigation or fuel-optimization system. It compares fixed synthetic route/weather costs and drafts a review-only route. No navigation comma... |
| [production-scheduling](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/production-scheduling) | A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [quant-risk](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/quant-risk) | A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [storyboard-previs](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/storyboard-previs) | A bounded tutorial slice over the native C++ Core. It reads one fixed fixture, enforces scope and drafts a review-only result. No production write or external system access. |
| [traffic-signal-plan](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/traffic-signal-plan) | A bounded first slice of CT-01, not a traffic-control system. It reads fixed junction queues, drafts a review-only green-time plan and checks it against deterministic limits. No... |

Index: [language/cpp/Tutorial](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial).

### Reference Applications

No accepted end-to-end reference application is recorded for this language yet. Candidate goals are tracked in the [Reference Application Portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio).

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

