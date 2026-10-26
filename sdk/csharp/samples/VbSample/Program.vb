Imports Praxo.Core

Module Program
    Sub Main()
        Dim model As New StaticModel("hello from VB")
        Dim agent As New Agent(New AgentOptions(model))
        Dim result = agent.Run(New Session("vb"), "hello")
        If result.Output <> "hello from VB" Then
            Throw New InvalidOperationException("unexpected output: " & result.Output)
        End If
        Console.WriteLine("VB.NET sample passed: " & result.Output)
    End Sub
End Module
