param([switch]$UseInstalledModule)

$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot '../../praxo-core-ps/praxo-core-ps.psd1'
if ($UseInstalledModule) {
    if ($env:PRAXO_CORE_DLL) {
        throw 'Unset PRAXO_CORE_DLL before verifying an installed package.'
    }
    Import-Module -FullyQualifiedName @{ ModuleName = 'praxo-core-ps'; RequiredVersion = '0.7.1' } -Force
} elseif (Test-Path $modulePath) {
    Import-Module $modulePath -Force
} else {
    Import-Module praxo-core-ps -Force
}

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

public sealed class ConsumerFixtureModel : IModel
{
    private readonly string _target;

    public ConsumerFixtureModel(string target)
    {
        _target = target;
    }

    public Response Generate(Request request)
    {
        var last = request.Messages[request.Messages.Count - 1];
        if (last.Role == Roles.Tool)
        {
            return new Response { Message = Message.Assistant("recorded") };
        }
        return new Response
        {
            Message = Message.Assistant("", new[]
            {
                new ToolCall
                {
                    Id = "record-1",
                    Name = "record",
                    Arguments = new JsonObject { ["target"] = _target },
                },
            }),
        };
    }
}

public sealed class ConsumerRecordTool : ITool
{
    public int Calls { get; private set; }

    public string Name => "record";

    public string Description => "Record a target in an in-memory counter.";

    public JsonNode? Invoke(JsonObject arguments)
    {
        Calls += 1;
        return JsonValue.Create("recorded");
    }
}

public sealed class ConsumerPublicTargetPolicy : IPolicyHook
{
    public Decision Authorize(Praxo.Core.Action action)
    {
        if (action.Kind == "model.generate")
        {
            return Decision.Allow("model generation");
        }
        if (action.Kind == "tool.invoke")
        {
            var target = action.Arguments?["target"]?.GetValue<string>();
            return action.ToolName == "record" && target == "public"
                ? Decision.Allow("only the public target is permitted")
                : Decision.Deny("only the public target is permitted");
        }
        return Decision.Deny("unsupported action");
    }
}
'@ -ReferencedAssemblies $references -CompilerOptions "/nowarn:1701"

function Invoke-Scenario {
    param([string]$Target)

    $record = [ConsumerRecordTool]::new()
    $registry = New-PraxoToolRegistry
    Register-PraxoTool -Registry $registry -Tool $record | Out-Null

    $options = New-PraxoAgentOptions -Model ([ConsumerFixtureModel]::new($Target))
    $options.Tools = $registry
    $options.MaxSteps = 3
    $options.AllowedTools.Add('record')
    $options.Policy = [ConsumerPublicTargetPolicy]::new()

    $agent = New-PraxoAgent -Options $options
    $session = New-PraxoSession -Id "consumer-$Target"

    try {
        $result = Invoke-PraxoAgent -Agent $agent -Session $session `
            -Prompt 'Record the requested target.'
        [pscustomobject]@{ Output = $result.Output; Calls = $record.Calls; Error = $null }
    }
    catch {
        [pscustomobject]@{ Output = ''; Calls = $record.Calls; Error = $_.Exception }
    }
}

$allowed = Invoke-Scenario -Target 'public'
if ($null -ne $allowed.Error -or $allowed.Output -ne 'recorded' -or $allowed.Calls -ne 1) {
    [Console]::Error.WriteLine(
        "allow verification failed: output=$($allowed.Output) effects=$($allowed.Calls)")
    exit 1
}
Write-Output 'allow: recorded; effects=1'

$denied = Invoke-Scenario -Target 'private'
if ($null -eq $denied.Error -or $denied.Error.Message -notmatch 'denied' -or $denied.Calls -ne 0) {
    [Console]::Error.WriteLine(
        "deny verification failed: effects=$($denied.Calls) error=$($denied.Error)")
    exit 1
}
Write-Output 'deny: policy rejected; effects=0'
