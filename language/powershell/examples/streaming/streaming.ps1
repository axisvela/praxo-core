$chunks = @('status: ', 'green')
$received = [System.Collections.Generic.List[string]]::new()
$output = ''
foreach ($chunk in $chunks) {
    $output += $chunk
    $received.Add($chunk)
}
if ($output -ne 'status: green' -or ($received -join '') -ne $output) {
    throw 'deltas did not reconstruct the output'
}
Write-Output 'PowerShell streaming example passed'
