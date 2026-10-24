param(
    [switch]$Race,
    [switch]$Fuzz
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$env:GOWORK = 'off'
function Invoke-Go {
    & go @args
    if ($LASTEXITCODE -ne 0) {
        throw "go $($args -join ' ') failed (exit $LASTEXITCODE)"
    }
}
try {
    Push-Location $root
    Invoke-Go test ./...
    Invoke-Go vet ./...
    Invoke-Go build ./...
    Invoke-Go run honnef.co/go/tools/cmd/staticcheck@latest ./...
    Invoke-Go run golang.org/x/vuln/cmd/govulncheck@latest ./...

    if ($Race) {
        Invoke-Go test -race ./...
    }
    if ($Fuzz) {
        Invoke-Go test ./pkg/plugin -run=^$ -fuzz=FuzzParseManifest -fuzztime=10s
        Invoke-Go test ./pkg/toolcall -run=^$ -fuzz=FuzzParseToolCall -fuzztime=10s
        Invoke-Go test ./pkg/tool/jsonschema -run=^$ -fuzz=FuzzFromJSON -fuzztime=10s
        Invoke-Go test ./pkg/policy -run=^$ -fuzz=FuzzPathChecker -fuzztime=5s
    }
    Write-Output 'release-check passed'
} finally {
    Pop-Location
    Remove-Item Env:GOWORK -ErrorAction SilentlyContinue
}
