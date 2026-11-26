# Installed OCaml Package Consumer

This independent Dune project depends only on the installed `praxo-core`
library. It does not compile the implementation from a relative source path.

The bounded task is preparing a review-only support draft from an allowed public
document. A scripted model requests a tool call and then a draft. The application
owns the document tool and the authorization decision. A public request reads
once; a private request is denied before the tool callback and adds zero reads.
Checks use explicit failures, not OCaml assertions that a release profile can
disable.

After installing the standalone package:

```sh
opam exec -- dune exec --root language/ocaml/tests/package-consumer ./main.exe
```

The fixture demonstrates embedding and governance without a provider account or
network. It is not a real model-quality evaluation, independent human review,
external adoption, or a production support application. See the
[publication status](https://github.com/axisvela/praxo-core/blob/main/language/ocaml/PUBLISHING.md)
for unresolved registry review requirements.
