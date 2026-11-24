# Dart Meeting Coordination (OP-02)

A bounded first slice of [OP-02](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not full multi-party scheduling or calendar control. It reads a fixed calendar
fixture, checks conflicts, and drafts review-only minutes and tasks. This uses the
source Dart Core with a relative import; no network, credentials or packages are
required.

## Why this language and runtime?

- **Selection basis:** An existing Dart or Flutter application might keep Agent
  execution in its own runtime. This is a conditional fit, not a verified consumer.
- **Demonstrated fit:** A Dart CLI uses a relative Core import and fixture tools.
  This is Core integration only: no Flutter UI, mobile lifecycle, platform channel
  or calendar plugin is exercised.
- **Choose when:** Evaluating the Core seam in an already maintained Dart host.
- **Do not choose when:** Expecting mobile/calendar integration from this CLI or
  selecting a scheduling backend. Compare an existing Node/Python service or a
  direct calendar workflow if no Dart host is required.
- **Evidence limit:** No mobile deployment, offline synchronization or Flutter
  integration claim follows from the CLI checks.

Run from the repository root:

```bash
dart language/dart/Tutorial/meeting-coordination/meeting.dart --test
dart language/dart/Tutorial/meeting-coordination/meeting.dart
dart language/dart/Tutorial/meeting-coordination/meeting.dart --meeting meeting-200
dart language/dart/Tutorial/meeting-coordination/meeting.dart --simulate-failure
```

Expected test output: `Dart OP-02 meeting-coordination tutorial: success, denial and dependency failure passed`.
Both negative commands exit nonzero.

The deterministic model plans three steps and consumes each result: `read_calendar`
returns slot `2026-12-02T10:00Z`, three attendees and zero conflicts; `draft_minutes`
returns `status=draft_only`, `review_required=true` and `invites_sent=0`. Policy
limits the meeting id and the final action, with `requirePolicy` and
`requireToolScope` enabled.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-meeting denial, and one read/zero drafts for the simulated calendar outage.
A failed tool throws, so no later draft executes.

Real calendar APIs, attendee identity, time zones, invitations, durable state and
effect reconciliation belong to the consumer. No live provider, publication
install, independent consumer or production scheduling is claimed.
