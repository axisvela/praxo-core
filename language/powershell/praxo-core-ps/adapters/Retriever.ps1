function New-PraxoDocument {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Content,
        [hashtable]$Metadata = @{},
        [double]$Score = 0
    )
    Import-PraxoCoreAssembly
    $document = [Praxo.Core.Retriever.Document]::new()
    $document.Id = $Id
    $document.Content = $Content
    foreach ($key in $Metadata.Keys) {
        $document.Metadata[$key] = [string]$Metadata[$key]
    }
    $document.Score = $Score
    $document
}

function New-PraxoFuncRetriever {
    param([Parameter(Mandatory = $true)][scriptblock]$Retrieve)
    Import-PraxoCoreAssembly
    $wrapped = {
        param($query, $limit)
        $result = & $Retrieve $query $limit
        $list = [System.Collections.Generic.List[Praxo.Core.Retriever.Document]]::new()
        foreach ($item in @($result)) {
            $list.Add([Praxo.Core.Retriever.Document]$item)
        }
        [System.Threading.Tasks.Task[System.Collections.Generic.List[Praxo.Core.Retriever.Document]]]::FromResult($list)
    }.GetNewClosure()
    $delegate = [System.Management.Automation.LanguagePrimitives]::ConvertTo(
        $wrapped,
        [System.Func[string, int, System.Threading.Tasks.Task[System.Collections.Generic.List[Praxo.Core.Retriever.Document]]]]
    )
    [Praxo.Core.Retriever.FuncRetriever]::new($delegate)
}

function Invoke-PraxoRetrieve {
    param(
        [Parameter(Mandatory = $true)]$Retriever,
        [Parameter(Mandatory = $true)][string]$Query,
        [int]$Limit = 10
    )
    $Retriever.RetrieveAsync($Query, $Limit).GetAwaiter().GetResult()
}

$script:PraxoAdapterExports = @($script:PraxoAdapterExports) + @(
    'New-PraxoDocument',
    'New-PraxoFuncRetriever',
    'Invoke-PraxoRetrieve'
)
