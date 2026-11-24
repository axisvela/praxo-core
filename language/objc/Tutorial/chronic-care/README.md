# Objective-C Chronic Care (HC-02)

Summarizes a fixed wearable trend and drafts a review-only care alert. No dosage
or individualized treatment change.

## Why this language and runtime?

- **Selection basis:** Existing Apple applications can run the follow-up review
  in-process with Foundation.
- **Demonstrated fit:** A deterministic model reads fixed trends and drafts one
  alert through native Objective-C Core tools.
- **Choose when:** Evaluating the Core seam inside a Foundation-based health app.
- **Do not choose when:** Seeking diagnosis, dosage changes or clinical advice.
  Compare platform health APIs and clinical governance first.
- **Evidence limit:** Fixed wearable fixture only; no live device, diagnosis,
  dosage change or clinical validation. This tutorial was not run locally in the
  current environment; CI is configured and pending.

## Run (macOS with Apple Foundation)

Build the C core first:

```bash
cmake -S language/c -B language/c/build
cmake --build language/c/build
clang -fobjc-arc -fblocks -Ilanguage/objc/src -o build/objc-chronic \
  language/objc/Tutorial/chronic-care/chronic.m language/objc/src/*.m \
  -Ilanguage/c/include -Llanguage/c/build -lpraxo_core -framework Foundation
./build/objc-chronic --test
./build/objc-chronic
./build/objc-chronic --patient patient-200
./build/objc-chronic --simulate-failure
```

Expected test output:

```text
success: patient-100 resting_hr=88 status=draft_only dosage_changes=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: TREND_SOURCE_UNAVAILABLE reads=1
```

No live model, device data, diagnosis, dosage change or treatment effect is
implemented. Consent, clinician review and retention belong to the consumer.
