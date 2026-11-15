# Multi-turn Checkpoint Recovery

This example saves and restores a conversation history across two agent turns.
It uses the checkpoint allowlist as a teaching in-memory store keyed by session
id; production storage and retention remain application-owned.

Run from the repository root:

```bash
mkdir -p build/delphi
fpc -Mobjfpc -Scghi -Fulanguage/delphi -FEbuild/delphi language/delphi/examples/session-checkpoint/session_checkpoint.pas
./build/delphi/session_checkpoint
```

On Windows use `build\delphi\session_checkpoint.exe`.

Expected output:

```text
restored messages: 4
output: turn 5
```

`PraxoRunAgentSession` accepts prior messages and returns the full message
history in `Result.Messages`, which the caller frees. The second turn runs
against the first checkpoint, then the updated history is saved and reloaded for
the third turn. A checkpoint is a recovery hint, not a transaction or an
exactly-once guarantee.
