# Objective-C DLP Redaction (CY-06)

Inspects a fixed export for sensitive fields and drafts a review-only redaction.
No encryption, DLP completeness or sharing claim.

## Why this language and runtime?

- **Selection basis:** An existing Apple application can inspect export fields
  before sharing without adding a sidecar service.
- **Demonstrated fit:** A deterministic model inspects fixed fields and drafts a
  redaction through native Objective-C Core tools.
- **Choose when:** Evaluating a review gate beside an existing export path.
- **Do not choose when:** Claiming DLP completeness, encryption or automatic
  sharing. Compare platform data-protection APIs first.
- **Evidence limit:** Fixed export fixture and field list only; no real export,
  encryption, DLP guarantee or share action. This tutorial was not run locally in
  the current environment; CI is configured and pending.

## Run (macOS with Apple Foundation)

Build the C core first:

```bash
cmake -S language/c -B language/c/build
cmake --build language/c/build
clang -fobjc-arc -fblocks -Ilanguage/objc/src -o build/objc-redact \
  language/objc/Tutorial/dlp-redaction/redact.m language/objc/src/*.m \
  -Ilanguage/c/include -Llanguage/c/build -lpraxo_core -framework Foundation
./build/objc-redact --test
./build/objc-redact
./build/objc-redact --export export-200
./build/objc-redact --simulate-failure
```

Expected test output:

```text
success: export-100 redactable=2 status=draft_only shared=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: EXPORT_UNAVAILABLE reads=1
```

No real export, encryption, DLP scanner or share action is implemented. Retention,
field classification and effect reconciliation belong to the consumer.
