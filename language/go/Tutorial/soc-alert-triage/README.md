# Go SOC alert triage

A scoped security-operations tutorial over the Go reference Core. It reads one
fixed `alert-100` snapshot through an application-owned `AlertSource`, redacts
personal data with Core's `PIIRedactor`, drafts a review-only host isolation and
emits events to an application sink. The source and model are deterministic
fixtures. This tutorial does not connect a real SIEM, run a host action, call a
live model or make a containment decision.

Run from the repository root:

```bash
go run ./language/go/Tutorial/soc-alert-triage --test
go run ./language/go/Tutorial/soc-alert-triage --alert alert-200
go run ./language/go/Tutorial/soc-alert-triage --simulate-failure
```

Expected test output:

```text
success: alert-100 severity=high action=isolate_host status=draft_only writes=0 reads=1 pii=redacted
deny: policy denied reads=0
failure: ALERT_SOURCE_UNAVAILABLE reads=1
```

`alert-200` is denied by policy before the source is called and exits `1`.
`--simulate-failure` reads once, reports `ALERT_SOURCE_UNAVAILABLE`, and exits `1`.
The package also has a Go test (`go test ./language/go/Tutorial/soc-alert-triage`).

## Path

1. `read_alert` calls the application-owned `AlertSource`; the fixture returns
   severity `high`, host `edge-web-01`, technique `brute_force`, 42 events and
   reporter PII for `alert-100`.
2. Core's `PIIRedactor` (default rules) rewrites tool results before they are
   model-bound, so the email and phone become `[REDACTED:email]` and
   `[REDACTED:phone]`.
3. `draft_containment` returns `status=draft_only`, `review_required=true` and
   `host_actions=0` for `isolate_host`.
4. The deterministic model packages the redacted evidence and the draft into a
   JSON report; an `event.FuncSink` records `run.started`, `tool.call` and
   `run.completed` for audit.

The application remains the owner of approval, host actions, retention and any
SIEM/EDR integration.

## Scope

This is source, local fixture and in-process redaction/event evidence. It does
not establish a real SIEM connection, detection quality, host isolation, live
provider, public hosting or independent adoption. Live tool arguments, errors and
event payloads are not redacted by this middleware; the application owns those
trust boundaries. Tool names and report fields are tutorial-local and are not
Core or wire API.
