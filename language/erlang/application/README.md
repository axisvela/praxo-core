# Erlang AI Ops Copilot (AI-native OTP reference application)

An OTP application where the agent drives the primary incident workflow: an
operator submits an incident intent, the agent searches supervised telemetry,
diagnoses the suspect, and drafts a review-only remediation. The agent never
executes remediation.

This is the AI-native Erlang reference application. There is no traditional
application precursor.

## Why this language and runtime?

- **Selection basis:** Erlang/OTP is typical for telecom, messaging, and
  high-availability operations. Supervision, process isolation, and restart are
  host features, not add-ons.
- **Demonstrated fit:** The application runs a supervised telemetry store and
  remediation executor, and the agent uses those host processes as tools. A test
  kills the telemetry process and verifies supervisor restart.
- **Choose when:** Adding an AI operations copilot to an existing BEAM service that
  already owns telemetry, incident state, and operator approval.
- **Do not choose when:** A static runbook or an external remediation engine
  satisfies the task with less integration and operational cost.
- **Evidence limit:** Fixture telemetry, in-memory executor counters, and a
  deterministic model for tests. This is not a production cluster, live telemetry,
  real remediation, or an independent consumer.

## AI-native workflow

1. An operator submits an incident intent.
2. The agent searches telemetry through the supervised `praxo_ops_telemetry`.
3. The model diagnoses the suspect and drafts a review-only remediation.
4. The application returns a JSON report with `executions=0`.
5. An operator approves and performs remediation outside the agent path.

If the model is removed, the primary incident workflow disappears.

## Where is the LLM reasoning?

The deterministic tests use a scripted model. They verify the harness, tool
policy, OTP boundaries, and trace shape, not LLM reasoning.

In the live path, the model chooses the telemetry/remediation tools and writes the
`diagnosis` and `rationale` saved by `draft_remediation`. The result records
`agent_trace` with tool calls and model output, and `model` is `"live"` rather than
`"deterministic"`. A hosted DeepSeek `deepseek-flash` run on 2026-11-25 recorded
`model=live`: the model chose `search_signals(service-100)`, then
`draft_remediation` with a model-written diagnosis and rationale, and finished with
`executions=0`. The live transport used `httpc` with the local proxy/CA. This is
one local hosted run, not independent reproduction or production deployment.

## OTP integration

| Boundary | Where |
| --- | --- |
| Application supervision tree | `src/praxo_ops_sup.erl` |
| Supervised telemetry | `src/praxo_ops_telemetry.erl` |
| Supervised remediation executor | `src/praxo_ops_executor.erl` |
| Governed agent | `src/praxo_ops_agent.erl` |
| Workflow and supervision tests | `src/praxo_ops_tests.erl` |

The telemetry and executor are `one_for_one` children. Killing the telemetry
process restarts it under the supervisor; the test asserts a new PID and a working
search.

## Tools and policy

| Tool | Effect | Policy |
| --- | --- | --- |
| `search_signals` | Read-only telemetry search | Service must be `service-100` |
| `draft_remediation` | Drafts a model-written review-only remediation | `review_remediation` plus non-empty diagnosis/rationale |
| `execute_remediation` | Would execute remediation | Always denied in the agent path |

A `Remediate now` or `Execute remediation` intent is denied before telemetry read,
drafting, or execution.

## Requirements

- Erlang/OTP 26 or newer. Local verification used OTP 29.
- Python 3 for the test runner.
- No database, model endpoint, or credentials are required for the deterministic
  tests.

## Build and test

The runner compiles the Erlang Core sources plus this application into
`build/ebin` and runs the workflow/supervision tests. It uses the local Core source,
not a registry install.

```bash
cd language/erlang/application
python run-tests.py
```

If `erlc`/`erl` are not on `PATH`, set `ERLC` and `ERL`:

```powershell
$env:ERLC = 'D:\dev\Erlang OTP\bin\erlc.exe'
$env:ERL = 'D:\dev\Erlang OTP\bin\erl.exe'
python run-tests.py
```

Expected: six tests pass, covering the review-only package, direct-execution
denial, service/tenant denial, telemetry failure, and supervisor restart.

## Live model

The live path uses the Erlang OpenAI-compatible adapter. Set `PRAXO_BASE_URL`,
`PRAXO_MODEL`, and `PRAXO_API_KEY`, plus `PRAXO_CA_BUNDLE` and
`PRAXO_HTTP_PROXY` when the workstation requires a proxy, then run the escript
after building:

```bash
python run-tests.py
escript live.escript
```

A hosted DeepSeek `deepseek-flash` run recorded `model=live`, the
`search_signals` -> `draft_remediation` trace, a model-written diagnosis and
rationale, and `executions=0`. Record provider, endpoint, model, cost, latency,
trace, and failures separately. This is not independent reproduction or
production deployment.

## Boundaries

- No live telemetry, production cluster, or distribution.
- No remediation execution, rollback, or device command.
- No durable incident store or exactly-once effect.
- No production identity or approval service.
- Fixture telemetry and in-memory executor are teaching components.
- The runner uses source-mode compilation; Hex/rebar registry installation and CI
  are separate evidence and have not been run.
- Local deterministic tests and one hosted live run are recorded; the live run
  used `httpc` proxy/CA and is not independent adoption or production.
