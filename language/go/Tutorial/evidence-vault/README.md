# Go evidence-vault review

A scoped security-operations tutorial over the Go reference Core. It reads one
allowlisted evidence file from a local `vfs/localfs` backend confined to a vault
root, then drafts a review-only finding. The backend rejects path traversal and
absolute paths, so the model cannot read a sibling `secret.txt` outside the vault.
This tutorial does not read arbitrary files, write to a case system, call a live
model or perform containment.

## Why this language and runtime?

- **Selection basis:** Go is the reference Core, and confinement belongs beside a
  service that already owns file access and case boundaries.
- **Demonstrated fit:** Core `vfs/localfs` restricts reads to a temporary root and the
  test exercises a path-traversal denial with no draft after it.
- **Choose when:** Evaluating confined read patterns inside an existing Go service.
- **Do not choose when:** Seeking encryption, case management or a production sandbox.
  Compare the platform's file and secret controls first.
- **Evidence limit:** Temporary local root and in-process checks; no encrypted store,
  multi-tenant isolation, retention policy or legal-evidence claim.

Run from the repository root:

```bash
go run ./language/go/Tutorial/evidence-vault --test
go run ./language/go/Tutorial/evidence-vault
go run ./language/go/Tutorial/evidence-vault --path ../secret.txt
go run ./language/go/Tutorial/evidence-vault --simulate-failure
```

Expected test output:

```text
success: evidence-100 severity=critical action=open_review status=draft_only writes=0 reads=1
containment: traversal and absolute paths rejected
deny: policy denied reads=0
failure: EVIDENCE_UNAVAILABLE reads=1
```

`--path ../secret.txt` is denied by policy before the tool runs (reads=0) and the
constrained backend also rejects the traversal when called directly.
`--simulate-failure` errors after one read. The package also has a Go test
(`go test ./language/go/Tutorial/evidence-vault`).

## Path

1. The tutorial creates a temporary vault with an allowlisted `evidence-100.txt`
   and a sibling `secret.txt` outside the root, then opens a `localfs` backend.
2. `read_evidence` reads the virtual path through the backend, which resolves it
   inside the vault root and rejects `..` or absolute paths at the OS root
   boundary. The tool computes `lines` and `severity=critical`.
3. `draft_finding` returns `status=draft_only`, `review_required=true` and
   `case_writes=0` for `open_review`.
4. The deterministic model packages both tool results into a JSON report.

## Scope

This is source, local temporary-vault and local containment evidence. It does not
establish a real evidence store, case system, retention policy, live provider,
public hosting or independent adoption. The vault is a temporary directory, not a
production encrypted store or sandbox. Tool names and report fields are
tutorial-local and are not Core or wire API.
