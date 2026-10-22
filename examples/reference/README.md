# Reference Workspace Agent

A small runnable example that combines the OpenAI-compatible adapter with:

- a confined local VFS and `fs.*` tools
- policy authorization
- event delivery
- memory recall
- a context budget

The agent can list, read, write, edit, delete, glob, and grep files inside the
workspace. Path traversal and symlink escapes are rejected by `localfs`.

## Run with Ollama

```bash
ollama pull llama3.2
GOWORK=off go run ./examples/reference -workspace ./workspace
```

## Run with a hosted endpoint

```bash
export PRAXO_BASE_URL=https://api.openai.com/v1
export PRAXO_API_KEY=...
export PRAXO_MODEL=gpt-4o-mini
GOWORK=off go run ./examples/reference \
  -workspace ./workspace \
  -prompt "Create notes.md with a short status report."
```

## Flags

| Flag | Default | Description |
| --- | --- | --- |
| `-workspace` | `workspace` | Directory exposed to the agent |
| `-prompt` | inspect and summarize | Request sent to the agent |
| `-base-url` | `PRAXO_BASE_URL` or Ollama | OpenAI-compatible endpoint |
| `-model` | `PRAXO_MODEL` or `llama3.2` | Model name |

`PRAXO_API_KEY` is read from the environment.

## Safety

- File access is confined to `-workspace` by `pkg/vfs/localfs`.
- The policy hook allows the example's workspace actions; replace it with your
  own authorization system in production.
- There is no shell or network tool in this example.
- Credentials are read from the environment and are not logged.
