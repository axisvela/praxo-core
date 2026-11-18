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
using System;
using System.Collections.Generic;
using System.Text.Json.Nodes;
using Praxo.Core;

public sealed class GovState
{
    public Dictionary<string, int> Effects { get; } =
        new Dictionary<string, int>(StringComparer.Ordinal);

    public int Budget { get; set; }

    public int Children { get; set; }

    public void Record(string target)
        => Effects[target] = Effects.GetValueOrDefault(target) + 1;

    public int Count(string target) => Effects.GetValueOrDefault(target);
}

public sealed class GovModel : IModel
{
    private readonly string _tool;
    private readonly string _target;
    private int _calls;

    public GovModel(string tool, string target)
    {
        _tool = tool;
        _target = target;
    }

    public Response Generate(Request request)
    {
        _calls += 1;
        if (_calls == 1)
        {
            return new Response
            {
                Message = Message.Assistant("", new[]
                {
                    new ToolCall
                    {
                        Id = "gov-call-1",
                        Name = _tool,
                        Arguments = new JsonObject { ["target"] = _target },
                    },
                }),
            };
        }
        return new Response { Message = Message.Assistant("done") };
    }
}

public sealed class GovTool : ITool
{
    private readonly GovState _state;

    public GovTool(GovState state)
    {
        _state = state;
    }

    public string Name => "record";

    public string Description => "Record a target.";

    public JsonNode? Invoke(JsonObject arguments)
    {
        _state.Record(arguments["target"]?.GetValue<string>() ?? "");
        return JsonValue.Create("ok");
    }
}

public sealed class GovPolicy : IPolicyHook
{
    private readonly int _kind;

    public GovPolicy(int kind)
    {
        _kind = kind;
    }

    public Decision Authorize(Praxo.Core.Action action)
    {
        if (action.Kind == "model.generate")
        {
            return Decision.Allow("model generation");
        }
        if (action.Kind != "tool.invoke")
        {
            return Decision.Deny("unsupported action");
        }
        var tool = action.ToolName ?? "";
        var target = action.Arguments?["target"]?.GetValue<string>() ?? "";
        if (_kind == 0)
        {
            return tool == "record"
                ? Decision.Allow("child may only record")
                : Decision.Deny("child may only record");
        }
        if (_kind == 1)
        {
            return tool == "record" && target != "blocked"
                ? Decision.Allow("record allowed")
                : Decision.Deny("blocked target");
        }
        if (_kind == 2)
        {
            return tool == "delegate" || (tool == "record" && target != "blocked")
                ? Decision.Allow("parent policy")
                : Decision.Deny("parent policy");
        }
        return Decision.Deny("unknown policy");
    }
}
'@ -ReferencedAssemblies $references -CompilerOptions "/nowarn:1701"

$state = [GovState]::new()
$registry = New-PraxoToolRegistry
Register-PraxoTool -Registry $registry -Tool ([GovTool]::new($state)) | Out-Null

function New-GovDeniedTask {
    param([string]$Status, [string]$Code)
    [pscustomobject]@{ Status = $Status; Error = $Code; Output = '' }
}

