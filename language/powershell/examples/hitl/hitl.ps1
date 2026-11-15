$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../../praxo-core-ps/praxo-core-ps.psd1') -Force

$assembly = (Get-PraxoCoreInfo).Assembly
$references = @(
    $assembly,
    [System.Text.Json.Nodes.JsonNode].Assembly.Location,
    [System.Collections.Generic.List[object]].Assembly.Location,
    'System.Collections'
)
Add-Type -TypeDefinition @'
#nullable enable
using System.Text.Json.Nodes;
using Praxo.Core;

public sealed class HitlFixtureModel : IModel
{
    public Response Generate(Request request)
    {
        var last = request.Messages[request.Messages.Count - 1];
        if (last.Role == Roles.Tool)
        {
            return new Response { Message = Message.Assistant("done") };
        }
        return new Response
        {
            Message = Message.Assistant("", new[]
            {
                new ToolCall
                {
                    Id = "write-note-1",
                    Name = "write_note",
                    Arguments = new JsonObject
                    {
                        ["text"] = "hello",
                        ["visibility"] = "public",
                    },
                },
            }),
        };
    }
}

public sealed class HitlWriteTool : ITool
{
    public int Calls { get; private set; }

    public string Name => "write_note";

    public string Description => "Write a short note with the requested visibility.";

    public JsonNode? Invoke(JsonObject arguments)
    {
        Calls += 1;
        return JsonValue.Create("written");
    }
}

public sealed class HitlFixedDecision : IInterruptHandler
{
    private readonly InterruptDecision _decision;

    public HitlFixedDecision(InterruptDecision decision)
    {
        _decision = decision;
    }

    public InterruptDecision Decide(Interrupt interrupt) => _decision;
}

public sealed class HitlPublicPolicy : IPolicyHook
{
    public int AuthorizeCalls { get; private set; }

    public string LastVisibility { get; private set; } = "";

    public Decision Authorize(Action action)
    {
        if (action.Kind == "model.generate")
        {
            return Decision.Allow("model generation");
        }
        if (action.Kind == "tool.invoke")
        {
            var visibility = action.Arguments?["visibility"]?.GetValue<string>();
            AuthorizeCalls += 1;
            LastVisibility = visibility ?? "";
            return action.ToolName == "write_note" && visibility == "public"
                ? Decision.Allow("only public notes are permitted")
                : Decision.Deny("only public notes are permitted");
        }
        return Decision.Deny("unsupported action");
    }
}
'@ -ReferencedAssemblies $references -CompilerOptions "/nowarn:1701"

function Invoke-HitlScenario {
    param($Decision)

    $tool = [HitlWriteTool]::new()
    $registry = New-PraxoToolRegistry
    Register-PraxoTool -Registry $registry -Tool $tool | Out-Null

    $options = New-PraxoAgentOptions -Model ([HitlFixtureModel]::new())
    $options.Tools = $registry
    $options.MaxSteps = 3
    $options.AllowedTools.Add('write_note')
    $policy = [HitlPublicPolicy]::new()
    $options.Policy = $policy
    Add-PraxoInterruptTool -Options $options -Name 'write_note' | Out-Null
    $argText = if ($null -eq $Decision.Arguments) { '<null>' } else { $Decision.Arguments.ToJsonString() }
    [Console]::Error.WriteLine("DECISION action=$($Decision.Action) args=$argText")
    $options.OnInterruptDecision = [HitlFixedDecision]::new($Decision)

    $agent = New-PraxoAgent -Options $options
    $session = New-PraxoSession -Id 'hitl'
    try {
        $result = Invoke-PraxoAgent -Agent $agent -Session $session -Prompt 'Write a note.'
        [pscustomobject]@{ Output = $result.Output; Code = ''; Effects = $tool.Calls; AuthCalls = $policy.AuthorizeCalls; LastVisibility = $policy.LastVisibility }
    }
    catch [Praxo.Core.PraxoException] {
        [pscustomobject]@{ Output = ''; Code = $_.Exception.Code; Effects = $tool.Calls }
    }
}

$approve = Invoke-HitlScenario (New-PraxoInterruptDecision -Action 'approve')
if ($approve.Code -ne '' -or $approve.Output -ne 'done' -or $approve.Effects -ne 1) {
    [Console]::Error.WriteLine(
        "approve scenario failed: output=$($approve.Output) effects=$($approve.Effects) error=$($approve.Code)")
    exit 1
}
Write-Output 'approve: written; effects=1'

$edit = Invoke-HitlScenario (New-PraxoInterruptDecision -Action 'edit' -Arguments @{
    text = 'hello'
    visibility = 'private'
})
if ($edit.Code -ne 'AGENT_POLICY_DENIED' -or $edit.Effects -ne 0) {
    [Console]::Error.WriteLine(
        "edit scenario failed: effects=$($edit.Effects) error=$($edit.Code) auth=$($edit.AuthCalls) last=$($edit.LastVisibility)")
    exit 1
}
Write-Output 'edit: policy rejected; effects=0'
