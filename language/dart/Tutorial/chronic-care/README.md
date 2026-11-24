# Dart chronic care (HC-02)

A bounded first slice of [HC-02](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a clinical decision system. It summarizes fixed synthetic wearable trends and
routes a review-only care alert. No dosage change, individualized treatment change
or live device feed.

## Why this language and runtime?

- **Selection basis:** A Dart or Flutter patient app could keep trend summaries and a
  care-team review alert in the client runtime. No health consumer is verified.
- **Demonstrated fit:** Fixed wearable trends produce a review-only alert; no device
  SDK, dosage logic or treatment recommendation runs.
- **Choose when:** Learning the Core seam in an existing Dart health app.
- **Do not choose when:** Seeking clinical decision support or device integration.
  Compare the care team's protocol and the wearable platform first.
- **Evidence limit:** Core integration fixture only; no device feed, clinical
  validation, dosage change, treatment decision or patient safety claim.

Run from the repository root:

```bash
dart language/dart/Tutorial/chronic-care/chronic_care.dart --test
dart language/dart/Tutorial/chronic-care/chronic_care.dart
dart language/dart/Tutorial/chronic-care/chronic_care.dart --patient patient-200
dart language/dart/Tutorial/chronic-care/chronic_care.dart --simulate-failure
```

Expected test output: `Dart HC-02 chronic-care tutorial: success, denial and dependency failure passed`.
Both negative commands exit nonzero.

`read_trends` returns 7 days, resting heart rate 78 against a 75 threshold, a
rising trend and `alert=true` for `patient-100`; `draft_alert` returns
`routed_to=care_team`, `status=draft_only`, `review_required=true`,
`dosage_changes=0` and `treatment_changes=0`. Policy limits the patient and final
`draft_alert` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-patient denial, and one read/zero drafts for the simulated trends outage.
Real device integration, clinical review and treatment decisions belong to the
care team.
