# Go incident coordination

A scoped operations tutorial over the Go reference Core. It reads one fixed
`incident-100` snapshot through an application-owned `IncidentSource` interface,
drafts an operator update, and emits events to an application sink. The source
and model are deterministic fixtures. This tutorial does not connect a real
incident system, call a live model, mutate an incident or start a durable
workflow.

Run from the repository root:

```bash
go run ./language/go/Tutorial/incident-coordination --test
go run ./language/go/Tutorial/incident-coordination --incident incident-200
go run ./language/go/Tutorial/incident-coordination --simulate-failure
```

Expected test output:

```text
success: incident-100 severity=high action=notify_oncall status=draft_only writes=0 reads=1 events=3
deny: policy denied reads=0
failure: INCIDENT_SOURCE_UNAVAILABLE reads=1
```

`incident-200` is denied by policy before the source is called and exits `1`.
`--simulate-failure` reads once, reports `INCIDENT_SOURCE_UNAVAILABLE`, and exits
`1`. The package also has a Go test (`go test ./language/go/Tutorial/incident-coordination`).

## Path

1. `read_incident` calls the application-owned `IncidentSource`; the fixture
   returns severity `high`, service `checkout-api`, status `mitigating`, three
   open alerts and `source_fixture` for `incident-100`.
2. `draft_update` returns `status=draft_only`, `review_required=true` and
   `incident_writes=0` for `notify_oncall`.
3. The deterministic model packages the two tool results into a JSON report.
4. An `event.FuncSink` records `run.started`, `tool.call` and `run.completed`,
   which is the telemetry seam an application uses for audit or OTLP export.

The application remains the owner of approval, effect reconciliation and any
later incident write.

## Scope

This is source, local fixture and in-process event evidence. It does not
establish a real incident system, durable long-running operation, live provider,
public hosting or independent adoption. A real source belongs in the application
and must supply its own connection, timeout, authentication, idempotency and
reconciliation contracts. Tool names and report fields are tutorial-local and
are not Core or wire API.
