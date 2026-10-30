# Containment Assessment

This page summarizes the containment properties that PRAXO-CORE tests in public.
It is not a penetration test, compliance certification, or a claim that deployed
products inherit these properties. See the [security model](index.md) for
the threat model and trust boundaries.

## Tested Boundaries

| Boundary | Public control |
| --- | --- |
| Filesystem path grants | Deny by default; empty grants deny; read, write, and readwrite are checked separately |
| Traversal and sibling prefixes | Traversal and sibling-prefix escapes are rejected |
| Symlinks | Grant roots and targets are resolved before comparison |
| Malformed paths | NUL bytes and Windows drive-relative paths fail closed |
| Windows special names | Local VFS rejects reserved device names, alternate data streams, and trailing dots or spaces |
| VFS | The local backend rejects absolute paths and routes through `policy.PathChecker` |
| Plugin lifecycle | Only active plugins admit calls; terminal states are irreversible |
| Process host | Platform supervisors apply process-tree and resource limits |
| WASM host | Linear-memory bounds and timeout/cancellation termination are tested |
| HTTP | TLS verification is on by default and response bodies are bounded |
| Tool authorization | Final tool names and arguments are reauthorized before execution |

## Open Areas

Containment is layered and product-owned. Callers must still provide OS-level
isolation, trusted base URLs, signature and SBOM verification, approval binding,
and idempotency where their threat model requires it.

In the unreleased Go source, the local VFS authorizes virtual paths with
`policy.PathChecker`, then performs reads, writes, stats, listings, deletes,
globs, and recursive Grep file reads through an `os.Root` rooted handle. A
symlink swapped after the policy check cannot redirect the actual file operation
outside the workspace root. `os.Root` rejects absolute symlinks, so workspace
symlinks should use relative targets. `Grep` still validates each file before
reading it; a denied path aborts with no partial matches. Policy decisions
outside localfs remain check-then-use, and high-risk callers should still add
OS-level confinement.

Symlink regressions require a host permitted to create symlinks; skipped tests
are not containment verification. Linux CI runs the symlink cases; Windows
hosts without symlink privilege report them as skipped.

The independent containment review request is tracked in
[issue #8](https://github.com/axisvela/praxo-core/issues/8).
