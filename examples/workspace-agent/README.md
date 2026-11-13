# Read-Only Workspace Agent

This standalone Go module uses the published PRAXO-CORE package to build a
read-only workspace assistant. It registers `fs.list`, `fs.read`, `fs.glob`,
and `fs.grep` from `pkg/vfs/vfstools`, then denies every other tool.

## Run

```bash
mkdir -p workspace
printf 'Quarterly status: all checks green.\n' > workspace/report.txt

export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2

go run . --workspace workspace
```

Ask for a write to verify the policy boundary:

```bash
go run . --workspace workspace --prompt "Create notes.md with a summary."
```

The write is denied because `fs.write` is outside the allowlist and policy.
No file should be created.

The example uses a published module version. It does not use a module
replacement or a repository checkout.
