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
using System.Threading;
using Praxo.Core;

public sealed class ChainMcpTransport : IMcpTransport
{
    private bool _running;

    public ChainMcpTransport(Dictionary<string, int> effects)
    {
        Effects = effects;
    }

    public Dictionary<string, int> Effects { get; }

    public int? ProcessId => null;

    public bool HasExited => !_running;

    public void Start() => _running = true;

    public void Send(JsonObject message)
    {
    }

    public void Notify(string method, JsonObject? parameters)
    {
    }

    public JsonObject Request(
        string method,
        JsonObject? parameters,
        TimeSpan timeout,
        CancellationToken cancellationToken)
    {
        if (!_running)
        {
            throw new InvalidOperationException("mcp: transport is closed");
        }
        JsonObject result;
        if (method == "initialize")
        {
            result = new JsonObject
            {
                ["protocolVersion"] = McpClient.DefaultProtocolVersion,
                ["capabilities"] = new JsonObject { ["tools"] = new JsonObject() },
                ["serverInfo"] = new JsonObject { ["name"] = "chain-mcp" },
            };
        }
        else if (method == "tools/list")
        {
            result = new JsonObject
            {
                ["tools"] = new JsonArray
                {
                    new JsonObject
                    {
                        ["name"] = "record",
                        ["description"] = "Record a target",
                        ["inputSchema"] = new JsonObject
                        {
                            ["type"] = "object",
                            ["properties"] = new JsonObject
                            {
                                ["target"] = new JsonObject { ["type"] = "string" },
                            },
                            ["required"] = new JsonArray { "target" },
                        },
                    },
                },
            };
        }
        else if (method == "tools/call")
        {
            var arguments = parameters?["arguments"] as JsonObject;
            var target = arguments?["target"]?.GetValue<string>() ?? "";
            Effects[target] = Effects.GetValueOrDefault(target) + 1;
            result = new JsonObject
            {
                ["content"] = new JsonArray
                {
                    new JsonObject { ["type"] = "text", ["text"] = "recorded:" + target },
                },
            };
        }
        else
        {
            result = new JsonObject();
        }
        return new JsonObject
        {
            ["jsonrpc"] = "2.0",
            ["id"] = 1,
            ["result"] = result,
        };
    }

    public void Close() => _running = false;

    public void Dispose() => Close();
}

public sealed class ChainModel : IModel
{
    private readonly string[] _tools;
    private readonly string[] _targets;
    private readonly string _final;
    private int _calls;

    public ChainModel(string[] tools, string[] targets, string final)
    {
        _tools = tools;
        _targets = targets;
        _final = final;
    }

    public int Calls => _calls;

    public Response Generate(Request request)
    {
        _calls += 1;
        if (_calls <= _tools.Length)
        {
            var index = _calls - 1;
            return new Response
            {
                Message = Message.Assistant("", new[]
                {
                    new ToolCall
                    {
                        Id = "chain-call-" + _calls,
                        Name = _tools[index],
                        Arguments = new JsonObject { ["target"] = _targets[index] },
                    },
                }),
            };
        }
        return new Response { Message = Message.Assistant(_final) };
    }
}

public sealed class ChainPolicy : IPolicyHook
{
    private readonly string _kind;

    public ChainPolicy(string kind)
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
        var target = action.Arguments?["target"]?.GetValue<string>() ?? "";
        if (_kind == "parent")
        {
            if (action.ToolName == "record")
            {
                return target != "blocked"
                    ? Decision.Allow("record allowed")
                    : Decision.Deny("blocked target");
            }
            return action.ToolName == "delegate"
                ? Decision.Allow("delegate allowed")
                : Decision.Deny("parent tool is not allowed");
        }
        return action.ToolName == "record"
            ? Decision.Allow("child record allowed")
            : Decision.Deny("child may only record");
    }
}

public sealed class DelegateChainTool : ITool
{
    private readonly McpToolAdapter _record;
    private readonly ChainModel _childModel;
    private readonly MultiSink _events;

    public DelegateChainTool(McpToolAdapter record, ChainModel childModel, MultiSink events)
    {
        _record = record;
        _childModel = childModel;
        _events = events;
    }

    public string Name => "delegate";

    public string Description => "Run a governed child agent.";

    public JsonNode? Invoke(JsonObject arguments)
    {
        var tools = new ToolRegistry();
        tools.Register(_record);
        var options = new AgentOptions(_childModel)
        {
            Tools = tools,
            AllowedTools = new List<string> { "record" },
            Policy = new ChainPolicy("child"),
            RequirePolicy = true,
            RequireToolScope = true,
            MaxSteps = 3,
            Events = _events,
        };
        var result = new Agent(options).Run(
            new Session("chain-child"), "record child");
        return JsonValue.Create(result.Output);
    }
}
'@ -ReferencedAssemblies $references -CompilerOptions "/nowarn:1701"

