# OCaml Package Publication Status

The [official opam packaging guide](https://opam.ocaml.org/doc/Packaging.html#Using-opam-publish-with-a-project-hosted-on-Github)
describes package validation and submission through `opam-publish`. Submission
opens a pull request to opam-repository; a GitHub tag or Release alone does not
make `opam install praxo-core` available.

Checked 2026-11-26: the monorepo source is `ocaml/v0.10.0`, while the
[dedicated package repository](https://github.com/axisvela/praxo-core-ocaml)
still declares `0.8.0` in `VERSION` and `dune-project`. Its root contains
`praxo-core.opam`, `dune-project`, and `src/`. The public library is
`praxo-core` and its module is `Praxo_core`.

[PR #31222](https://github.com/ocaml/opam-repository/pull/31222) submitted
`0.8.0` and is closed without merge. Its
[opam-ci results](https://opam.ci.ocaml.org/github/ocaml/opam-repository/commit/78cc5259efabfd9fa81c0bb2e8383e43cb074049)
show passing lint and compiler builds; the remaining reported failures are
Arch Linux base-image builds. This is not evidence of a package compilation
failure. These results apply to `0.8.0`, not the current monorepo source.

Registry review is a separate unresolved gate. In
[PR #31106](https://github.com/ocaml/opam-repository/pull/31106#issuecomment-6706195267),
maintainers raised source duplication, missing interface documentation, and
utility and human OCaml review concerns. The
[inline review of PR #31222](https://github.com/ocaml/opam-repository/pull/31222#discussion_r4568340018)
explicitly says those concerns had not been addressed. Passing package CI does
not resolve them. Before resubmission, address the technical feedback and obtain
human OCaml review; do not claim that automated checks provide that review.

A future submission needs a version-aligned source package, package validation,
and a static release archive with its checksum. The official guide recommends
static archives rather than forge-generated archives whose checksums may change.
Only an accepted registry entry establishes registry publication. Current
availability remains **not published to opam**; see [REGISTRY.md](REGISTRY.md).

## Source Package Validation

The canonical repository now provides a local staging tool:

```sh
python scripts/build_ocaml_package.py
opam lint build/ocaml-package/praxo-core.opam
opam install ./build/ocaml-package --with-test
opam exec -- dune exec --root language/ocaml/tests/package-consumer ./main.exe
```

The staged package includes the native OCaml sources, Dune metadata, both test
modules, shared conformance vectors, and the process-plugin test fixture.
`PROVENANCE.json` records actual input hashes separately from canonical tag and
HEAD references. Local worktree inputs are not automatically tagged release
content. An optional `--archive` argument creates a deterministic local source
archive and reports its SHA-256; this does not upload or publish anything.

The local dedicated repository has been aligned to `0.10.0` with the guarded
`--sync-split --output <split-repository>` mode. It validates repository identity
and clean Git status before adopting existing tracked files; subsequent local
refreshes use the generated ownership manifest without that adoption flag.
These edits are not committed or pushed, so they do not change the public split
repository observation above or establish a new release tag.

The `ocaml-package` workflow checks package installation with tests and an
external installed-library consumer on OCaml 4.14.2 and 5.5.0.
[Run 45809486298](https://github.com/axisvela/praxo-core/actions/runs/45809486298)
passed both compilers at `a39ca216669d27e71a850b0370d3365cb2e8ee98`, including
installation of the staging directory and the installed-library consumer.
That run did not install a freshly extracted archive. The subsequent workflow
now installs the archive after extraction; its result must be recorded separately.
Package-local metadata corrections also require a new run rather than inheriting
the earlier result. Local Windows validation passed opam lint,
Dune bytecode compilation, and the complete Dune test suite. Full native Dune
package build is blocked by the installed compiler's stale assembler path;
`opam install` and the installed-library consumer are not locally verified.
