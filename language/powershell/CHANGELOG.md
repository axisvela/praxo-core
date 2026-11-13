# PowerShell Core Release Notes

## 0.5.3 - 2026-11-13

Source tag `powershell/v0.5.3`.

### Added

- OpenTelemetry wrappers over the C# sink: `New-PraxoOtelSinkOptions`,
  `New-PraxoOtelSink`, and `Send-PraxoOtelEvent`.
- Retriever wrappers over the C# document/retriever seam: `New-PraxoDocument`,
  `New-PraxoFuncRetriever`, and `Invoke-PraxoRetrieve`.
- Synchronous subagent delegation over the C# manager: `New-PraxoFuncSubagentRunner`,
  `New-PraxoSubagentRequest`, `New-PraxoSubagentManager`, and
  `Invoke-PraxoSubagent`.

## 0.4.2 - 2026-11-12

Source tag `powershell/v0.4.2`.

### Fixed

- Keep the release test focused on transport construction and HTTPS
  enforcement; end-to-end MCP behavior remains covered by the C# Core tests.

## 0.4.1 - 2026-11-12

Source tag `powershell/v0.4.1`.

### Fixed

- Update the wrapper version assertion for the MCP-enabled release.

## 0.4.0 - 2026-11-12

Source tag `powershell/v0.4.0`.

### Added

- `New-PraxoMcpServerOptions`, `New-PraxoMcpStdioTransport`,
  `New-PraxoMcpHttpOptions`, `New-PraxoMcpHttpTransport`, `Connect-PraxoMcp`,
  `Get-PraxoMcpTools`, `Invoke-PraxoMcpTool`, and `Close-PraxoMcp` wrappers
  over the C# MCP client.
