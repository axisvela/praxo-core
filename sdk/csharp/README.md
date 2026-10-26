# PRAXO-CORE C# SDK

C# 12 / .NET 8 implementation of the PRAXO-CORE agent contract.

- `SPEC_VERSION`: `0.2.0`
- SDK version: `0.1.0`
- License: MIT
- Dependencies: none beyond the .NET base class library

## Scope

The SDK implements all eleven vector groups: toolcall, jsonschema, plugin,
checkpoint, event, memory, policy, stream, context, middleware, and agent loop.
It also includes a synchronous `OpenAiCompatibleModel` and a streaming variant.
The public API is idiomatic C#; wire shapes keep the Go casing (`image_url`,
`runId`, `plugin_id`).

## Build and test

```bash
dotnet build sdk/csharp/Praxo.Core/Praxo.Core.csproj
dotnet run --project sdk/csharp/Praxo.Conformance
dotnet run --project sdk/csharp/Praxo.Tests
dotnet run --project sdk/csharp/Praxo.Conformance -- --check-api
dotnet run --project sdk/csharp/samples/VbSample
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

## Layout

- `Praxo.Core/` library.
- `Praxo.Conformance/` vector runner and API snapshot tool.
- `Praxo.Tests/` dependency-free core tests.
- `samples/VbSample/` VB.NET consumer sample.
- `api-snapshot.txt` checked-in public API snapshot.

## Release

Tag shape: `csharp/v0.1.0`. The tag targets `SPEC_VERSION` `0.2.0`.