$state = @{
    otel = 0
    harmovela = 0
}
$effects = [System.Collections.Generic.Dictionary[string, int]]::new([System.StringComparer]::Ordinal)
$transport = [ChainMcpTransport]::new($effects)
$client = [Praxo.Core.McpClient]::new($transport)
$client.Connect() | Out-Null
$record = [Praxo.Core.McpToolAdapter]::new(
    $client,
    ($client.ListTools() | Where-Object Name -eq 'record' | Select-Object -First 1))

$otelOptions = New-PraxoOtelSinkOptions -Endpoint 'http://otel.test/v1/traces' -ServiceName 'praxo-chain'
$otelSink = New-PraxoOtelSink -Options $otelOptions -Transport {
    param($request)
    $state.otel++
    $response = [Praxo.Core.OtelHttpResponse]::new()
    $response.StatusCode = 200
    $response
}

$harmovelaOptions = New-PraxoHarmovelaSinkOptions -BaseUrl 'http://harmovela.test' -Source 'praxo-chain'
$harmovelaSink = New-PraxoHarmovelaSink -Options $harmovelaOptions -Transport {
    param($request)
    $state.harmovela++
    $response = [Praxo.Core.HarmovelaHttpResponse]::new()
    $response.StatusCode = 202
    $response
}
$events = [Praxo.Core.MultiSink]::new([Praxo.Core.IEventSink[]]@($otelSink, $harmovelaSink))

$childModel = [ChainModel]::new(
    [string[]]@('record'),
    [string[]]@('child'),
    'CHILD-DONE')
$parentModel = [ChainModel]::new(
    [string[]]@('record', 'delegate'),
    [string[]]@('parent', 'child'),
    'DONE')
$delegate = [DelegateChainTool]::new($record, $childModel, $events)

$registry = New-PraxoToolRegistry
Register-PraxoTool -Registry $registry -Tool $record | Out-Null
Register-PraxoTool -Registry $registry -Tool $delegate | Out-Null

$options = New-PraxoAgentOptions -Model $parentModel
$options.Tools = $registry
$options.AllowedTools.Add('record')
$options.AllowedTools.Add('delegate')
$options.Policy = [ChainPolicy]::new('parent')
$options.RequirePolicy = $true
$options.RequireToolScope = $true
$options.MaxSteps = 4
$options.Events = $events

$parent = Invoke-PraxoAgent -Agent (New-PraxoAgent -Options $options) -Session (New-PraxoSession -Id 'chain-parent') -Prompt 'run the representative chain'
if ($parent.Output -ne 'DONE' -or $effects['parent'] -ne 1 -or $effects['child'] -ne 1 -or $childModel.Calls -ne 2) {
    throw "representative chain failed: output=$($parent.Output) parent=$($effects['parent']) child=$($effects['child']) childCalls=$($childModel.Calls)"
}
if ($state.otel -lt 3 -or $state.harmovela -lt 3) {
    throw "representative chain events missing: otel=$($state.otel) harmovela=$($state.harmovela)"
}

$deniedModel = [ChainModel]::new(
    [string[]]@('record'),
    [string[]]@('edit-me'),
    'UNEXPECTED')
$deniedOptions = New-PraxoAgentOptions -Model $deniedModel
$deniedOptions.Tools = $registry
$deniedOptions.AllowedTools.Add('record')
$deniedOptions.Policy = [ChainPolicy]::new('parent')
$deniedOptions.RequirePolicy = $true
$deniedOptions.RequireToolScope = $true
$deniedOptions.MaxSteps = 2
$deniedOptions.Events = $events
Add-PraxoInterruptTool -Options $deniedOptions -Name 'record' | Out-Null
$deniedOptions.OnInterruptDecision = New-PraxoInterruptHandler -Handler {
    param($interrupt)
    New-PraxoInterruptDecision -Action 'edit' -Arguments @{ target = 'blocked' }
}
$deniedCode = ''
try {
    Invoke-PraxoAgent -Agent (New-PraxoAgent -Options $deniedOptions) -Session (New-PraxoSession -Id 'chain-denied') -Prompt 'attempt a denied edit' | Out-Null
} catch [Praxo.Core.PraxoException] {
    $deniedCode = $_.Exception.GetBaseException().Code
}
$blocked = if ($effects.ContainsKey('blocked')) { $effects['blocked'] } else { 0 }
if ($deniedCode -ne 'AGENT_POLICY_DENIED' -or $blocked -ne 0) {
    throw "denied edit failed: code=$deniedCode blocked=$blocked"
}

Write-Output "output: $($parent.Output)"
Write-Output "effects: parent=$($effects['parent']) child=$($effects['child'])"
Write-Output "child calls: $($childModel.Calls)"
Write-Output "otel spans: $($state.otel)"
Write-Output "harmovela events: $($state.harmovela)"
Write-Output 'denied effects: 0'

$client.Dispose()
