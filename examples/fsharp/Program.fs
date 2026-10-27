open System
open Praxo.Core

[<EntryPoint>]
let main _ =
    let model = StaticModel("hello from F#")
    let agent = Agent(AgentOptions(model))
    let result = agent.Run(Session("fsharp"), "hello")
    if result.Output <> "hello from F#" then
        invalidOp ("unexpected output: " + result.Output)
    printfn "F# sample passed: %s" result.Output
    0
