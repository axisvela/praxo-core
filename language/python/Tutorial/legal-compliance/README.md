# Python legal compliance memo

A native Python Core tutorial for a compliance memo with a human-review gate. One
tool searches fixed policy fixtures; a second tool publishes the memo only after
the application approves the interrupt. The deterministic model packages the cited
evidence. This tutorial does not read arbitrary files, call a real case system,
publish to a real document store or call a live model.

## Run

From this directory:

```bash
python -m pip install -r requirements.txt
python app.py --test
python app.py
python app.py --reject
python app.py --scope private
python app.py --simulate-failure
```

Expected test output:

```text
Python legal-compliance tutorial: all checks passed
```

`--reject` rejects the approval before `publish_memo` runs (publications=0).
`--scope private` is denied by policy before the search tool runs (reads=0).
`--simulate-failure` errors after one read.

## Path

1. `search_policy` searches three fixed policy fixtures and returns `retention` as
   the citation for `retention`.
2. `publish_memo` is listed in `interrupt_on`, so Core calls the application's
   `on_interrupt` handler before invoking it. Approval lets the simulated publish
   run; rejection raises `ApprovalDeniedError` with zero publications.
3. After approval the tool returns `status=published`, and the model packages
   `memo_id`, `status`, `citations` and `publications` into a JSON report.

The application owns the reviewer identity, approval audit trail, real document
store and effect reconciliation.

## Scope

This is source, local fixture and local HITL evidence. It does not establish real
legal advice, a real approval record, a production document store, live provider,
public hosting or independent adoption. The tools, interrupt policy and report
fields are tutorial-local and are not Core or wire API.
