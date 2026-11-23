# Nim Maintenance Triage (IN-01)

A bounded first slice of [IN-01](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a predictive-maintenance model. It reads fixed sensor telemetry for one device,
marks the indicator elevated, and drafts a review-only work order. This uses the
source Nim Core; no network, credentials or packages beyond Nim and a C compiler
are required.

Build and run from the repository root:

```bash
nim c --path:language/nim/src --hints:off --out:build/nim-maintenance language/nim/Tutorial/maintenance-triage/maintenance.nim
./build/nim-maintenance --test
./build/nim-maintenance
./build/nim-maintenance --device device-200
./build/nim-maintenance --simulate-failure
```

Expected test output:

```text
success: device-100 indicator=elevated status=draft_only writes=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: TELEMETRY_UNAVAILABLE reads=1
```

Both negative commands exit nonzero.

The deterministic model plans three steps and consumes each result: `read_telemetry`
returns vibration `4.2`, temperature `71` and `indicator=elevated`; `draft_workorder`
returns `status=draft_only`, `review_required=true` and `writes=0`. The policy
receives tool name and arguments, limiting both the device and the final action;
`requirePolicy` and `requireToolScope` are enabled.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-device denial, and one read/zero drafts for the simulated sensor outage.
This is a fixed indicator, not a validated failure prediction.

Real sensor transports, predictive models, technician dispatch, approval identity
and effect reconciliation belong to the consumer. No live provider, publication,
independent consumer or production maintenance claim is made.
