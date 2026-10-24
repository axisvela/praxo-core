# Governed Workspace Demo

A deterministic, no-API-key demo of the governance path: read-only by default,
writes require explicit human approval, denial prevents execution, and a path
escape is rejected by policy before a tool runs. Every run prints an event
trace.

This is a fixture demo. The scripted model does not prove real model behavior,
and the approval handler is a local demo decision, not an enterprise approval
system.

## Run

```bash
GOWORK=off go run ./examples/governed-workspace -mode read
GOWORK=off go run ./examples/governed-workspace -mode write
GOWORK=off go run ./examples/governed-workspace -mode deny
GOWORK=off go run ./examples/governed-workspace -mode escape
```

Use `-workspace ./demo-workspace` to keep the seeded workspace for inspection;
without it, the demo uses a temporary directory.

## Expected Results

| Mode | Result |
| --- | --- |
| `read` | Reads `report.txt`; no write; trace has `tool.call:fs.read` and `run.completed`. |
| `write` | HITL approves `fs.write`; `notes.md` is created; trace has `tool.interrupt` then `tool.call`. |
| `deny` | HITL rejects `fs.write`; the file is absent; trace has `tool.interrupt` and `run.failed`. |
| `escape` | Policy rejects `../secret.txt`; no tool call occurs; trace has `run.failed`. |

## Boundaries

- This is not a real model integration. The scripted model only exercises the
  framework's policy, allowlist, approval, tool, and event boundaries.
- The `write` mode's approval handler always approves. Real products must bind
  approval to an authenticated human and the exact final arguments.
- The policy checker is a demo path check; `localfs` also enforces the workspace
  root. High-risk products should add OS-level confinement.
- The demo does not claim production, multi-tenant, or network isolation.
