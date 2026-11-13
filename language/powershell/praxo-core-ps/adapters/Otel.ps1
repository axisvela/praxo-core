function New-PraxoOtelSinkOptions {
    param(
        [string]$Endpoint = 'http://127.0.0.1:4318/v1/traces',
        [string]$ServiceName = 'praxo-core',
        [string[]]$AllowedDataKeys = @(),
        [int]$TimeoutSeconds = 30
    )
    Import-PraxoCoreAssembly
    $options = [Praxo.Core.OtelSinkOptions]::new()
    $options.Endpoint = $Endpoint
    $options.ServiceName = $ServiceName
    $options.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)
    foreach ($key in $AllowedDataKeys) {
        $options.AllowedDataKeys.Add($key)
    }
    $options
}

function New-PraxoOtelSink {
    param(
        [Parameter(Mandatory = $true)]$Options,
        [scriptblock]$Transport
    )
    Import-PraxoCoreAssembly
    if ($Transport) {
        $delegate = [System.Management.Automation.LanguagePrimitives]::ConvertTo(
            $Transport,
            [Praxo.Core.OtelTransport]
        )
        [Praxo.Core.OtelSink]::new($Options, $delegate)
    } else {
        [Praxo.Core.OtelSink]::new($Options)
    }
}

function Send-PraxoOtelEvent {
    param(
        [Parameter(Mandatory = $true)]$Sink,
        [Parameter(Mandatory = $true)]$Event
    )
    $Sink.Emit($Event)
}

$script:PraxoAdapterExports = @($script:PraxoAdapterExports) + @(
    'New-PraxoOtelSinkOptions',
    'New-PraxoOtelSink',
    'Send-PraxoOtelEvent'
)
