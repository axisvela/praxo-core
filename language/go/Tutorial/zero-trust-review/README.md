# Go Zero-Trust Policy Review (CY-05)

A bounded first slice of [CY-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a live policy engine. It reads fixed access events for one tenant, identifies
over-granted permissions, and drafts a review-only narrowing. It does not change
live grants, authenticate principals or call a live model.

Run from the repository root:

```bash
go run ./language/go/Tutorial/zero-trust-review --test
go run ./language/go/Tutorial/zero-trust-review
go run ./language/go/Tutorial/zero-trust-review --tenant tenant-200
go run ./language/go/Tutorial/zero-trust-review --simulate-failure
```

Expected test output:

```text
success: tenant-100 overgranted=2 status=draft_only changes=0 reads=1
deny: policy denied reads=0
failure: TENANT_AUDIT_UNAVAILABLE reads=1
```

Both negative commands exit `1`. The package also has a Go test
(`go test ./language/go/Tutorial/zero-trust-review`).

The deterministic model plans three steps and consumes each result:
`read_access_events` returns three fixed events, `overgranted=2` and recommended
narrowings (`svc-a` write→read, `svc-b` admin→read); `draft_policy_change`
returns `status=draft_only`, `review_required=true` and `changes_applied=0`.
Policy limits the tenant and the final `narrow_grants` action; `RequirePolicy` and
`RequireToolScope` are enabled.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-tenant denial, and one read/zero drafts for the simulated audit outage.
No identity provider, live access decisions, permission changes, connector or
production policy engine is implemented. Approval, staged rollout, rollback and
effect reconciliation belong to the consumer.
