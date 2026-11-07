# Workspace Session Contract Example

This example runs the provider-neutral workspace/session contract with the
in-memory fake provider. It is evaluation tooling, not a `pkg/...` API
commitment.

The `contract.Session` interface combines:

- `sandbox.Sandbox` for command execution;
- `vfs.Backend` for file operations;
- `Upload`, `Download`, `ID`, and `Close` lifecycle methods.

`Pauser` and `Snapshotter` are optional capabilities discovered by type
assertion. The fake provider implements `Pauser` and does not implement
`Snapshotter`; the example asserts both.

The shared `conformance.CheckProvider` suite verifies create, upload/download,
VFS read/write/list/glob/grep/delete, command execution, attach, optional
pause/resume, close, and attach-after-close rejection.

Run from the adapter module:

```sh
cd adapters/workspace
GOWORK=off go test ./example -v
```

The fake provider is not an isolation boundary and no live provider is used.
See the [workspace/session evaluation](../../../docs/reference/workspace-session.md)
and the [provider adapters](../README.md).
