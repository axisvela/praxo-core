# OCaml Package Publication Status

The [official opam packaging guide](https://opam.ocaml.org/doc/Packaging.html#Using-opam-publish-with-a-project-hosted-on-Github)
describes package validation and submission through `opam-publish`. Submission
opens a pull request to opam-repository; a GitHub tag or Release alone does not
make `opam install praxo-core` available.

Checked 2026-11-26: the monorepo source and the
[dedicated package repository](https://github.com/axisvela/praxo-core-ocaml)
are aligned to `0.11.0`. The split root contains `praxo-core.opam`,
`dune-project`, and `src/`. The public library is `praxo-core` and its module
is `Praxo_core`.

[PR #31222](https://github.com/ocaml/opam-repository/pull/31222) submitted
`0.8.0` and is closed without merge. Its
[opam-ci results](https://opam.ci.ocaml.org/github/ocaml/opam-repository/commit/78cc5259efabfd9fa81c0bb2e8383e43cb074049)
show passing lint and compiler builds; the remaining reported failures are
Arch Linux base-image builds. This is not evidence of a package compilation
failure. These results apply to `0.8.0`, not the current monorepo source.

Registry review is a separate unresolved gate. In previous submissions,
maintainers raised source duplication, missing interface documentation, and
utility and human OCaml review concerns. The current source addresses the
documented technical issues and has a guarded package layout, but passing
automated checks does not replace the requested human OCaml review.

Technical follow-up completed on 2026-11-26:

- Every exported value in `src/praxo_core.mli` has an odoc comment, with
  contract notes for limits, error codes, lexical path checks, and transport
  seams. `scripts/test_ocaml_api_docs.py` enforces attached docs, the API
  snapshot, and a 500-line limit for every library source file.
- The native implementation is split into responsibility modules
  (`praxo_types`, JSON/tool-call, schema/manifest, providers, plugin host,
  runtime, middleware, agent, and seams); `praxo_core.ml` re-exports them as
  the public `Praxo_core` module. `praxo_core_bundle.ml` supports source
  examples through the OCaml toplevel.
- Duplicated ASCII predicates (`is_digit_char`, repeated alpha tests) were
  replaced by one `is_alpha` and the existing `is_digit`; prefix/suffix helpers
  delegate to `String.starts_with`/`String.ends_with`; assistant and tool
  messages derive from `text_message` instead of repeating record literals.
- The installed-package consumer performs a governed allow/deny task rather
  than only parsing JSON.

These are source-level changes verified by the OCaml suite and package staging.
They do not constitute the human OCaml review requested by maintainers.

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

The dedicated repository is synced from the guarded
`--sync-split --output <split-repository>` mode. It validates repository identity
and clean Git status before adopting existing tracked files; subsequent local
refreshes use the generated ownership manifest without that adoption flag. The
split release tag and static archive are the registry submission inputs.

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
