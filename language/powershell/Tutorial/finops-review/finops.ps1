param(
    [switch]$SourceMode,
    [string]$Account = 'account-100',
    [switch]$SimulateFailure,
    [switch]$Test,
    [switch]$Deny
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

if ($SourceMode) {
    Import-Module (Join-Path $PSScriptRoot '../../praxo-core-ps/praxo-core-ps.psd1') -Force
} else {
    if ($env:PRAXO_CORE_DLL) { throw 'Unset PRAXO_CORE_DLL before using the published module.' }
    Import-Module -FullyQualifiedName @{ ModuleName = 'praxo-core-ps'; RequiredVersion = '0.9.1' } -Force
}
$assembly = (Get-PraxoCoreInfo).Assembly
$references = @(
    $assembly,
    [System.Text.Json.Nodes.JsonNode].Assembly.Location,
    [System.Collections.Generic.List[object]].Assembly.Location,
    'System.Collections',
    'System.Linq'
)
Add-Type -Path (Join-Path $PSScriptRoot 'Interop.cs') -ReferencedAssemblies $references -CompilerOptions '/nowarn:1701'

function Invoke-Case {
    param([string]$Target, [bool]$Failure)

    $costTool = [Praxo.Tutorial.Finops.CostTool]::new($Failure)
    $reviewTool = [Praxo.Tutorial.Finops.ReviewTool]::new()
    $registry = New-PraxoToolRegistry
    Register-PraxoTool -Registry $registry -Tool $costTool | Out-Null
    Register-PraxoTool -Registry $registry -Tool $reviewTool | Out-Null
    $options = New-PraxoAgentOptions -Model ([Praxo.Tutorial.Finops.FixtureModel]::new($Target))
    $options.Tools = $registry
    $options.Policy = [Praxo.Tutorial.Finops.CostPolicy]::new()
    $options.AllowedTools.Add('read_costs')
    $options.AllowedTools.Add('draft_review')
    $options.MaxSteps = 4
    $agent = New-PraxoAgent -Options $options
    try {
        $result = Invoke-PraxoAgent -Agent $agent -Session (New-PraxoSession -Id "finops-$Target") `
            -Prompt 'Read fixed resource costs and draft a review-only action.'
        return [pscustomobject]@{
            Output = $result.Output
            Reads = $costTool.Calls
            Drafts = $reviewTool.Calls
            Code = $null
        }
    } catch {
        $code = $_.Exception.Message
        return [pscustomobject]@{
            Output = $null
            Reads = $costTool.Calls
            Drafts = $reviewTool.Calls
            Code = $code
        }
    }
}

function Run-Tests {
    $success = Invoke-Case -Target 'account-100' -Failure $false
    if ($success.Code -or $success.Reads -ne 1 -or $success.Drafts -ne 1) {
        throw "success failed: reads=$($success.Reads) drafts=$($success.Drafts) code=$($success.Code)"
    }
    $report = ConvertFrom-Json -InputObject $success.Output -AsHashtable
    $candidate = $report['costs']['candidate']
    if ($candidate['id'] -ne 'vm-1' -or $candidate['monthly_cost'] -ne 420) {
        throw "candidate calculation failed"
    }
    if ($report['review']['action'] -ne 'review_termination' -or
        $report['review']['status'] -ne 'draft_only' -or
        $report['terminations_executed'] -ne 0) {
        throw "review contract failed"
    }

    $denied = Invoke-Case -Target 'account-200' -Failure $false
    if (-not $denied.Code -or $denied.Reads -ne 0 -or $denied.Drafts -ne 0) {
        throw "denial failed: reads=$($denied.Reads) drafts=$($denied.Drafts)"
    }

    $failed = Invoke-Case -Target 'account-100' -Failure $true
    if (-not $failed.Code -or $failed.Reads -ne 1 -or $failed.Drafts -ne 0) {
        throw "dependency failure failed: reads=$($failed.Reads) drafts=$($failed.Drafts)"
    }

    Write-Output 'PowerShell SE-07 finops-review tutorial: success, denial and dependency failure passed'
}

if ($Test) {
    Run-Tests
    exit 0
}

$target = if ($Deny) { 'account-200' } else { $Account }
$outcome = Invoke-Case -Target $target -Failure $SimulateFailure.IsPresent
if ($outcome.Code) {
    [Console]::Error.WriteLine("finops review failed: reads=$($outcome.Reads) drafts=$($outcome.Drafts); $($outcome.Code)")
    exit 1
}
$report = ConvertFrom-Json -InputObject $outcome.Output -AsHashtable
$report['read_calls'] = $outcome.Reads
ConvertTo-Json -InputObject $report -Depth 10 -Compress
