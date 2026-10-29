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

## Execution Guard

The example validates its controls before calling the model: policy, event sink,
registered tools, and a nonempty explicit filesystem scope are required. Each
write/edit/delete capability also requires a structured approval handler and an
enabled approval gate. Automatic tool retries are rejected by this example.
These requirements do not change the ordinary `agent.New` defaults.

For each run, an in-memory approval count binds the tool name to the exact JSON
arguments approved, including explicit approval edits. At invocation, the tool
wrapper checks policy again and consumes one matching approval. Changes after
approval, dependency failures, and queued-policy denial prevent the affected
write. A guard failure stops later queued tools and fails the run even if an
AfterTool middleware clears the tool error. Already started concurrent work is
not rolled back or forcibly terminated.

Run `go test ./examples/governed-workspace` for the deterministic failure and
positive-path fixtures. The wrapper preserves model-visible tool schemas and
only exposes the tools in the configured scope.

## Context Trust

`runWithWorkspaceContext` is a second, explicitly selected admission path for
already-fetched memory and skills. It does not enable Core's automatic recall or
skill providers. Only the deployment system prompt and skills whose full JSON
matches caller-supplied approved digests become instructions. Memory,
unapproved skills, tool results, historical text, and derived summaries are
wrapped as JSON data with source IDs, an untrusted label, and conservative
summary lineage.

The same boundary runs for primary and fallback model calls. It rejects extra
System messages, other roles, changed instructions, unmanaged inputs, duplicate
sources, forged trust labels, and unsupported structured restore. Summaries are
converted back to data and must fit the configured budget; the example fails
rather than dropping instructions or source metadata. Restore is limited to
text history and rebuilds instructions from current configuration.

These are example-level checks, not a Core wire contract or general prompt
injection filter. A model can still follow untrusted text; tool scope, policy,
and approval must remain independently enforced. Source authentication, durable
lineage, real-model adversarial testing, and full tool/effect recovery are out of
scope.

## Boundaries

- This is not a real model integration. The scripted model only exercises the
  framework's policy, allowlist, approval, tool, and event boundaries.
- The `write` mode's approval handler always approves. Real products must bind
  approval to an authenticated human; this demo only implements local argument
  binding, not durable, signed, expiring, or cross-process approval evidence.
- The policy checker is a demo path check; `localfs` also enforces the workspace
  root. High-risk products should add OS-level confinement.
- The demo does not claim production, multi-tenant, or network isolation.
- A policy recheck and business commit are not atomic. Revocation after the
  check, external effect deduplication, and recovery remain integration concerns.
