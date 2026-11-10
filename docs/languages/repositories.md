# Language Repositories

PRAXO-CORE is a multi-language framework. Go is the reference implementation;
other implementations have independent packages and dedicated repositories so
that language-specific discovery does not depend on finding a subdirectory in a
Go-oriented monorepo.

The canonical source, specification, and release workflows remain in
[`axisvela/praxo-core`](https://github.com/axisvela/praxo-core). A dedicated
repository is either a publication source or a discovery mirror; the registry
version remains the authority for what consumers install.

## Active Repositories

| Language | Repository | Role |
| --- | --- | --- |
| Python | [axisvela/praxo-core-python](https://github.com/axisvela/praxo-core-python) | Discovery mirror of `language/python`; includes `spec/` for conformance |
| TypeScript | [axisvela/praxo-core-typescript](https://github.com/axisvela/praxo-core-typescript) | Discovery mirror of `language/typescript`; includes `spec/` for conformance |
| Ruby | [axisvela/praxo-core-ruby](https://github.com/axisvela/praxo-core-ruby) | RubyGems publication source |
| PHP | [axisvela/praxo-core-php](https://github.com/axisvela/praxo-core-php) | Packagist publication source |
| Lua | [axisvela/praxo-core-lua](https://github.com/axisvela/praxo-core-lua) | Dedicated Lua repository |
| Swift | [axisvela/praxo-core-swift](https://github.com/axisvela/praxo-core-swift) | Swift Package Index source |
| Julia | [axisvela/praxo-core-julia](https://github.com/axisvela/praxo-core-julia) | Julia General Registry mirror |
| V | [axisvela/praxo-core-v](https://github.com/axisvela/praxo-core-v) | Split V repository |
| OCaml | [axisvela/praxo-core-ocaml](https://github.com/axisvela/praxo-core-ocaml) | Split OCaml repository |
| Nim | [axisvela/praxo-core-nim](https://github.com/axisvela/praxo-core-nim) | Split Nim repository |
| D | [axisvela/praxo-core-d](https://github.com/axisvela/praxo-core-d) | DUB publication source |

## Rollout

Dedicated repositories are added in adoption order, not to maximize language
counts. The current batch covers Python and TypeScript. The next batch covers
Java, Rust, C#, R, and Elixir. Extended and optional implementations follow when
a maintainer or named consumer needs a dedicated repository.

A mirror keeps the canonical `language/<language>` tree and the shared `spec/`
vectors so its tests and conformance runner work. It does not replace the
monorepo release workflow. Do not infer registry availability, conformance, or
production readiness from the existence of a repository.

## Adding a Language Repository

1. Keep the canonical source under `language/<language>` in the monorepo.
2. Mirror that directory plus `spec/`, `LICENSE`, and a language-specific README.
3. Reuse the language README's registry, install, and scope text; link back to
   the canonical source and documentation.
4. Run the language's conformance and tests in the mirror before publishing it.
5. Add the repository to this page and to the language's `REGISTRY.md` or
   `llms.txt` entry when it becomes active.
