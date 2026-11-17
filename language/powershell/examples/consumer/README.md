# PowerShell Consumer

This starter is a thin PowerShell wrapper over the C# PRAXO-CORE runtime. The
PowerShell module loads `Praxo.Core.dll`; the agent loop, tools, policy, and
deterministic model behavior are inherited from the C# Core. No network,
credentials, or model service is needed.

From an installed module:

```powershell
Install-Module praxo-core-ps
pwsh -NoProfile -File language/powershell/examples/consumer/consumer.ps1
```

From a source checkout:

```powershell
dotnet build language/csharp/Praxo.Core/Praxo.Core.csproj -c Release
pwsh -NoProfile -File language/powershell/examples/consumer/consumer.ps1
```

The script imports the source module when it is present and otherwise imports
the installed `praxo-core-ps` module.

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
