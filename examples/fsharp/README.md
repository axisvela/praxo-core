# PRAXO-CORE F# Sample

F# consumes the C# / .NET Core assembly; it is a sample, not a second contract
implementation. The sample runs on .NET 8.

## Build and run

From the repository root, use the .NET Core to run the sample:

```bash
dotnet run --project examples/fsharp/Praxo.FSharp.Sample.fsproj
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

## Release

No separate tag. F# ships with the C# package `csharp/v0.1.0`.
