# Publishing the OCaml Core

Source tag `ocaml/v0.2.0` maps to opam package `praxo-core` version `0.2.0`
from the split repository <https://github.com/axisvela/praxo-core-ocaml>.
The repository root has `dune-project`, `praxo-core.opam`, and `src/`; the
public library is `praxo-core` and the module remains `Praxo`.
opam-repository PR #31106 is open; the package CI jobs passed.

The release tarball is a GitHub release asset named
`praxo-core-ocaml-0.2.0.tar.gz`; its sha256 is in the opam file. To release a
new version, update the main Core and the split repository, run
`python language/ocaml/run-tests.py --compiler ocamlc` and the API snapshot,
tag both repositories, upload a fresh source tarball, update the checksum, and
open an opam-repository pull request. No separate account is required beyond
GitHub. `ocamlopt` support remains unverified.
