# COBOL Batch Exception Review

Keep the main batch deterministic and hand exceptions to a separate review
step. This fixture uses Python to stand in for the batch and scheduler, and
reuses the native COBOL [allow/deny consumer](../consumer/) as the review worker.
It does not need a model service, credentials, or an HTTP transport.

From the repository root, with Python 3.10+ and GnuCOBOL on `PATH` (or `COBC`
set to the compiler):

```sh
python language/cobol/examples/batch-exception-review/run.py
```

The batch writes normal output and a separate exception file, then returns
before the driver starts review. The driver runs three independent scenarios:

| Worker | Expected result |
| --- | --- |
| COBOL deterministic consumer | The public review records one in-memory effect; the private review is denied with zero effects. The driver writes a separate advisory report. |
| Unavailable worker (simulated nonzero exit) | No advisory report; the exception file remains available for later review. |
| Slow worker (simulated timeout) | The driver times out the separate process. No advisory report; the exception file remains available. |

All three runs check that the batch output and exception file remain unchanged
after review. The fixture uses fixed records that match the existing consumer's
public/private cases, not a general record-processing interface. The driver
waits for the worker only to verify the result. In deployment, if the main job
must wait for review before finishing, review is still on the critical path.

This is a local handoff fixture, not a durable queue, recovery proof, or
throughput benchmark. Production code needs application-owned persistence,
reconciliation, transport timeouts, and review budgets. A local process timeout
does not establish that remote work or remote effects stopped.
