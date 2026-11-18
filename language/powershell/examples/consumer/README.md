# PowerShell Consumer

This starter is a thin PowerShell wrapper over the C# PRAXO-CORE runtime. The
PowerShell module loads `Praxo.Core.dll`; the agent loop, tools, policy, and
deterministic model behavior are inherited from the C# Core. No network,
credentials, or model service is needed.

From an installed module:

```powershell
Install-Module praxo-core-ps -RequiredVersion 0.7.2
pwsh -NoProfile -File language/powershell/examples/consumer/consumer.ps1 -UseInstalledModule
```

For an isolated package download without installing into the user module path:

```powershell
New-Item -ItemType Directory -Path ./modules -Force | Out-Null
Save-PSResource praxo-core-ps -Version 0.7.2 -Path ./modules -TrustRepository
$env:PSModulePath = (Resolve-Path ./modules).Path + [IO.Path]::PathSeparator + $env:PSModulePath
pwsh -NoProfile -File language/powershell/examples/consumer/consumer.ps1 -UseInstalledModule
```

The destination directory must exist. The `Save-PSResource` path and packaged
module/DLL consumer were verified locally; `Install-Module` itself was not
tested in that run. See the
[verification evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/)
for toolchain and network limits.

From a source checkout:

```powershell
dotnet build language/csharp/Praxo.Core/Praxo.Core.csproj -c Release
pwsh -NoProfile -File language/powershell/examples/consumer/consumer.ps1
```

The `-UseInstalledModule` switch explicitly selects installed version `0.7.2`
even inside a source checkout. It fails if the package is unavailable, rather
than falling back to the source module. Unset `PRAXO_CORE_DLL` before running
this mode so that the module uses its packaged assembly.

Without this switch, the script imports the source module when it is present
and otherwise imports the installed `praxo-core-ps` module. A source-mode pass
is not evidence of a successful Gallery install.

Run the module-selection regressions from the repository root:

```powershell
pwsh -NoProfile -File language/powershell/examples/consumer/consumer.tests.ps1
```

These check the source allow/deny path, missing installed-package failure
without source fallback, and rejection of `PRAXO_CORE_DLL` in installed mode.
They do not replace a Gallery download and installed-package run.

Expected output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The deterministic model requests one `record` tool call. An explicit tool scope
limits calls to `record`, and the policy denies the target `private`. A rejected
call must leave the in-memory counter at zero.

Set `PRAXO_CORE_DLL` if `Praxo.Core.dll` is built somewhere other than the
default Release or Debug output directory.
