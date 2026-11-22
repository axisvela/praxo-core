# Windows Diagnostics Agent

A read-only Windows operations tutorial. PowerShell calls the shared C# Core
through `praxo-core-ps`; the Agent has two fixed tools, `read_service` and
`read_disk`. It produces a structured report and never executes a model-selected
command, changes a service, deletes files, or performs a repair.

This is an application-shaped operations slice, not a monitoring platform or a
general remote administration agent.

## Run the Portable Fixture

Fixture mode needs no Windows service access and no model endpoint. From this
directory:

```powershell
pwsh -NoProfile -File diagnostics.ps1
```

Published-module mode loads PowerShell Gallery `praxo-core-ps` version `0.8.1`.
Install it first:

```powershell
Install-Module praxo-core-ps -RequiredVersion 0.8.1
pwsh -NoProfile -File diagnostics.ps1
```

Unset `PRAXO_CORE_DLL` in this mode so the package assembly is used. For a source
checkout, build the C# Core first:

```powershell
dotnet build language/csharp/Praxo.Core/Praxo.Core.csproj -c Debug
pwsh -NoProfile -File diagnostics.ps1 -SourceMode
```

## Run Read-Only Local Checks

```powershell
pwsh -NoProfile -File diagnostics.ps1 -SourceMode -LocalMachine
```

Local mode reads:

- `Get-Service Spooler` (status only);
- the system drive `Get-PSDrive` free space.

It does not require administrator rights, a remote host, or a shell command. The
tool allowlist and policy fix the service and disk names. `-LocalMachine` is
rejected outside Windows.

Fixture output has this shape:

```json
{"checks":[{"kind":"service","status":"Running","name":"Spooler","source":"fixture"},{"free_bytes":10737418240,"kind":"disk","name":"system","source":"fixture"}],"mutating_tools_registered":false,"read_calls":2}
```

Local output uses `"source":"local_machine"`. The result is a report for a human
operator; it is not an effect ledger or a background monitor.

## Failure Checks

```powershell
pwsh -NoProfile -File diagnostics.ps1 -SourceMode -ServiceName WinRM
pwsh -NoProfile -File diagnostics.ps1 -SourceMode -SimulateFailure
```

The first request is denied by Agent policy before any read (`reads=0`). The
second simulates an unavailable diagnostic dependency after one read attempt
(`reads=1`); it exits nonzero without printing a successful report. Neither path
mutates a service or disk.

## Tests

```powershell
pwsh -NoProfile -File tests.ps1 -SourceMode -IncludeLocalMachine
```

The script covers fixture success, fixed-scope denial, simulated dependency
failure and Windows local reads. It launches each case in an isolated `pwsh`
process and checks exit status and read counts. Windows CI runs this source-mode
suite; it does not test a Gallery install or a real model.

## Boundaries

- PowerShell is a wrapper over the shared C# Core, not a separate agent loop.
- There is no live model mode here; the deterministic fixture selects the two
  approved tools.
- No arbitrary order of commands, URLs, service names, file paths or shell
  fragments come from the model at runtime.
- No repair, restart, scheduled task, remote host, WMI query, registry write or
  elevated operation is implemented.
- Public fixture output is teaching data. Production identity, approvals,
  durable audit, alert routing and OS isolation remain integration responsibilities.
- A successful local read does not establish production monitoring, security
  hardening or independent adoption.
