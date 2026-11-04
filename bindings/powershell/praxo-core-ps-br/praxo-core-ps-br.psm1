function Invoke-PraxoBridge {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments,
        [Parameter(ValueFromPipeline = $true)]
        [string] $InputJson = ""
    )

    process {
        $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        if ($env:PRAXO_BRIDGE_BIN) {
            $executable = $env:PRAXO_BRIDGE_BIN
            $commandArgs = $Arguments
        } else {
            $executable = "go"
            $commandArgs = @("run", (Join-Path $root "cmd/praxo-bridge")) + $Arguments
        }

        $InputJson | & $executable @commandArgs
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            throw "praxo-bridge exited with $code"
        }
    }
}

Export-ModuleMember -Function Invoke-PraxoBridge
