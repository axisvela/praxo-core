# PRAXO-CORE C# Core

PRAXO-CORE is an embeddable, MIT-licensed agent framework. This package is its
native .NET Core: an agent loop with tool registration and dispatch, policy
hooks, typed events, memory, checkpoints, context budgets, middleware, JSON
Schema validation, and plugin manifest parsing. It runs in-process and does not
require a hosted service.

- `SPEC_VERSION`: `0.2.0`
- Core version: `0.4.0`
- License: MIT
- Dependencies: none beyond the .NET base class library
- The NuGet package is `Praxo.Core@0.4.0`.

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/csharp/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/csharp/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/csharp/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: [NuGet](https://www.nuget.org/packages/Praxo.Core/0.4.0)

## Install

```bash
dotnet add package Praxo.Core --version 0.4.0
```

## Scope

The Core implements all eleven vector groups: toolcall, jsonschema, plugin,
checkpoint, event, memory, policy, stream, context, middleware, and agent loop.
It also includes a synchronous `OpenAiCompatibleModel` and a streaming variant.
The agent loop supports `RunStream`, cooperative cancellation through
`AgentOptions.CancellationToken`, bounded parallel tool execution through
`AgentOptions.MaxParallelTools`, and human-in-the-loop interrupt decisions
through `AgentOptions.InterruptOn` and `OnInterruptDecision`. The public API is
idiomatic C#; wire shapes
keep the Go casing (`image_url`, `runId`, `plugin_id`).

## Build and test

```bash
dotnet build language/csharp/Praxo.Core/Praxo.Core.csproj
dotnet run --project language/csharp/Praxo.Conformance
dotnet run --project language/csharp/Praxo.Tests
dotnet run --project language/csharp/Praxo.Conformance -- --check-api
dotnet run --project language/csharp/samples/VbSample
```

Local toolchain used by the repository maintainers lives at `D:\dev\dotnet`.
On CI, use the standard `actions/setup-dotnet` job.

## Quickstart

```csharp
using Praxo.Core;

var model = new StaticModel("hello");
var agent = new Agent(new AgentOptions(model));
var result = agent.Run(new Session("demo"), "hello");
Console.WriteLine(result.Output);
```

Tools are registered on `AgentOptions.Tools`:

```csharp
var registry = new ToolRegistry();
registry.Register(new FuncTool("echo", "Echo arguments", args => args.DeepClone()));

var agent = new Agent(new AgentOptions(model)
{
    Tools = registry,
    MaxSteps = 8,
});
```

## Model adapters

- `OpenAiCompatibleModel` for OpenAI, DeepSeek, Kimi/Moonshot, OpenRouter,
  Groq, and Together endpoints.
- `AnthropicModel` for the Anthropic Messages API.
- `GeminiModel` for the Gemini generateContent API.

Each adapter accepts an injected `HttpClient` so tests can use a fake transport.

## Harmovela event sink

`HarmovelaSink` posts lifecycle events to `{BaseUrl}/events` as JSON envelopes
with `spec_version`, `id`, `type`, `source`, `created_at`, and a payload that
merges the event data with `session_id` and `run_id` when present.

```csharp
using Praxo.Core;

var options = new AgentOptions(model)
{
    Events = new HarmovelaSink(new HarmovelaSinkOptions
    {
        BaseUrl = "http://127.0.0.1:8790/aep/api",
    }),
};
var agent = new Agent(options);
```

Pass a `HarmovelaTransport` to inject a fake for tests. Limits: the sink adds no
authentication, retries, buffering, acknowledgements, ordering, or exactly-once
delivery. Filter sensitive event data at the caller, and use HTTPS for remote
endpoints.

## MCP stdio client

`McpClient` spawns a child process and speaks newline-delimited JSON-RPC 2.0.
It performs the `initialize` / `notifications/initialized` handshake, follows
`tools/list` cursors, rejects repeated cursors and duplicate names, preserves
`inputSchema`, and maps `tools/call` structured or text content.

```csharp
using System.Text.Json.Nodes;
using Praxo.Core;

using var client = new McpClient(new McpServerOptions
{
    Command = "my-mcp-server",
});
client.Connect();

var registry = new ToolRegistry();
client.RegisterTools(registry);

var result = client.CallTool("echo", new JsonObject { ["text"] = "hi" });
```

Registering MCP tools does not bypass policy: the agent still authorizes every
`tool.invoke` action and applies its allowlist and middleware. Limits: stdio
transport only, no remote transport or authentication, and MCP output remains
untrusted content. Operations are bounded by the client timeout (default 30
seconds), timeouts send `notifications/cancelled`, and `Close` terminates the
child process.

## Layout

- `Praxo.Core/` library.
- `Praxo.Conformance/` vector runner and API snapshot tool.
- `Praxo.Tests/` dependency-free core tests.
- `samples/VbSample/` VB.NET consumer sample.
- `api-snapshot.txt` checked-in public API snapshot.

## Release

Tag shape: `csharp/v0.4.0`. The tag targets `SPEC_VERSION` `0.2.0`. See
[CHANGELOG.md](CHANGELOG.md) for per-release changes and compatibility notes.
