param(
    [switch]$Race,
    [switch]$Fuzz
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$env:GOWORK = 'off'
try {
    Push-Location $root
    go test ./...
    go vet ./...
    go build ./...
    go run honnef.co/go/tools/cmd/staticcheck@latest ./...
    go run golang.org/x/vuln/cmd/govulncheck@latest ./...

    if ($Race) {
        go test -race ./...
    }
    if ($Fuzz) {
        go test ./pkg/plugin -run=^$ -fuzz=FuzzParseManifest -fuzztime=10s
        go test ./pkg/toolcall -run=^$ -fuzz=FuzzParseToolCall -fuzztime=10s
        go test ./pkg/tool/jsonschema -run=^$ -fuzz=FuzzFromJSON -fuzztime=10s
        go test ./pkg/policy -run=^$ -fuzz=FuzzPathChecker -fuzztime=5s
    }
    Write-Output 'release-check passed'
} finally {
    Pop-Location
    Remove-Item Env:GOWORK -ErrorAction SilentlyContinue
}
