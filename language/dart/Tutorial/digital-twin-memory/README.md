# Dart digital twin memory (OG-06)

A bounded first slice of [OG-06](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a personal memory hub. It stores one consent-scoped synthetic memory, recalls
only that scope and confirms deletion. No real inbox, passwords, cross-app access
or unrestricted recall.

Run from the repository root:

```bash
dart language/dart/Tutorial/digital-twin-memory/digital_twin.dart --test
dart language/dart/Tutorial/digital-twin-memory/digital_twin.dart
dart language/dart/Tutorial/digital-twin-memory/digital_twin.dart --account account-200
dart language/dart/Tutorial/digital-twin-memory/digital_twin.dart --simulate-failure
```

Expected test output: `Dart OG-06 digital-twin-memory tutorial: success, denial and dependency failure passed`.
Both negative commands exit nonzero.

`store_memory` records `memory-100` with `scope=work`, `consent=true` and
provenance; `recall_memories` returns only work-scoped memories with
`unscoped=0`; `forget_memory` returns `deleted=true` and `remaining=0`. Policy
limits the account, requires work scope and consent for writes, and limits recall
scope.

Tests assert one store, one recall and one delete on success, zero calls for a
cross-account denial, and one store/zero recall/zero delete for the simulated
store outage. Real persistence, cross-app permissions, consent management and
deletion propagation belong to the consumer.
