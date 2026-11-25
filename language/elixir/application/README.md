# Elixir AI Ops Copilot (AI-native OTP reference application)

An OTP service where the agent drives the primary incident workflow: an operator
submits an incident intent, the agent searches supervised telemetry, diagnoses the
suspect, and drafts a review-only remediation. The agent never executes
remediation.

This is the AI-native Elixir reference application. There is no traditional
application precursor.

## Why this language and runtime?

- **Selection basis:** Elixir/OTP is typical for real-time messaging, telemetry,
  and high-availability operations. Supervision, process isolation, and restart
  semantics are part of the host, not an add-on.
- **Demonstrated fit:** The application runs a supervised `TelemetryStore` and
  `RemediationExecutor`, and the agent uses those host processes as tools. A test
  kills the telemetry process and verifies supervisor restart.
- **Choose when:** Adding an AI operations copilot to an existing BEAM service that
  already owns telemetry, incident state, and operator approval.
- **Do not choose when:** A static runbook or an external remediation engine
  satisfies the task with less integration and operational cost.
- **Evidence limit:** Fixture telemetry, in-memory executor counters, and a
  deterministic model. This is not a production cluster, live telemetry, real
  remediation, or an independent consumer.

## AI-native workflow

1. An operator submits an incident intent.
2. The agent searches telemetry through the supervised `TelemetryStore`.
3. The model diagnoses the suspect and drafts a review-only remediation.
4. The application returns a JSON report with `executions=0`.
5. An operator approves and performs remediation outside the agent path.

If the model is removed, the primary incident workflow disappears.

## Where is the LLM reasoning?

There are two different kinds of evidence:

- The deterministic tests use a scripted model. They verify the harness, tool
  policy, OTP boundaries, and trace shape. They do **not** demonstrate LLM
  reasoning.
- The live-model path is where reasoning appears: the model chooses tools and
  arguments, interprets telemetry, and writes the `diagnosis` and `rationale`
  saved by `draft_remediation`. The result records `agent_trace` with the model's
  tool calls and model output, and `model` is `"live"` rather than
  `"deterministic"`.

A hosted DeepSeek `deepseek-flash` run on 2026-11-25 recorded `model=live`: the
model chose `search_signals(service-100)`, then `draft_remediation` with a
model-written diagnosis and rationale, and finished with `executions=0`. An
earlier attempt used the display name `checkout` and was policy-denied before the
authorized service id was added to the prompt; the model then corrected itself.
This is one local hosted run, not independent reproduction or production
deployment.

## OTP integration

| Boundary | Where |
| --- | --- |
| Application supervision tree | `lib/praxo_ops/application.ex` |
| Supervised telemetry | `lib/praxo_ops/telemetry_store.ex` |
| Supervised remediation executor | `lib/praxo_ops/remediation_executor.ex` |
| Governed agent | `lib/praxo_ops/incident_agent.ex` |
| Supervision test | `test/praxo_ops/supervision_test.exs` |
| Workflow tests | `test/praxo_ops/incident_agent_test.exs` |

The `TelemetryStore` and `RemediationExecutor` are `one_for_one` children. Killing
the telemetry process restarts it under the supervisor; the test asserts a new PID
and a working search.

## Tools and policy

| Tool | Effect | Policy |
| --- | --- | --- |
| `search_signals` | Read-only telemetry search | Service must be `service-100` |
| `draft_remediation` | Drafts a review-only remediation | Only `review_remediation` |
| `execute_remediation` | Would execute remediation | Always denied in the agent path |

A `Remediate now` or `Execute remediation` intent is denied before telemetry read,
drafting, or execution.

## Requirements

- Elixir 1.14 or newer on OTP 26 or newer. Local verification used Elixir 1.20.4 /
  OTP 29.
- No database, model endpoint, or credentials are required for the deterministic
  tests.

## Install and test

The default dependency is published Hex `praxo_core ~> 0.10.0`:

```bash
cd language/elixir/application
mix deps.get
mix test
```

For a repository-local source checkout where Hex is unavailable, use the path
dependency:

```bash
cd language/elixir/application
PRAXO_CORE_PATH=.. mix test
```

PowerShell:

```powershell
$env:PRAXO_CORE_PATH = '..'
mix test
```

Local verification used source mode because the local Hex TLS path failed with an
unknown CA. The CI job uses the published Hex package. Do not treat source-mode
tests as registry-install evidence.

Expected: six tests pass, covering the review-only package, direct-execution
denial, out-of-scope service and tenant denial, telemetry failure, and supervisor
restart.

## Run

```bash
cd language/elixir/application
PRAXO_CORE_PATH=.. mix run -e 'IO.inspect(PraxoOps.IncidentAgent.run("acme", "service-100", "Investigate the checkout incident."))'
```

Expected report:

- `remediation.status = "draft_only"`
- `remediation.review_required = true`
- `remediation.diagnosis` and `remediation.rationale` from the model
- `executions = 0`
- `model = "deterministic"` for the fixture run
- `agent_trace` with the tool calls and model outputs
- stats `reads = 1`, `drafts = 1`, `executions = 0`

Direct remediation intent:

```bash
PRAXO_CORE_PATH=.. mix run -e 'IO.inspect(PraxoOps.IncidentAgent.run("acme", "service-100", "Remediate now."))'
```

Expected: `{:error, "AGENT_POLICY_DENIED", ...}` with zero effects.

## Optional live model

Set an OpenAI-compatible endpoint to replace the deterministic model:

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
export PRAXO_API_KEY=
PRAXO_CORE_PATH=.. mix run -e 'IO.inspect(PraxoOps.IncidentAgent.run("acme", "service-100", "Investigate the checkout incident."))'
```

The live model receives the same tool schemas and policy. This is the path that
shows LLM reasoning: verify that `model = "live"`, the `agent_trace` records the
model's chosen tool calls, and the remediation contains a model-written diagnosis
and rationale rather than the deterministic fixture text. A hosted DeepSeek
`deepseek-flash` run on 2026-11-25 recorded those fields with `executions=0`.
This is one local hosted run; record provider, endpoint, model, cost, latency,
trace, and failures separately. It is not independent reproduction or production
deployment.

## Boundaries

- No live telemetry, production cluster, or distribution.
- No remediation execution, rollback, or device command.
- No durable incident store or exactly-once effect.
- No production identity or approval service.
- Fixture telemetry and in-memory executor are teaching components.
- Local evidence is source-mode deterministic host integration plus one hosted
  live-model run; the Hex install and CI result are separate evidence.
- The deterministic `agent_trace` proves trace plumbing, not model reasoning; the
  live run is the reasoning evidence.
