@{
    RootModule        = 'praxo-core-ps-br.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '1f4f058e-4a1f-4f69-9f0d-0b2f4f7b8c11'
    Author            = 'AxisVela'
    CompanyName       = 'AxisVela'
    Copyright         = '(c) AxisVela. MIT License.'
    Description       = 'PowerShell bridge for PRAXO-CORE over the praxo-bridge CLI.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @('Invoke-PraxoBridge')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData = @{
        PSData = @{
            Tags       = @('praxo', 'agent', 'bridge')
            LicenseUri = 'https://github.com/axisvela/praxo-core/blob/main/LICENSE'
            ProjectUri = 'https://github.com/axisvela/praxo-core'
        }
    }
}
