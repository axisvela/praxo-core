# Dart CBT exercise (HC-05)

A bounded first slice of [HC-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a therapist or crisis service. It walks a fixed synthetic CBT exercise, keeps
an explicit `human_review` escalation branch and drafts a review-only summary. No
live session, diagnosis, therapist replacement or unsupervised crisis handling.

## Why this language and runtime?

- **Selection basis:** A Dart or Flutter health app could keep a guided exercise and
  escalation branch in the client runtime. No clinical product is verified here.
- **Demonstrated fit:** A CLI exercises a fixed CBT exercise and an explicit
  human-review branch; no live session, diagnosis or therapist is involved.
- **Choose when:** Learning the Core seam for an existing Dart health workflow.
- **Do not choose when:** Seeking clinical care or crisis response. Compare licensed
  clinical guidance, emergency procedures and the existing care pathway first.
- **Evidence limit:** Core integration fixture only; no therapist replacement,
  diagnosis, live session, unsupervised crisis handling or clinical validation.

Run from the repository root:

```bash
dart language/dart/Tutorial/cbt-exercise/cbt_exercise.dart --test
dart language/dart/Tutorial/cbt-exercise/cbt_exercise.dart
dart language/dart/Tutorial/cbt-exercise/cbt_exercise.dart --crisis
dart language/dart/Tutorial/cbt-exercise/cbt_exercise.dart --session session-200
dart language/dart/Tutorial/cbt-exercise/cbt_exercise.dart --simulate-failure
```

Expected test output: `Dart HC-05 cbt-exercise tutorial: success, crisis, denial and dependency failure passed`.
Negative commands exit nonzero.

`read_exercise` returns the `breathing` exercise with 3 steps, `crisis_flag`
false/true and `escalation=human_review` for `session-100`; `draft_summary`
returns `status=draft_only`, `review_required=true`, `escalated` matching the
crisis branch, `therapist_replacement=0` and `unsupervised_crisis=0`. Policy
limits the session and final summary action.

Tests cover success, the crisis-escalation branch, a cross-session denial and the
simulated exercise-index outage. Real clinical care, crisis response and
therapist oversight belong to licensed professionals.
