@{
    RootModule        = 'praxo-core-ps.psm1'
    ModuleVersion     = '0.3.1'
    GUID              = '8f04a4d6-1f3c-4f6e-9d69-7b2f11d3a902'
    Author            = 'AxisVela'
    CompanyName       = 'AxisVela'
    Copyright         = '(c) AxisVela. MIT License.'
    Description       = 'PowerShell Core wrapper for the C# PRAXO-CORE framework.'
    PowerShellVersion = '7.4'
    FunctionsToExport = @(
        'Get-PraxoCoreInfo',
        'New-PraxoStaticModel',
        'New-PraxoSession',
        'New-PraxoAgentOptions',
        'New-PraxoAgent',
        'Invoke-PraxoAgent',
        'Invoke-PraxoAgentStream',
        'New-PraxoToolRegistry',
        'New-PraxoFuncTool',
        'Register-PraxoTool',
        'ConvertFrom-PraxoJson',
        'ConvertTo-PraxoJson',
        'Test-PraxoJsonSchema',
        'Get-PraxoToolCall',
        'Remove-PraxoToolCallMarkup',
        'Get-PraxoPluginManifest',
        'New-PraxoMemoryRecord',
        'New-PraxoMemoryStore',
        'Add-PraxoMemoryRecord',
        'Find-PraxoMemory',
        'New-PraxoPathGrant',
        'New-PraxoPathChecker',
        'Test-PraxoPath',
        'New-PraxoCheckpointAllowlist',
        'Register-PraxoCheckpointType',
        'ConvertTo-PraxoCheckpoint',
        'ConvertFrom-PraxoCheckpoint',
        'New-PraxoContextBudget',
        'Get-PraxoTokenEstimate',
        'Invoke-PraxoContextCompact',
        'New-PraxoPiiRedactor',
        'Invoke-PraxoPiiRedaction',
        'Get-PraxoStreamKinds',
        'New-PraxoHarmovelaSinkOptions',
        'New-PraxoHarmovelaSink',
        'Send-PraxoHarmovelaEvent'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData = @{
        PSData = @{
            Tags       = @('praxo', 'agent', 'core', 'dotnet')
            LicenseUri = 'https://github.com/axisvela/praxo-core/blob/main/LICENSE'
            ProjectUri = 'https://github.com/axisvela/praxo-core'
        }
    }
}
