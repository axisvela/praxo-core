# TypeScript workspace plan (SE-01)

A bounded first slice of [SE-01](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a code-generation or deployment product. It reads a fixed allowlisted
workspace, applies one bounded edit to `app.js` and inspects synthetic
diagnostics. In-process fixtures only; no host filesystem, compiler or deployment.

From this directory:

```bash
npm ci
npm test
node app.js
node app.js --workspace workspace-200
node app.js --simulate-failure
```

Expected test output: `TypeScript workspace-plan tutorial: all checks passed`.
Both negative commands exit nonzero.

`read_workspace` returns 2 files with only `app.js` allowlisted; `apply_edit`
reports one bounded change with `status=applied_fixture`; `inspect_diagnostics`
returns 0 diagnostics and `build_status=ok_fixture`. Policy limits the workspace,
allowlisted file and each final action.

Tests assert one read, one edit and one diagnostic on success, zero calls for a
cross-workspace denial, and one read/zero edits for the simulated workspace
outage. Real code generation, compilation, testing and deployment remain
application-owned.
