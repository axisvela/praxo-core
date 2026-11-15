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
using Praxo.Core;

public sealed class SessionCheckpointTurnModel : IModel
{
    public Response Generate(Request request)
    {
        return new Response
        {
            Message = Message.Assistant("turn " + request.Messages.Count.ToString()),
        };
    }
}
'@ -ReferencedAssemblies $references -CompilerOptions "/nowarn:1701"

function Save-SessionCheckpoint {
    param(
        [Parameter(Mandatory = $true)]$Allowlist,
        [Parameter(Mandatory = $true)][hashtable]$Store,
        [Parameter(Mandatory = $true)]$Session,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$RunId
    )
    $messagesJson = [System.Text.Json.JsonSerializer]::Serialize(
        $Session.Messages,
        [System.Collections.Generic.List[Praxo.Core.Message]]
    )
    $envelope = [System.Text.Json.Nodes.JsonObject]::new()
    $envelope['id'] = $Id
    $envelope['sessionId'] = $Session.Id
    $envelope['runId'] = $RunId
    $envelope['status'] = 'completed'
    $envelope['messages'] = [System.Text.Json.Nodes.JsonNode]::Parse($messagesJson)
    $Store[$Session.Id] = $Allowlist.Marshal('session.checkpoint', $envelope)
}

function Load-SessionCheckpointMessages {
    param(
        [Parameter(Mandatory = $true)]$Allowlist,
        [Parameter(Mandatory = $true)][hashtable]$Store,
        [Parameter(Mandatory = $true)][string]$SessionId
    )
    if (-not $Store.ContainsKey($SessionId)) {
        throw 'checkpoint not found'
    }
    $data = $Allowlist.Unmarshal($Store[$SessionId])
    $messages = $data.AsObject()['messages']
    if ($null -eq $messages) {
        throw 'checkpoint messages are invalid'
    }
    $raw = $messages.ToJsonString()
    Write-Output -NoEnumerate ([System.Text.Json.JsonSerializer]::Deserialize(
        $raw,
        [System.Collections.Generic.List[Praxo.Core.Message]]
    ))
}

function Set-SessionMessages {
    param(
        [Parameter(Mandatory = $true)]$Session,
        [Parameter(Mandatory = $true)]$Messages
    )
    $Session.Messages.Clear()
    foreach ($message in $Messages) {
        $Session.Messages.Add($message)
    }
}

$allowlist = New-PraxoCheckpointAllowlist
Register-PraxoCheckpointType -Allowlist $allowlist -TypeName 'session.checkpoint'

$store = @{}
$session = New-PraxoSession -Id 'session-1' -Messages @(
    [Praxo.Core.Message]::Text('user', 'first'),
    [Praxo.Core.Message]::Text('assistant', 'ack')
)
Save-SessionCheckpoint -Allowlist $allowlist -Store $store -Session $session -Id 'cp-1' -RunId 'run-1'

$options = New-PraxoAgentOptions -Model ([SessionCheckpointTurnModel]::new())
$options.MaxSteps = 2
$agent = New-PraxoAgent -Options $options

$messages = Load-SessionCheckpointMessages -Allowlist $allowlist -Store $store -SessionId $session.Id
Set-SessionMessages -Session $session -Messages $messages
$result = Invoke-PraxoAgent -Agent $agent -Session $session -Prompt 'second'
if ($result.Output -ne 'turn 3') {
    throw "unexpected second turn: $($result.Output)"
}

$session.Messages.Add([Praxo.Core.Message]::Text('user', 'second'))
$session.Messages.Add([Praxo.Core.Message]::Text('assistant', $result.Output))
Save-SessionCheckpoint -Allowlist $allowlist -Store $store -Session $session -Id 'cp-2' -RunId 'run-2'

$messages = Load-SessionCheckpointMessages -Allowlist $allowlist -Store $store -SessionId $session.Id
Set-SessionMessages -Session $session -Messages $messages
$result = Invoke-PraxoAgent -Agent $agent -Session $session -Prompt 'third'
if ($result.Output -ne 'turn 5') {
    throw "unexpected third turn: $($result.Output)"
}

Write-Output "restored messages: $($messages.Count)"
Write-Output "output: $($result.Output)"
