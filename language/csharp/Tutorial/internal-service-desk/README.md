# C# Internal Service Desk (OP-01)

A bounded tutorial slice over the native .NET Core. It reads one fixed fixture,
enforces scope and drafts a review-only result. No production write or external
system access.

## Why this language and runtime?

- **Selection basis:** C# fits .NET services where a review seam can stay
  in-process.
- **Demonstrated fit:** A fixed fixture yields a draft-only result with zero
  writes through scoped tools and policy.
- **Choose when:** Evaluating a review seam in an existing .NET service.
- **Do not choose when:** Seeking production effects or external guarantees.
  Compare the existing controls and review policy first.
- **Evidence limit:** One fixed fixture only; no live system, credentials,
  production effect or quality guarantee. Local validation used
  `dotnet build -p:UseAppHost=false`; CI is configured and pending.

## Run

```bash
dotnet build -p:UseAppHost=false
dotnet bin/Debug/net8.0/Praxo.InternalServiceDesk.dll --test
```

Expected output:

```text
success: request-100 status=draft_only writes=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: REQUEST_DATA_UNAVAILABLE reads=1
```

No production write or external system access is implemented. Approval and effect
reconciliation belong to the consumer.
