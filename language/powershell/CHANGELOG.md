# PowerShell Core Release Notes

## 0.9.1 - 2026-11-27

Source tag `powershell/v0.9.1`.

### Changed

- Add explicit example, scenario-tutorial, and reference-application lists to
  the PowerShell Gallery description. No public API or wire change.

## 0.9.0 - 2026-11-26

Source tag `powershell/v0.9.0`.

- Minor release for AI-native reference applications, scenario tutorials, and the Go examples layout refresh.

## 0.8.1 - 2026-11-21

Source tag `powershell/v0.8.1`.

### Changed

- Expanded the PowerShell Gallery module description and README with Features
  and Limits. No public API or wire change.

## 0.8.0 - 2026-11-20

Source tag `powershell/v0.8.0`.

### Added

- Process plugin host and provider streaming updates.

## 0.7.2 - 2026-11-18

Source tag `powershell/v0.7.2`; PowerShell Gallery publication follows the release workflow.

### Added

- Representative-chain, advanced-delegation, and the expanded task-oriented
  example index, including MCP, OTel/Harmovela, and governance checks.
- Registry README links for the current example set.

### Compatibility

- No public API or wire change; `SPEC_VERSION` remains `0.2.0`.

## 0.7.1 - 2026-11-17

Source tag `powershell/v0.7.1`.

### Changed

- Expanded the PowerShell Gallery description with the project introduction,
  install command, starter, examples, and documentation links.
- Added Gallery release notes.

### Fixed

- `Get-PraxoCoreInfo` falls back to the packaged module manifest for the module
  version and `SPEC_VERSION` when the source `VERSION` and `spec/SPEC_VERSION`
  files are not present in an installed module.

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