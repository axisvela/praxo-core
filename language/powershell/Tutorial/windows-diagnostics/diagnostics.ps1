param(
    [switch]$SourceMode,
    [switch]$LocalMachine,
    [string]$ServiceName = 'Spooler',
    [switch]$SimulateFailure
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

if ($LocalMachine -and -not $IsWindows) { throw 'LocalMachine mode requires Windows.' }
if ($LocalMachine -and $SimulateFailure) { throw 'SimulateFailure is fixture-only.' }
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

$serviceRead = [System.Func[System.Text.Json.Nodes.JsonObject, System.Text.Json.Nodes.JsonNode]] {
    param($arguments)
    if ($SimulateFailure) { throw 'Simulated diagnostic dependency unavailable.' }
    if ($LocalMachine) {
        $service = Get-Service -Name 'Spooler' -ErrorAction Stop
        $record = @{ kind = 'service'; name = 'Spooler'; status = [string]$service.Status; source = 'local_machine' }
    } else {
        $record = @{ kind = 'service'; name = 'Spooler'; status = 'Running'; source = 'fixture' }
    }
    Write-Output -NoEnumerate ([System.Text.Json.Nodes.JsonNode]::Parse((ConvertTo-Json -InputObject $record -Compress)))
}
$diskRead = [System.Func[System.Text.Json.Nodes.JsonObject, System.Text.Json.Nodes.JsonNode]] {
    param($arguments)
    if ($LocalMachine) {
        $drive = Get-PSDrive -Name $env:SystemDrive.TrimEnd(':') -PSProvider FileSystem -ErrorAction Stop
        $record = @{ kind = 'disk'; name = 'system'; free_bytes = [long]$drive.Free; source = 'local_machine' }
    } else {
        $record = @{ kind = 'disk'; name = 'system'; free_bytes = [long]10737418240; source = 'fixture' }
    }
    Write-Output -NoEnumerate ([System.Text.Json.Nodes.JsonNode]::Parse((ConvertTo-Json -InputObject $record -Compress)))
}
$serviceTool = [Praxo.Tutorial.Operations.ProbeTool]::new('read_service', 'Spooler', $serviceRead)
$diskTool = [Praxo.Tutorial.Operations.ProbeTool]::new('read_disk', 'system', $diskRead)
$registry = New-PraxoToolRegistry
Register-PraxoTool -Registry $registry -Tool $serviceTool | Out-Null
Register-PraxoTool -Registry $registry -Tool $diskTool | Out-Null
$options = New-PraxoAgentOptions -Model ([Praxo.Tutorial.Operations.FixtureModel]::new($ServiceName))
$options.Tools = $registry
$options.Policy = [Praxo.Tutorial.Operations.ScopePolicy]::new()
$options.AllowedTools.Add('read_service')
$options.AllowedTools.Add('read_disk')
$options.MaxSteps = 3
$agent = New-PraxoAgent -Options $options
try {
    $result = Invoke-PraxoAgent -Agent $agent -Session (New-PraxoSession -Id 'windows-diagnostics') `
        -Prompt 'Inspect the fixed Windows service and system disk; report observations only.'
    $report = ConvertFrom-Json -InputObject $result.Output -AsHashtable
    $report['read_calls'] = $serviceTool.Calls + $diskTool.Calls
    ConvertTo-Json -InputObject $report -Depth 10 -Compress
} catch {
    [Console]::Error.WriteLine("diagnostics failed: reads=$($serviceTool.Calls + $diskTool.Calls); $($_.Exception.Message)")
    exit 1
}
