# PowerShell Core Release Notes

## 0.7.0 - 2026-11-15

Source tag `powershell/v0.7.0`.

### Added

- HITL interrupt decisions and session-checkpoint support.



## 0.6.1 - 2026-11-15

### Added

- Human-in-the-loop wrappers over the inherited C# interrupt support:
  `New-PraxoInterruptDecision`, `New-PraxoInterruptHandler`,
  `New-PraxoInterruptApproval`, and `Add-PraxoInterruptTool`.
- Tests and an example for approve, edit reauthorization denial, reject,
  respond, unhandled, and invalid decisions.

### Changed

- Expanded the registry README with a Get started section and a task-oriented example index.

## 0.6.0 - 2026-11-15

Source tag `powershell/v0.6.0`.

### Added

- Tests and documentation for the inherited C# safe-default guards exposed
  through `New-PraxoAgentOptions`: setting `RequirePolicy` rejects agent
  construction without a policy hook, and `RequireToolScope` rejects an empty
  `AllowedTools` list. Both default to `false`; the C# Core owns the behavior.

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
