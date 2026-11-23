# Objective-C Privacy Agent (PE-03)

A bounded first slice of [PE-03](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a password manager or data-deletion service. It classifies a fixed message
fixture for sensitive exposure and drafts a review-only deletion request. This
uses the source Objective-C Core; no network, credentials or additional
frameworks beyond Foundation are required.

macOS with Apple Foundation:

```bash
mkdir -p build
cmake -S language/c -B language/c/build
cmake --build language/c/build
clang -fobjc-arc -fblocks -Ilanguage/objc/src -o build/objc-privacy \
  language/objc/Tutorial/privacy-agent/privacy.m \
  language/objc/src/PraxoJSON.m language/objc/src/PraxoJsonSchema.m \
  language/objc/src/PraxoPlugin.m language/objc/src/PraxoWire.m \
  language/objc/src/PraxoCore.m language/objc/src/PraxoAgent.m \
  language/objc/src/PraxoHitl.m language/objc/src/PraxoOpenAI.m \
  language/objc/src/PraxoAnthropic.m language/objc/src/PraxoGemini.m \
  language/objc/src/PraxoHarmovela.m language/objc/src/PraxoMCP.m \
  language/objc/src/PraxoOtel.m language/objc/src/PraxoRetriever.m \
  language/objc/src/PraxoDelegation.m language/objc/src/PraxoPluginProcess.m \
  -Ilanguage/c/include -Llanguage/c/build -lpraxo_core -framework Foundation
./build/objc-privacy --test
./build/objc-privacy
./build/objc-privacy --subject subject-200
./build/objc-privacy --simulate-failure
```

Expected test output:

```text
success: subject-100 exposures=2 status=draft_only actions=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: MESSAGE_SOURCE_UNAVAILABLE reads=1
```

Both negative commands exit nonzero.

The deterministic model plans three steps and consumes each result:
`classify_messages` returns two messages and two exposures (email ×2, phone ×1);
`draft_privacy_request` returns `status=draft_only`, `review_required=true` and
`actions=0`. The policy block receives tool name and arguments, limiting the
subject and final `request_deletion` action; `requirePolicy` and
`requireToolScope` are enabled.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-subject denial, and one read/zero drafts for the simulated source outage.
No password handling, account access, message deletion, connector or live model is
implemented. Identity, consent, retention policy, deletion execution and effect
reconciliation belong to the consumer.
