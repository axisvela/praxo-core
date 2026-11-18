# PRAXO-CORE F# Sample

F# consumes the C# / .NET Core assembly; it is a sample, not a second contract
implementation. The sample runs on .NET 8.

## Build and run

From the repository root, use the .NET Core to run the sample:

```bash
dotnet run --project language/fsharp/examples/Praxo.FSharp.Sample.fsproj
```

CI runs the same command after building the C# Core.

## Usage

```fsharp
open Praxo.Core

let model = StaticModel("hello")
let agent = Agent(AgentOptions(model))
let result = agent.Run(Session("demo"), "hello")
printfn "%s" result.Output
```

Tools, middleware, memory, checkpoints, policy, and streaming are the C# Core
APIs; do not create a separate F# core.

## Representative Chain and Governance

F# uses the C# Core directly. Run the host language examples instead of creating
a separate F# chain:

- [C# representative chain tests](../../csharp/Praxo.Tests/RepresentativeChainTests.cs)
- [C# advanced delegation](../../csharp/examples/advanced-delegation/README.md)

## Release

No separate tag. F# ships with the C# package `csharp/v0.1.0`.