function Invoke-GovChild {
    param(
        [string]$Tool,
        [string]$Target,
        [hashtable]$Config
    )

    if ($Config.Cancelled) {
        return New-GovDeniedTask -Status 'cancelled' -Code 'CANCELLED'
    }
    if ($Config.MaxDepth -ge 0 -and $Config.Depth -gt $Config.MaxDepth) {
        return New-GovDeniedTask -Status 'denied' -Code 'DEPTH_LIMIT'
    }
    if ($Config.MaxChildren -ge 0 -and $state.Children -ge $Config.MaxChildren) {
        return New-GovDeniedTask -Status 'denied' -Code 'CHILD_LIMIT'
    }
    if ($Config.UseBudget -and $state.Budget -le 0) {
        return New-GovDeniedTask -Status 'denied' -Code 'BUDGET_EXHAUSTED'
    }
    if ($Config.UseChildren) {
        $state.Children++
    }

    $request = New-PraxoSubagentRequest -ParentSessionId 'governance-parent' -AgentId 'governance-child' -Prompt 'run child'
    $task = Invoke-PraxoSubagent -Request $request -Runner {
        param($subagentRequest)
        $options = New-PraxoAgentOptions -Model ([GovModel]::new($Tool, $Target))
        $options.Tools = $registry
        $options.AllowedTools.Add('record')
        $options.Policy = [GovPolicy]::new([int]$Config.PolicyKind)
        $options.RequirePolicy = $true
        $options.RequireToolScope = $true
        $options.MaxSteps = 3
        if ($Config.EditToBlocked) {
            Add-PraxoInterruptTool -Options $options -Name 'record' | Out-Null
            $options.OnInterruptDecision = New-PraxoInterruptHandler -Handler {
                param($interrupt)
                New-PraxoInterruptDecision -Action 'edit' -Arguments @{ target = 'blocked' }
            }
        }
        $result = Invoke-PraxoAgent -Agent (New-PraxoAgent -Options $options) -Session (New-PraxoSession -Id 'governance-child') -Prompt 'run child'
        [pscustomobject]@{ Output = $result.Output }
    }

    if ($Config.UseBudget -and $task.Status.ToString() -eq 'Completed') {
        $state.Budget--
    }
    $task
}

function Invoke-GovCase {
    param(
        [string]$Tool,
        [string]$Target,
        [hashtable]$Config,
        [string]$Status,
        [string]$Code = ''
    )
    $task = Invoke-GovChild -Tool $Tool -Target $Target -Config $Config
    if ($task.Status.ToString() -ne $Status) {
        throw "status $($task.Status) expected $Status"
    }
    if ($Code -ne '' -and [string]$task.Error -notlike "*$Code*") {
        throw "error $($task.Error) expected $Code"
    }
}

$config = @{
    Allowed       = @('record')
    PolicyKind    = 0
    Depth         = 0
    MaxDepth      = -1
    MaxChildren   = -1
    UseBudget     = $false
    UseChildren   = $false
    Cancelled     = $false
    EditToBlocked = $false
}

Invoke-GovCase -Tool 'write' -Target 'escape' -Config $config -Status 'Failed'
if ($state.Count('escape') -ne 0) { throw 'escape effect' }

$config.PolicyKind = 2
Invoke-GovCase -Tool 'record' -Target 'blocked' -Config $config -Status 'Failed'
if ($state.Count('blocked') -ne 0) { throw 'blocked effect' }

$config.PolicyKind = 0
$config.UseBudget = $true
$state.Budget = 1
Invoke-GovCase -Tool 'record' -Target 'sibling' -Config $config -Status 'Completed'
Invoke-GovCase -Tool 'record' -Target 'sibling' -Config $config -Status 'Denied' -Code 'BUDGET_EXHAUSTED'
if ($state.Count('sibling') -ne 1) { throw 'sibling effect' }

$config.UseBudget = $false
$config.UseChildren = $true
$config.MaxChildren = 1
$state.Children = 0
Invoke-GovCase -Tool 'record' -Target 'limit' -Config $config -Status 'Completed'
Invoke-GovCase -Tool 'record' -Target 'limit' -Config $config -Status 'Denied' -Code 'CHILD_LIMIT'

$config.UseChildren = $false
$config.MaxChildren = -1
$config.Depth = 2
$config.MaxDepth = 1
Invoke-GovCase -Tool 'record' -Target 'limit' -Config $config -Status 'Denied' -Code 'DEPTH_LIMIT'
if ($state.Count('limit') -ne 1) { throw 'limit effect' }

$config.Depth = 0
$config.MaxDepth = -1
$config.Cancelled = $true
Invoke-GovCase -Tool 'record' -Target 'cancel' -Config $config -Status 'Cancelled' -Code 'CANCELLED'
if ($state.Count('cancel') -ne 0) { throw 'cancel effect' }

$config.Cancelled = $false
$config.PolicyKind = 1
$config.EditToBlocked = $true
Invoke-GovCase -Tool 'record' -Target 'edit-me' -Config $config -Status 'Failed'
if ($state.Count('edit-me') -ne 0) { throw 'edit effect' }
if ($state.Count('blocked') -ne 0) { throw 'edited blocked effect' }

Write-Output 'PowerShell advanced delegation governance: 6/6 passed'
