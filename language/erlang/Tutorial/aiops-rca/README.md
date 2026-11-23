# Erlang AIOps RCA (SE-06)

A bounded first slice of [SE-06](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a production incident platform. It correlates fixed trace/metric/log signals
and drafts a review-only rollback. This uses the source Erlang Core through
`escript`; no network, credentials or packages beyond Erlang/OTP are required.

Compile the Core once, then run from the repository root:

```bash
mkdir -p language/erlang/build/ebin
erlc -I language/erlang/src -o language/erlang/build/ebin language/erlang/src/*.erl
escript language/erlang/Tutorial/aiops-rca/rca.escript --test
escript language/erlang/Tutorial/aiops-rca/rca.escript
escript language/erlang/Tutorial/aiops-rca/rca.escript --service service-200
escript language/erlang/Tutorial/aiops-rca/rca.escript --simulate-failure
```

Expected test output:

```text
success: service-100 suspect=checkout-api status=draft_only actions=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: TELEMETRY_UNAVAILABLE reads=1
```

Both negative commands exit nonzero.

The function-model callback plans three steps and consumes each result:
`read_signals` returns error rate `0.18`, latency `940`, suspect
`checkout-api`, trace `trace-100` and a fixture source; `draft_rollback` returns
`status=draft_only`, `review_required=true` and `actions=0`. Policy receives tool
name and arguments, limiting the service and final `rollback` action;
`require_policy` and `require_tool_scope` are enabled.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-service denial, and one read/zero drafts for the simulated telemetry
outage. The tool returns an error object for that outage; the model reports
`TELEMETRY_UNAVAILABLE` and no rollback executes.

Real telemetry, root-cause scoring, runbook execution, approvals, isolation and
effect reconciliation belong to the consumer. No live provider, publication,
independent consumer or production remediation is claimed.
