# Sandbox and Policy Example

A high-risk tool pattern: authorize before execution, allow only an exact
command, and run without a shell.

```bash
go run ./examples/sandbox
```

Expected output:

```text
exit=0 stdout="go version ..."
denied: command is not allowlisted
```

The policy hook allows only `go version`; `rm -rf /` is denied before it reaches
the sandbox. The sandbox sets a timeout and invokes `exec.CommandContext` without
a shell.

## Warning

This example executes an allowed command on the host. It demonstrates the
policy and sandbox contracts, not real isolation. Production high-risk tools
should use a container, VM, or dedicated sandbox runtime behind
`sandbox.Sandbox`.

## Test

```bash
go test ./examples/sandbox
```
