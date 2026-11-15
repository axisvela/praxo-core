# PowerShell Multi-turn Checkpoint Recovery

This example saves and restores a conversation history across two agent turns.
It uses the module's `New-PraxoSession` and `Invoke-PraxoAgent` over the C#
Core runtime, plus the Core checkpoint allowlist and a teaching in-memory store.
Production storage and retention remain application-owned.

From the repository root:

```powershell
dotnet build language/csharp/Praxo.Core/Praxo.Core.csproj -c Release
pwsh -NoProfile -File language/powershell/examples/session-checkpoint/session_checkpoint.ps1
```

Expected output:

```text
restored messages: 4
output: turn 5
```

The source is a deterministic self-check: the fixture model returns
`turn <request message count>`, and the example throws if the second turn is not
`turn 3` or the third turn is not `turn 5`. The second turn runs against the
first checkpoint, then the updated history is saved and reloaded for the third
turn. A checkpoint is a recovery hint, not a transaction or an exactly-once
guarantee.

Set `PRAXO_CORE_DLL` if `Praxo.Core.dll` is built somewhere other than the
default Release or Debug output directory.
