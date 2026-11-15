$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../../praxo-core-ps/praxo-core-ps.psd1') -Force

$assembly = (Get-PraxoCoreInfo).Assembly
$references = @($assembly, [System.Text.Json.Nodes.JsonNode].Assembly.Location)
Add-Type -TypeDefinition @'
using System;
using System.Text.Json.Nodes;
using Praxo.Core;

public sealed class LiveTimeTool : ITool, IToolSpecProvider
{
    public string Name => "get_time";

    public string Description =>
        "Return the current time in ISO 8601 format for the requested zone.";

    public JsonNode? Invoke(JsonObject arguments)
    {
        var zone = arguments["zone"]?.GetValue<string>();
        return JsonValue.Create(
            zone == "local"
                ? DateTimeOffset.Now.ToString("O")
                : DateTimeOffset.UtcNow.ToString("O"));
    }

    public ToolSpec Spec() => new ToolSpec()
    {
        Name = Name,
        Description = Description,
        Parameters = JsonNode.Parse(
            "{\"type\":\"object\",\"properties\":{\"zone\":{\"type\":\"string\"," +
            "\"enum\":[\"utc\",\"local\"],\"description\":\"utc or local; defaults to utc\"}}}")!.AsObject(),
        Risk = "read",
    };
}

public sealed class LiveAllowGetTime : IPolicyHook
{
    public Decision Authorize(Praxo.Core.Action action)
    {
        if (action.Kind == "model.generate")
        {
            return Decision.Allow("model generation");
        }
        if (action.Kind == "tool.invoke")
        {
            return action.ToolName == "get_time"
                ? Decision.Allow("get_time is permitted")
                : Decision.Deny("only get_time is permitted");
        }
        return Decision.Deny("unsupported action");
    }
}
'@ -ReferencedAssemblies $references -CompilerOptions "/nowarn:1701"

function Get-EnvOr {
    param([string]$Name, [string]$Fallback)
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrEmpty($value)) { return $Fallback }
    return $value
}

$baseUrl = Get-EnvOr 'PRAXO_BASE_URL' 'http://localhost:11434/v1'
$modelName = Get-EnvOr 'PRAXO_MODEL' 'qwen3.5:4b'
$prompt = Get-EnvOr 'PRAXO_PROMPT' 'What time is it? Use get_time with zone set to utc and reply with the time.'

$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromSeconds(120)
$adapterOptions = [Praxo.Core.OpenAiCompatibleOptions]::new()
$adapterOptions.BaseUrl = $baseUrl
$adapterOptions.ApiKey = Get-EnvOr 'PRAXO_API_KEY' ''
$adapterOptions.Model = $modelName
$model = [Praxo.Core.OpenAiCompatibleModel]::new($client, $adapterOptions)

$registry = New-PraxoToolRegistry
Register-PraxoTool -Registry $registry -Tool ([LiveTimeTool]::new()) | Out-Null

$options = New-PraxoAgentOptions -Model $model
$options.Tools = $registry
$options.SystemPrompt = 'You are a concise assistant. Use the provided tools when they help.'
$options.MaxSteps = 4
$options.AllowedTools.Add('get_time')
$options.Policy = [LiveAllowGetTime]::new()

$agent = New-PraxoAgent -Options $options

try {
    $result = Invoke-PraxoAgent -Agent $agent -Session (New-PraxoSession -Id 'live-model') `
        -Prompt $prompt
    Write-Output $result.Output
}
catch {
    [Console]::Error.WriteLine("live model run failed: $($_.Exception.Message)")
    [Console]::Error.WriteLine(
        "Check PRAXO_BASE_URL ($baseUrl), PRAXO_MODEL ($modelName), and PRAXO_API_KEY")
    exit 1
}
