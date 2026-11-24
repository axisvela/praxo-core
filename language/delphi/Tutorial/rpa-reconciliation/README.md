# Delphi / Free Pascal RPA Reconciliation (OP-04)

A bounded first slice of [OP-04](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a production RPA platform. It reconciles a fixed purchase order and invoice,
flags a delta above the threshold, and drafts a review-only exception. No ERP
connector, posting or live model is used.

## Why this language and runtime?

- **Selection basis:** Existing Delphi desktop automation can add a reconciliation
  review without adopting a new RPA platform or service.
- **Demonstrated fit:** Fixed purchase-order/invoice data yields a flagged exception
  draft; no ERP connector, posting or UI automation runs.
- **Choose when:** Learning the Core seam beside existing Delphi automation.
- **Do not choose when:** Seeking end-to-end RPA or posting. Compare the ERP process,
  deterministic reconciliation rules and existing RPA tools first.
- **Evidence limit:** Core integration fixture only; no ERP access, posting, UI
  automation, credential handling or production reconciliation.

Build and run from `language/delphi`:

```bash
cd language/delphi
fpc -Mobjfpc -Scghi -O2 -Fu. -FEbuild Tutorial/rpa-reconciliation/reconcile.pas
./build/reconcile --test
./build/reconcile
./build/reconcile --batch batch-200
./build/reconcile --simulate-failure
```

On Windows use `build\reconcile.exe`. Expected test output:

```text
success: batch-100 delta=50 status=draft_only postings=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: RECORD_SOURCE_UNAVAILABLE reads=1
```

Both negative commands exit nonzero.

The deterministic host plans three steps and consumes each result: `read_records`
returns PO `1200`, invoice `1250`, `delta=50` and `threshold=25`; `draft_exception`
returns `status=draft_only`, `review_required=true` and `postings=0`. The Free
Pascal Core exposes only the action kind to the policy, so batch and final-action
checks run inside the tool seams before counters; `RequirePolicy` and
`RequireToolScope` are enabled.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-batch denial, and one read/zero drafts for the simulated source outage.
Real ERP/procurement APIs, matching rules, postings, approvals and effect
reconciliation belong to the consumer. Commercial Delphi remains unverified.
