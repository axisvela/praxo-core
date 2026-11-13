$script:PraxoSubagentRunnerSource = @'
using System;
using System.Threading.Tasks;
using Praxo.Core.Delegation;

namespace Praxo.Core.PowerShell
{
    public sealed class FuncSubagentRunner : SubagentRunner
    {
        private readonly Func<SubagentRequest, Task<SubagentResult>> _run;

        public FuncSubagentRunner(
            Func<SubagentRequest, Task<SubagentResult>> run)
        {
            _run = run ?? throw new ArgumentNullException(nameof(run));
        }

        public Task<SubagentResult> RunAsync(SubagentRequest request)
            => _run(request);
    }
}
'@

function Initialize-PraxoSubagentAdapter {
    Import-PraxoCoreAssembly
    if ('Praxo.Core.PowerShell.FuncSubagentRunner' -as [type]) {
        return
    }
    Add-Type -TypeDefinition $script:PraxoSubagentRunnerSource `
        -ReferencedAssemblies $script:PraxoCoreDll
}

function New-PraxoFuncSubagentRunner {
    param([Parameter(Mandatory = $true)][scriptblock]$Run)
    Import-PraxoCoreAssembly
    Initialize-PraxoSubagentAdapter
    $wrapped = {
        param($request)
        $result = & $Run $request
        if ($result -is [System.Threading.Tasks.Task[Praxo.Core.Delegation.SubagentResult]]) {
            return $result
        }
        $typed = [Praxo.Core.Delegation.SubagentResult]$result
        [System.Threading.Tasks.Task[Praxo.Core.Delegation.SubagentResult]]::FromResult($typed)
    }.GetNewClosure()
    $delegate = [System.Management.Automation.LanguagePrimitives]::ConvertTo(
        $wrapped,
        [System.Func[Praxo.Core.Delegation.SubagentRequest, System.Threading.Tasks.Task[Praxo.Core.Delegation.SubagentResult]]]
    )
    [Praxo.Core.PowerShell.FuncSubagentRunner]::new($delegate)
}

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

function New-PraxoSubagentManager {
    param([Parameter(Mandatory = $true)]$Runner)
    Import-PraxoCoreAssembly
    [Praxo.Core.Delegation.SubagentManager]::new($Runner)
}

function Invoke-PraxoSubagent {
    param(
        [Parameter(Mandatory = $true)]$Manager,
        [Parameter(Mandatory = $true)]$Request,
        [int]$TimeoutSeconds = 30
    )
    $task = $Manager.Launch($Request)
    if ($TimeoutSeconds -gt 0) {
        $timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)
    } else {
        $timeout = [System.Threading.Timeout]::InfiniteTimeSpan
    }
    $Manager.WaitAsync($task.Id, $timeout).GetAwaiter().GetResult()
}

$script:PraxoAdapterExports = @($script:PraxoAdapterExports) + @(
    'New-PraxoFuncSubagentRunner',
    'New-PraxoSubagentRequest',
    'New-PraxoSubagentManager',
    'Invoke-PraxoSubagent'
)
