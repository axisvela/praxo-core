function Get-PraxoBridgeBinary {
    if ($env:PRAXO_BRIDGE_BIN) {
        return $env:PRAXO_BRIDGE_BIN
    }
    $architecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture
    if ($IsWindows) {
        $rid = 'win-x64'
    } elseif ($IsMacOS) {
        $rid = if ($architecture -eq [System.Runtime.InteropServices.Architecture]::Arm64) { 'osx-arm64' } else { 'osx-x64' }
    } else {
        $rid = if ($architecture -eq [System.Runtime.InteropServices.Architecture]::Arm64) { 'linux-arm64' } else { 'linux-x64' }
    }
    $name = if ($IsWindows) { 'praxo-bridge.exe' } else { 'praxo-bridge' }
    $candidate = Join-Path $PSScriptRoot "bin/$rid/$name"
    if (Test-Path $candidate) {
        return $candidate
    }
    return $null
}

function Invoke-PraxoBridge {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments,
        [Parameter(ValueFromPipeline = $true)]
        [string] $InputJson = ""
    )

    process {
        $binary = Get-PraxoBridgeBinary
        if ($binary) {
            $executable = $binary
            $commandArgs = $Arguments
        } else {
            $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
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
