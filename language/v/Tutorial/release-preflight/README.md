# V Release Preflight (SE-01)

A local release-planning tutorial in native V. It reads `app.json` from a bounded
temporary directory, validates required fields, semantic-version shape and the
entry allowlist, then lets the Agent choose a review branch from the actual check
result. It never deploys, installs tools or executes model-provided commands.

## Why this language and runtime?

- **Selection basis:** V targets small compiled CLI tools; this keeps a native
  preflight beside an existing V build or release helper.
- **Demonstrated fit:** The tutorial creates a temporary workspace, reads and parses
  JSON, validates actual fields and files, and changes the review action when the
  configuration changes.
- **Choose when:** An existing V-native tool needs a governed release-check boundary.
- **Do not choose when:** A mature CI/release platform already performs these checks.
  V is not presented as a broadly adopted industry platform.
- **Evidence limit:** Local temporary directory and fixed schema only; no deployment,
  installation, arbitrary command execution, signing, registry upload or live model.

## Run

From the repository root:

```bash
v -path "language/v|@vlib|@vmodules" run language/v/Tutorial/release-preflight/preflight.v --test
v -path "language/v|@vlib|@vmodules" run language/v/Tutorial/release-preflight/preflight.v
v -path "language/v|@vlib|@vmodules" run language/v/Tutorial/release-preflight/preflight.v --invalid
v -path "language/v|@vlib|@vmodules" run language/v/Tutorial/release-preflight/preflight.v --deny
v -path "language/v|@vlib|@vmodules" run language/v/Tutorial/release-preflight/preflight.v --simulate-failure
```

Expected test output:

```text
V release-preflight tutorial: configuration, branches, denial and failure passed
```

The valid fixture returns `review_release`; `--invalid` reports missing name,
invalid version and an entry outside the allowlist, then returns
`review_corrections`. `--deny` is rejected before the checker runs.
`--simulate-failure` and malformed JSON return `CONFIG_UNAVAILABLE_OR_INVALID`
with no draft. Tests also cover a missing entry file and version edge cases.
