# Delphi / Free Pascal Legacy Migration (SE-03)

A bounded first slice of [SE-03](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an automatic production migration. It inventories fixed legacy modules and
dependencies and drafts a review-only migration plan. This uses the source
Delphi/Free Pascal Core; no network, credentials or additional units are required.

## Why this language and runtime?

- **Selection basis:** Legacy Windows applications often remain in Delphi/Free Pascal,
  where replacing the host is riskier than adding a reviewed plan.
- **Demonstrated fit:** Fixed modules and dependencies produce a review-only migration
  plan; no source is rewritten or deployed.
- **Choose when:** Planning work beside an existing Delphi codebase.
- **Do not choose when:** Seeking automated migration or dependency resolution. Compare
  the actual build graph and staged migration process first.
- **Evidence limit:** Core integration fixture only; no real repository scan, code
  transformation, build verification or production migration.

Build and run from `language/delphi` (so `-Fu.` finds the Core units):

```bash
cd language/delphi
fpc -Mobjfpc -Scghi -O2 -Fu. -FEbuild Tutorial/legacy-migration/inventory.pas
./build/inventory --test
./build/inventory
./build/inventory --repo repo-200
./build/inventory --simulate-failure
```

On Windows use `build\inventory.exe`. Expected test output:

```text
success: repo-100 modules=3 status=draft_only changes_applied=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: LEGACY_SOURCE_UNAVAILABLE reads=1
```

Both negative commands exit nonzero.

The deterministic host plans three steps and consumes each result: `read_legacy`
returns three synthetic modules, one dependency edge, migration steps and a
fixture source; `draft_migration` returns `status=draft_only`,
`review_required=true` and `changes_applied=0`. The Free Pascal Core exposes only
the action kind to the policy, so repository and final-action checks run inside
the tool seams before any counter or effect. `RequirePolicy` and
`RequireToolScope` are enabled.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-repository denial, and one read/zero drafts for the simulated source
outage. The failing read raises `LEGACY_SOURCE_UNAVAILABLE` before any draft.

This build uses `-Scghi -Fu.` without `-Facwstring`; the local 32-bit Free Pascal
installation does not ship `cwstring`. Commercial Delphi compatibility, real
dependency graphs, automated refactoring, approvals and effect reconciliation
belong to the consumer. No live provider, publication, independent consumer or
production migration is claimed.
