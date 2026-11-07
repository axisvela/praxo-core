# VFS and Path Containment Recipe (Go)

This recipe demonstrates Core-owned local path controls: a rooted VFS backend
and a deny-by-default path checker. It uses no containers, VMs, or external
services.

**Evidence level: L1 contract recipe.** It shows path, traversal, NUL-byte,
root-delete, and symlink handling on the host filesystem. It is not real
sandbox/container/VM isolation and does not prove deployment-level containment.
See [EC-11](../../../docs/project/execution-correctness.md),
[containment](../../../docs/security/containment.md), and the
[test and evidence taxonomy](../../../docs/project/test-taxonomy.md).

Run from this directory:

```sh
GOWORK=off go test -mod=readonly -v ./...
```

The tests show:

- a rooted `localfs` backend round-trips a file;
- traversal and NUL-byte paths are rejected;
- deleting the root is refused;
- a symlink that points outside the root is rejected when the host can create
  symlinks;
- `policy.PathChecker` allows read inside a read-only grant, denies write, and
  denies traversal and sibling-prefix paths;
- an empty grant set denies every path.

Host-level checks remain check-then-use at the policy layer; `localfs` uses
`os.Root` for its actual operations. Deployment OS/network isolation and
independent review remain external responsibilities.

From the repository root, `python scripts/test_go_vfs_containment_recipe.py -v`
repeats the checks in a fresh temporary module using the published package.
