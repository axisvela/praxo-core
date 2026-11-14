$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../../praxo-core-ps/praxo-core-ps.psm1') -Force

$allowlist = New-PraxoCheckpointAllowlist
Register-PraxoCheckpointType -Allowlist $allowlist -TypeName 'order'
$payload = ConvertFrom-PraxoJson '{"value":"x"}'
$encoded = ConvertTo-PraxoCheckpoint -Allowlist $allowlist -TypeName 'order' -Value $payload
$decoded = ConvertFrom-PraxoCheckpoint -Allowlist $allowlist -Data $encoded
if ($decoded.AsObject()['value'].ToString() -ne 'x') {
    throw 'checkpoint payload did not round trip'
}
Write-Output 'PowerShell checkpoint example passed'
