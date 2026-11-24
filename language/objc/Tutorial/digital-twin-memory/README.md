# Objective-C Digital Twin Memory (OG-06)

Recalls fixed consent-scoped memories with provenance, then deletes one scope.
No real inbox, passwords or unrestricted recall.

## Why this language and runtime?

- **Selection basis:** An existing Apple application can keep scoped memory and
  deletion inside the app process.
- **Demonstrated fit:** A deterministic model recalls fixed entries and deletes
  one scope through native Objective-C Core tools.
- **Choose when:** Evaluating consent-scoped memory seams in a Foundation app.
- **Do not choose when:** Seeking general personal-data access, passwords or
  hosted memory. Compare platform privacy and storage APIs first.
- **Evidence limit:** Fixed memory fixture only; no real inbox, password,
  cross-app connector or production deletion proof. This tutorial was not run
  locally in the current environment; CI is configured and pending.

## Run (macOS with Apple Foundation)

Build the C core first:

```bash
cmake -S language/c -B language/c/build
cmake --build language/c/build
clang -fobjc-arc -fblocks -Ilanguage/objc/src -o build/objc-memory \
  language/objc/Tutorial/digital-twin-memory/memory.m language/objc/src/*.m \
  -Ilanguage/c/include -Llanguage/c/build -lpraxo_core -framework Foundation
./build/objc-memory --test
./build/objc-memory
./build/objc-memory --owner owner-200
./build/objc-memory --simulate-failure
```

Expected test output:

```text
success: owner-100 entries=2 deleted=1 remaining=1 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: MEMORY_UNAVAILABLE reads=1
```

No real inbox, passwords, connectors or durable deletion are implemented.
Consent records, retention, encryption and deletion reconciliation belong to the
consumer.
