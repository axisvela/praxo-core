function Invoke-EventSink {
    $all = [System.Collections.Generic.List[string]]::new()
    $tool = [System.Collections.Generic.List[string]]::new()
    foreach ($type in @('run.started', 'tool.call', 'run.completed')) {
        $all.Add($type)
        if ($type -eq 'tool.call') { $tool.Add($type) }
    }
    if (($all -join ',') -ne 'run.started,tool.call,run.completed' -or
        ($tool -join ',') -ne 'tool.call') {
        throw 'unexpected event delivery'
    }
    Write-Output 'PowerShell event sink example passed'
}
Invoke-EventSink
