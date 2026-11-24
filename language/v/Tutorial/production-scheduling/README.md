# V Production Scheduling (IN-02)

A bounded first slice of [IN-02](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an APS/MES integration. It reads a fixed job queue, computes a deterministic
priority order, and drafts review-only MES/AGV instructions. This uses the source
V Core; no network, credentials or packages beyond V are required.

## Why this language and runtime?

- **Selection basis:** An existing V application may need an in-process Core.
  No named production-scheduling consumer is established here.
- **Demonstrated fit:** The source V Core executes fixture tools and policy checks.
  This is Core integration only, not an exercised MES or scheduling engine.
- **Choose when:** Evaluating Core inside an existing V tool with a V toolchain.
- **Do not choose when:** Selecting a new production scheduler. Compare C++, Go
  or Python against actual solver, device SDK and deployment requirements; this
  example establishes no advantage over them.
- **Evidence limit:** No comparative performance, binary-size or deployment
  advantage has been measured.

Build and run from the repository root:

```bash
v -path "language/v|@vlib|@vmodules" -o build/v-schedule language/v/Tutorial/production-scheduling/schedule.v
./build/v-schedule --test
./build/v-schedule
./build/v-schedule --line line-200
./build/v-schedule --simulate-failure
```

Expected test output:

```text
success: line-100 first=job-b status=draft_only dispatched=false reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: SCHEDULE_SOURCE_UNAVAILABLE reads=1
```

Both negative commands exit nonzero.

The deterministic model plans three steps and consumes each result: `read_jobs`
returns three fixed jobs and a recommended order (`job-b`, `job-c`, `job-a`) by
priority then due time; `draft_schedule` returns `status=draft_only`,
`review_required=true` and `dispatched=false`. The V `policy_action` hook receives
tool name and arguments, limiting the line and final `replan` action;
`require_policy` and `require_tool_scope` are enabled.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-line denial, and one read/zero drafts for the simulated schedule-source
outage. The tool seam returns an error object for that outage; the model reports
`SCHEDULE_SOURCE_UNAVAILABLE` and no draft executes.

Real ERP/MES data, capacity constraints, AGV dispatch, approvals and effect
reconciliation belong to the consumer. No live provider, publication, independent
consumer or production scheduling is claimed.
