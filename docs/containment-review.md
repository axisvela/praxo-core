# Containment Review

**Status:** internal review, not independent sign-off. Reviewed commit
`c4960d0` on 2026-10-24.

This review maps the framework's containment boundaries to tests and documents
residual risk. It is not a penetration test, compliance certification, or a
claim that deployed products inherit these properties.

## Scope

- `pkg/policy` path grants and `PathChecker`
- `pkg/vfs/localfs` and `pkg/vfs/vfstools`
- `pkg/plugin` lifecycle and `pkg/plugin/host/process`
- `pkg/plugin/host/wasm`
- `pkg/httpclient`
- Claimed sandbox and workspace boundaries in examples

## Confirmed Controls

| Boundary | Control | Evidence |
| --- | --- | --- |
| Filesystem path grants | Deny by default; empty grants deny; read/write/readwrite checked separately | `pkg/policy/path_test.go` |
| Traversal and sibling prefixes | Traversal and `root-evil`-style sibling prefixes are rejected | `TestPathCheckerDeniesTraversal`, `TestPathCheckerDeniesSiblingPrefix` |
| Symlinks | Grant roots and targets are resolved; a symlink cannot move a path outside the root | `TestPathCheckerSymlinkEscape`, `TestPathCheckerRootSymlink` |
| Windows path case | Comparison is case-insensitive on Windows | `TestPathCheckerWindowsCaseInsensitive` |
| VFS | `localfs` rejects absolute paths and resolves through `PathChecker`; VFS tools expose no shell unless the backend implements `Executor` | `pkg/vfs/localfs`, `pkg/vfs/vfstools` |
| Plugin lifecycle | Only `ACTIVE` admits calls; transitions are a guarded table; terminal states are irreversible | `pkg/plugin/lifecycle.go`, `pkg/plugin/lifecycle_failure_test.go` |
| Process host, Windows | Child runs in a Job Object with kill-on-close; required limits fail startup when unavailable | `pkg/plugin/host/process/limits_windows.go` |
| Process host, Linux | Separate process group plus rlimits; required limits fail startup when unavailable | `pkg/plugin/host/process/limits_linux.go` |
| WASM | Linear-memory page bound and context cancellation | `pkg/plugin/host/wasm` |
| HTTP | Default TLS verification; response body bounded; configured timeout | `pkg/httpclient`, `pkg/httpclient/client_failure_test.go` |
| Reauthorization | Final tool name and changed JSON arguments are reauthorized before execution since 2.3.3 | `pkg/agent/tool_authorization_test.go` |

## Residual Risks

1. **PathChecker is check-then-use.** A symlink or path component can change
   between `Check` and the file operation. High-risk callers need OS-level
   confinement or open-by-handle APIs.
2. **Linux process containment is weaker than Windows.** A descendant that
   creates a new session can leave the process group. `RLIMIT_NPROC` is counted
   per real UID across the system and is not enforced for uid 0. Hard per-tree
   containment needs delegated cgroup v2 controllers.
3. **No WASM CPU fuel.** CPU-bound guests rely on context cancellation and
   forced termination, not deterministic fuel accounting.
4. **HTTP redirects use Go's default policy.** Callers must choose trusted base
   URLs; redirect handling and SSRF allowlisting remain caller-owned.
5. **No signature/SBOM verification in core.** Products must verify descriptors,
   signatures, SBOMs, and trust roots before starting a host.
6. **Sandbox seam is an interface.** A policy-gated host command is not OS-level
   isolation.
7. **Approval is a handler.** Products must bind approval to an authenticated
   human and the exact final arguments; the framework does not provide an
   approval service.
8. **Checkpoint is not exactly-once.** `EffectCursor` is a recovery hint; the
   application owns an idempotency ledger and lease/fencing semantics.

## Review Gaps

- No independent reviewer has reproduced this assessment.
- No Windows/Linux adversarial containment harness beyond the existing unit tests.
- No cgroup-based Linux containment test.
- No WASM fuel or CPU-exhaustion test.
- No deployed/networked red-team exercise.

These gaps remain open. The independent review request is tracked in
[issue #8](https://github.com/axisvela/praxo-core/issues/8).

## Verification Run

```text
go test ./pkg/policy ./pkg/vfs/... ./pkg/plugin/... ./pkg/httpclient ./pkg/agent
go vet ./...
```

Linux race and the three-platform matrix remain CI gates. This review does not
substitute for those gates.
