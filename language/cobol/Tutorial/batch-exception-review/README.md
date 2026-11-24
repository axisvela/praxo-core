# COBOL Bank Batch Exception Review

This tutorial reuses the existing
[`language/cobol/examples/batch-exception-review`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/batch-exception-review)
fixture. It does not create a second bank model or a second COBOL review worker.

The batch writes normal output and a separate exception file, then finishes. A
separate COBOL review worker handles the exceptions. The tutorial wrapper checks
three outcomes and that the batch output and exception file are unchanged:

| Worker outcome | Expected result |
| --- | --- |
| Reviewed | COBOL consumer allows the public record, denies the private record, and writes advisory output only |
| Unavailable | Nonzero worker exit; no advisory output; exceptions remain for later review |
| Timeout | The driver stops waiting; no advisory output; exceptions remain |

## Why this language and runtime?

- **Selection basis:** The bank's exception review already exists as a COBOL batch
  and worker; this keeps that flow in place rather than reimplementing it.
- **Demonstrated fit:** A COBOL worker reviews the fixture exception file; a Python
  driver checks reviewed/unavailable/timeout outcomes and unchanged batch output.
- **Choose when:** Adding a governed review step beside an existing COBOL batch.
- **Do not choose when:** Building a new service or replacing the batch. Compare
  direct COBOL batch rules and the current operations process first.
- **Evidence limit:** Fixed fixture and local driver only; no core-banking
  integration, production scheduling, mainframe deployment or live model.

## Run

From the repository root, with Python 3.10+ and GnuCOBOL `cobc` on `PATH` or
`COBC` set:

```bash
python language/cobol/Tutorial/batch-exception-review/run.py
```

Expected output:

```text
reviewed: batch output unchanged; exceptions retained
unavailable: batch output unchanged; exceptions retained
timeout: batch output unchanged; exceptions retained
COBOL batch exception review tutorial: passed
```

The wrapper invokes the existing example and checks its contract; it does not
reimplement the batch, the review worker or the timeout behavior.

## Failure and Boundary Checks

- The unavailable worker exits nonzero; the tutorial fails if advisory output
  appears or the exception handoff changes.
- The slow worker exceeds the driver timeout; the tutorial fails if advisory
  output appears or the batch/exception files change.
- The reviewed path checks the COBOL worker's allow/deny output before writing
  advisory records.
- No real payment, posting, account change or clearing operation is implemented.

## Scope

This is a local deterministic handoff fixture. It is not a durable queue,
production scheduler, recovery proof, exactly-once effect ledger, throughput
benchmark or banking integration. A local process timeout does not prove that
remote work or remote effects stopped. Production deployments need
application-owned persistence, reconciliation, budgets, credentials and audit.

Local verification on 2026-11-22 used GnuCOBOL 2.0.0 and Python 3.14: the wrapper
and all three underlying scenarios passed. Linux CI is configured and pending.
No live model, real bank data, real posting, public hosting or independent
consumer evidence is claimed.
