# Dart Onboarding Plan (OP-06)

A bounded first slice of [OP-06](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an HR or permissions system. It reads a fixed employee profile and drafts a
review-only learning path. No account provisioning, permissions or live model are
used.

Run from the repository root:

```bash
dart language/dart/Tutorial/onboarding-plan/onboarding.dart --test
dart language/dart/Tutorial/onboarding-plan/onboarding.dart
dart language/dart/Tutorial/onboarding-plan/onboarding.dart --employee employee-200
dart language/dart/Tutorial/onboarding-plan/onboarding.dart --simulate-failure
```

Expected test output: `Dart OP-06 onboarding-plan tutorial: success, denial and dependency failure passed`.
Both negative commands exit nonzero.

`read_profile` returns employee-100 with role `engineer`, level `mid` and two
prerequisites; `draft_onboarding` returns `lessons=3`, `status=draft_only`,
`review_required=true` and `permissions_granted=0`. Policy limits employee and
final `assign_path` action; `requirePolicy` and `requireToolScope` are enabled.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-employee denial, and one read/zero drafts for the simulated profile-source
outage. Real employee data, consent, permissions and learning systems belong to
the consumer.
