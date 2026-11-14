$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../../praxo-core-ps/praxo-core-ps.psm1') -Force

$schema = ConvertFrom-PraxoJson '{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}'
$valid = ConvertFrom-PraxoJson '{"name":"ok"}'
$invalid = ConvertFrom-PraxoJson '{}'
if ((Test-PraxoJsonSchema -Schema $schema -Data $valid).Count -ne 0) {
    throw 'valid output was rejected'
}
if ((Test-PraxoJsonSchema -Schema $schema -Data $invalid).Count -eq 0) {
    throw 'invalid output was accepted'
}
Write-Output 'PowerShell structured output example passed'
