# COBOL AI Batch Exception Analyst (AI-native reference application)

A native GnuCOBOL batch reviewer where the agent drives the primary exception
workflow: the driver reads a bounded exception file, the agent inspects each
allowed record, writes a diagnosis and rationale, and drafts a review-only
advisory. The batch never posts an adjustment and private records are denied
before the read.

This is the AI-native COBOL reference application. The existing
[`batch-exception-review`](../Tutorial/batch-exception-review/) tutorial remains
the deterministic batch/worker boundary example.

## Why this language and runtime?

- **Selection basis:** COBOL batch and reconciliation jobs already produce
  bounded exception files; the review step should stay next to that logic.
- **Demonstrated fit:** A native `praxo-run` loop, COBOL tools, a lexical policy
  callback, and an event trace exercise the Core seam without a second Core.
- **Choose when:** Adding a governed review step beside an existing COBOL batch
  that can export a bounded exception file.
- **Do not choose when:** Putting a synchronous model call in a per-record batch
  loop or an online transaction. Export exceptions and review them separately.
- **Evidence limit:** Fixture exception data and a deterministic scripted model.
  No live-model run is recorded because this application does not bundle an HTTP
  transport for the COBOL provider adapters.

## AI-native workflow

1. The batch writes `exceptions.tsv` (`record_id,class,difference`).
2. `cobol-batch-analyst` reads each row and invokes the agent.
3. The model chooses `read_exception`, diagnoses the difference, then chooses
   `draft_advisory` with a diagnosis and rationale.
4. COBOL policy allows only public records, only review-only advisories, and only
   tenant `bank-ops`; `post_adjustment` is always denied.
5. The application writes allowed advisories to `advisory.tsv`. Exceptions stay
   in place and no posting or account change occurs.

If the model is removed, the primary review workflow disappears.

## Where is the LLM reasoning?

The deterministic tests use a scripted COBOL model. They verify the harness,
policy, file handoff, trace shape, and failure paths, not LLM reasoning. The
scripted model writes the diagnosis/rationale and chooses the tools, but its
text is fixed.

The COBOL Core has no bundled HTTP/TLS client. A live path would use a
caller-owned transport with a provider adapter and must preserve tool-result
history; this revision records no live-model evidence. Do not treat a
deterministic run as reasoning evidence.

## Host integration

| Boundary | Where |
| --- | --- |
| Batch entry and file handoff | `application.cob` |
| Agent loop | `src/agent.cob` (`praxo-run`) |
| Model | `analyst-model` |
| Tools | `analyst-tool` |
| Policy | `analyst-policy` |
| Trace | `analyst-event` |
| Tests | `run-tests.py` and `--test` |

Identity, transport, approval, posting, and effect reconciliation remain
application-owned.

## Tools and policy

| Tool | Effect | Policy |
| --- | --- | --- |
| `read_exception` | Returns the current fixture record | Public record only |
| `draft_advisory` | Saves a review-only advisory | Public record, `review_only`, diagnosis and rationale required |
| `post_adjustment` | Would post an adjustment | Always denied |

The tenant must be `bank-ops`. A `direct` scenario is denied at
`post_adjustment`; a `weak` scenario with no diagnosis/rationale is denied at
`draft_advisory`. The application reports `executions=0` in every allowed path.

## Build and test

GnuCOBOL 2.0+ and Python 3.10+:

```bash
python language/cobol/application/run-tests.py
```

Expected:

```text
public: reviewed advisory=1 executions=0
private: denied before read
direct: denied with zero effects
tenant: denied before model
weak: denied without rationale
COBOL batch analyst self-test: passed
COBOL batch exception analyst: passed
```

The first pass line is the internal self-test; the final line is the batch-file check.
Generated objects and the executable stay under `language/cobol/build/`, which is
ignored; no executable is committed.

## Run

From a working directory containing `exceptions.tsv`:

```bash
cobc -c -free -I language/cobol/copy \
  -o build/batch-analyst-agent.o language/cobol/src/agent.cob
cobc -x -free -I language/cobol/copy -I language/cobol/application \
  -o build/cobol-batch-analyst \
  language/cobol/application/application.cob build/batch-analyst-agent.o
./build/cobol-batch-analyst
```

Set `PRAXO_TENANT` to override the default `bank-ops`. Output:

```text
reviewed: 002 advisory=1 reads=1 drafts=1 executions=0
denied: 003 error=POLICY_ERROR executions=0
reviewed=1 denied=1
```

The `advisory.tsv` file contains only allowed public rows.

## Boundaries

- Fixture exception file and deterministic model; no live model.
- No real ledger, posting, settlement, clearing, or account change.
- No durable queue, scheduler, recovery, exactly-once effect, or production
  identity.
- No production throughput or batch-window claim.
- Local source build; not a registry-package install.
