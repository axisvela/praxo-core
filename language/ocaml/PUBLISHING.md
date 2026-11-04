# Publishing the OCaml Core

Source tag `ocaml/v0.2.0`. The package is not in opam.

Add an opam package and a build description. The Core is currently built with
`ocamlc` directly, so provide either a `dune-project`/`dune` build or an opam
`build` field that compiles `praxo.mli` and `praxo.ml`. A split mirror or an
opam package pointing at `language/ocaml` avoids publishing the monorepo root.

Run `python language/ocaml/run-tests.py --compiler ocamlc` and the API snapshot,
then submit an `opam-publish` pull request to
<https://github.com/ocaml/opam-repository>. No separate account is required.
`ocamlopt` support remains unverified.
