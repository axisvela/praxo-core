# Go full-stack workspace

A scoped full-stack-planning tutorial over the Go reference Core. It reads a fixed
allowlisted workspace, applies one bounded edit to `app.go` and inspects synthetic
diagnostics. The workspace is an in-process fixture, not the host filesystem.
This tutorial does not compile real code, deploy, call a live model or touch a
production workspace.

## Why this language and runtime?

- **Selection basis:** Go is the reference Core, so this tutorial also exercises
  the canonical runtime and package shape. It is not evidence for a specific
  developer-tool product backend.
- **Demonstrated fit:** Go tools and policy checks read an in-process workspace,
  acknowledge one edit and return synthetic diagnostics. No filesystem, compiler
  or process sandbox is used.
- **Choose when:** Learning the reference end-to-end tool/policy loop in Go.
- **Do not choose when:** Expecting a coding sandbox or real build integration.
  Compare direct Go tooling or an existing workspace service first.
- **Evidence limit:** Core integration fixture only; no real edit, compilation,
  deployment or workspace isolation is demonstrated.

Run from the repository root:

```bash
go run ./language/go/Tutorial/fullstack-workspace --test
go run ./language/go/Tutorial/fullstack-workspace --workspace workspace-200
go run ./language/go/Tutorial/fullstack-workspace --simulate-failure
```

Expected test output:

```text
success: workspace-100 files=2 edited=1 diagnostics=0 status=applied_fixture deployments=0 reads=1
deny: policy denied reads=0
failure: WORKSPACE_UNAVAILABLE reads=1
```

`workspace-200` is denied by policy before the source is called and exits `1`.
`--simulate-failure` reads once, reports `WORKSPACE_UNAVAILABLE`, and exits `1`.
The package also has a Go test
(`go test ./language/go/Tutorial/fullstack-workspace`).

`read_workspace` returns 2 files with only `app.go` allowlisted;
`apply_edit` reports one bounded change with `status=applied_fixture`;
`inspect_diagnostics` reports 0 diagnostics and `build_status=ok_fixture`. Policy
limits the workspace, the allowlisted file and each final action.

The diagnostics are fixtures, not a compiler result. Real code generation,
compilation, testing and deployment remain application-owned.
