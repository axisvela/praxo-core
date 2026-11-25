# Go AI Infrastructure Agent (AI-native reference application)

A Go HTTP service and CLI where the agent drives the primary incident workflow:
an operator submits an incident intent, the agent searches application-owned
telemetry, diagnoses the suspect, and drafts a review-only remediation. The agent
never executes remediation.

This is the AI-native Go reference application. There is no traditional
application precursor.

## Why this language and runtime?

- **Selection basis:** Go is common for cloud infrastructure, control planes,
  CLIs, and operational services. Standard-library HTTP plus a small service
  boundary is a typical host shape.
- **Demonstrated fit:** The app exposes an HTTP endpoint and CLI, uses
  application-owned telemetry/executor services, Core tool policy, and a
  model-driven trace.
- **Choose when:** Adding an AI operations copilot to an existing Go service or
  CLI that already owns telemetry, identity, and effect boundaries.
- **Do not choose when:** A deterministic runbook or an external remediation
  engine solves the task with less integration and operational cost.
- **Evidence limit:** Deterministic model and fixture telemetry, plus one hosted
  live run. This is not a production cluster, live telemetry, real remediation,
  independent consumer, or production deployment.

## AI-native workflow

1. Submit `POST /api/ops/incidents` with `{"intent": "..."}` and `X-Tenant-Id`.
2. The agent searches telemetry and reads the suspect signal.
3. The model writes a diagnosis and rationale and drafts a review-only remediation.
4. The service returns `executions=0`.
5. An operator approves and performs remediation outside the agent.

If the model is removed, the primary incident workflow disappears.

## Where is the LLM reasoning?

The deterministic tests use a scripted model. They verify the harness, tool
policy, failure paths, and trace shape, not LLM reasoning.

In the live path, the model chooses tools/arguments and writes the diagnosis and
rationale. The report records `agent_trace` with model tool calls and output, and
`model` is `"live"` rather than `"deterministic"`. A hosted DeepSeek
`deepseek-flash` run on 2026-11-25 recorded `model=live`, a three-step trace
(`search_signals(service-100)` -> `draft_remediation` -> final report), a
model-written diagnosis (350 characters) and rationale (523 characters), and
`executions=0`. Set `PRAXO_BASE_URL`, `PRAXO_MODEL`, and `PRAXO_API_KEY` to use
the OpenAI-compatible adapter.

## Host integration

| Boundary | Where |
| --- | --- |
| HTTP route and tenant check | `main.go`, `newHandler` |
| CLI entry | `main.go` |
| Application services | `ops.go` (`telemetryStore`, `executor`) |
| Tools and policy | `ops.go` |
| Trace | `ops.go` (`tracingModel`) |
| Tests | `main_test.go` |

Identity, telemetry persistence, approvals, and effect reconciliation remain
application-owned. The tenant header is a teaching stand-in for a verified
principal.

## Tools and policy

| Tool | Effect | Policy |
| --- | --- | --- |
| `search_signals` | Read-only telemetry search | Service must be `service-100` |
| `draft_remediation` | Saves a model-written review-only remediation | `review_remediation` plus diagnosis/rationale |
| `execute_remediation` | Would execute remediation | Always denied in the agent path |

A `Remediate now` or `Execute remediation` intent is denied before telemetry read,
drafting, or execution.

## Requirements

- Go 1.25 or newer. Local verification used Go 1.25.0.
- No database, model endpoint, or credentials are required for deterministic
  tests.

## Build and test

The module uses a local `replace` to the repository's Go reference source. It
does not install a published module.

```bash
cd language/go/application
go test ./...
```

Expected: eight tests pass, covering success, tenant boundaries, direct
execution denial, out-of-scope service, telemetry failure, validation, invalid
model output, and trace tool selection.

## Run

Deterministic CLI:

```bash
go run . -intent "Investigate the checkout incident."
```

HTTP service:

```bash
go run . -serve
curl -s -X POST http://127.0.0.1:8080/api/ops/incidents \
  -H 'Content-Type: application/json' \
  -H 'X-Tenant-Id: acme' \
  -d '{"intent":"Investigate the checkout incident."}'
```

Expected JSON includes:

- `report.remediation.status = "draft_only"`
- `report.remediation.diagnosis` and `reasoning`/rationale fields
- `report.executions = 0`
- `report.model = "deterministic"`
- `report.agent_trace` with model-selected tools
- `agent.reads = 1`, `agent.drafts = 1`, `agent.executions = 0`

Direct remediation:

```bash
go run . -intent "Remediate now for service-100."
```

Expected: nonzero exit with `AGENT_POLICY_DENIED` and zero effects.

## Live model

```bash
export PRAXO_BASE_URL=https://api.deepseek.com
export PRAXO_MODEL=deepseek-flash
export PRAXO_API_KEY=...
go run . -intent "Investigate the checkout incident using the telemetry."
```

A hosted DeepSeek `deepseek-flash` run on 2026-11-25 recorded `model=live`,
`search_signals` -> `draft_remediation`, a model-written diagnosis/rationale, and
`executions=0`. Verify `report.model = "live"`, model-selected tools in
`report.agent_trace`, and a model-written diagnosis/rationale. Record provider,
endpoint, model, cost, latency, trace, and failures separately. This is not
independent reproduction or production deployment.

## Boundaries

- No live telemetry, production cluster, or deployment.
- No remediation execution, rollback, or device command.
- No durable incident store or exactly-once effect.
- No production identity or approval service.
- Fixture telemetry and in-memory executor are teaching components.
- The module uses local source replacement; it is not registry-install evidence.
- Local deterministic tests and one hosted live run are recorded; the live run is
  not independent adoption or production evidence.
