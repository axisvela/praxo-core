# Independent C# Consumer

This starter installs the published NuGet package `Praxo.Core==0.8.0` and
verifies an allow/deny governed tool path.

```bash
dotnet run --project language/csharp/examples/consumer
```

Expected output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The starter uses a deterministic model. It does not prove live provider behavior,
authentic identity, durable approvals, or production readiness.
