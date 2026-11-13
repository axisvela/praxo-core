# Build a Read-Only Workspace Agent

This tutorial moves from the
[Live Model Golden Path](../getting-started/live-model-golden-path.md) to a
useful local application. You will run an agent that can inspect a directory but
cannot modify it.

The runnable project is
[`examples/workspace-agent`](https://github.com/axisvela/praxo-core/tree/main/examples/workspace-agent).
It uses the published `github.com/axisvela/praxo-core/v2` module without a
repository replacement.

## What You Need

- Go 1.26.11 or newer.
- Ollama running locally, or another OpenAI-compatible endpoint.
- A small model, for example `llama3.2`.

## Run the Example

From the repository root:

```bash
mkdir -p workspace
printf 'Quarterly status: all checks green.\n' > workspace/report.txt

export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2

cd examples/workspace-agent
go run . --workspace workspace
```

The default prompt asks the agent to list the workspace, read text files, and
summarize them.

## What the Example Wires Together

- `localfs.New` roots file access at the workspace directory.
- `vfstools.Tools` registers `fs.list`, `fs.read`, `fs.glob`, and `fs.grep`.
- `agent.Options.AllowedTools` limits the exposed tools.
- The policy hook allows only model generation and those four read tools.
- A policy path check rejects absolute paths and `..` escapes.
- `event.FuncSink` prints lifecycle events to stderr.

The allowlist and policy are both application-owned. Core enforces the
decisions; it does not infer your production authorization policy.

## Verify the Boundary

Ask the agent to create a file:

```bash
go run . --workspace workspace --prompt "Create notes.md with a summary."
```

`fs.write` is not in the allowlist and policy denies it. No `notes.md` should be
created.

This is the same separation used by the
[governed workspace example](https://github.com/axisvela/praxo-core/tree/main/examples/governed-workspace):
read operations are available, while writes require an explicit application
decision and, in that example, human approval.

## Moving Toward a Real Application

- Replace the local workspace with your application's storage or sandbox seam.
- Supply an authenticated principal and tenant-aware policy.
- Add checkpoints for long-running or side-effecting work.
- Forward events to your observability pipeline.
- Add MCP tools only when their scope and trust boundary are explicit.
- Keep credentials, durable approvals, and effect reconciliation outside Core.

## Related

- [Examples](../getting-started/examples.md)
- [Live Model Golden Path](../getting-started/live-model-golden-path.md)
- [Identity and policy recipe](identity-policy.md)
- [Recipes](recipes.md)
- [Containment](../security/containment.md)
