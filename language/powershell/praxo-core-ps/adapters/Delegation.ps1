function New-PraxoSubagentRequest {
    param(
        [Parameter(Mandatory = $true)][string]$ParentSessionId,
        [Parameter(Mandatory = $true)][string]$AgentId,
        [string]$Prompt = '',
        [ValidateSet('isolated', 'fork')][string]$Mode = 'isolated',
        [hashtable]$Context = @{},
        [object[]]$History = @()
    )
    Import-PraxoCoreAssembly
    $request = [Praxo.Core.Delegation.SubagentRequest]::new()
    $request.ParentSessionId = $ParentSessionId
    $request.AgentId = $AgentId
    $request.Prompt = $Prompt
    if ($Mode -eq 'fork') {
        $request.Mode = [Praxo.Core.Delegation.SubagentMode]::Fork
    } else {
        $request.Mode = [Praxo.Core.Delegation.SubagentMode]::Isolated
    }
    foreach ($key in $Context.Keys) {
        $request.Context[$key] = $Context[$key]
    }
    foreach ($message in $History) {
        $request.History.Add([Praxo.Core.Message]$message)
    }
    $request
}

function Invoke-PraxoSubagent {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Runner,
        [Parameter(Mandatory = $true)]$Request
    )
    Import-PraxoCoreAssembly
    if ([string]::IsNullOrEmpty($Request.ParentSessionId) `
            -or [string]::IsNullOrEmpty($Request.AgentId)) {
        throw [System.ArgumentException]::new(
            'agent: subagent parent session and agent id are required')
    }
    $task = [Praxo.Core.Delegation.SubagentTask]::new()
    $type = $task.GetType()
    $now = [DateTimeOffset]::UtcNow
    $type.GetProperty('Id').SetValue($task, 'subagent')
    $type.GetProperty('ParentSessionId').SetValue($task, $Request.ParentSessionId)
    $type.GetProperty('AgentId').SetValue($task, $Request.AgentId)
    $type.GetProperty('Mode').SetValue($task, $Request.Mode)
    $type.GetProperty('CreatedAt').SetValue($task, $now)
    $task.Status = [Praxo.Core.Delegation.SubagentStatus]::Running
    $task.UpdatedAt = $now
    try {
        $result = & $Runner $Request
        if ($result -is [System.Threading.Tasks.Task[Praxo.Core.Delegation.SubagentResult]]) {
            $result = $result.GetAwaiter().GetResult()
        }
        $task.Status = [Praxo.Core.Delegation.SubagentStatus]::Completed
        $task.Output = [string]$result.Output
    } catch {
        $task.Status = [Praxo.Core.Delegation.SubagentStatus]::Failed
        $task.Error = [string]$_.Exception.Message
    }
    $task.UpdatedAt = [DateTimeOffset]::UtcNow
    $task
}

$script:PraxoAdapterExports = @($script:PraxoAdapterExports) + @(
    'New-PraxoSubagentRequest',
    'Invoke-PraxoSubagent'
)
