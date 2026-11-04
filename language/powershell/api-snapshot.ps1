param([switch]$Check)

$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'praxo-core-ps/praxo-core-ps.psd1'
Import-Module $modulePath -Force

$version = (Get-Content (Join-Path $PSScriptRoot 'VERSION') -Raw).Trim()
$spec = (Get-Content (Join-Path $PSScriptRoot '../../spec/SPEC_VERSION') -Raw).Trim()
$functions = [string[]](Get-Command -Module praxo-core-ps -CommandType Function |
    Select-Object -ExpandProperty Name)
[Array]::Sort($functions, [System.StringComparer]::Ordinal)
$content = @(
    "# PRAXO-CORE PowerShell API $version",
    "# SPEC_VERSION $spec",
    '',
    $functions
) -join "`n"
$content += "`n"
$target = Join-Path $PSScriptRoot "api/$version.txt"

if ($Check) {
    if (-not (Test-Path $target)) {
        throw "missing snapshot: $target"
    }
    if ((Get-Content $target -Raw) -ne $content) {
        throw "snapshot is stale: $target"
    }
    Write-Output "snapshot is current: $target"
    return
}

New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
Set-Content -Path $target -Value $content -NoNewline -Encoding utf8
Write-Output "wrote $target"
