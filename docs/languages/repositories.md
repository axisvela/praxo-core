# Language Repositories

PRAXO-CORE is a multi-language framework. Go is the reference implementation;
other implementations have independent packages and dedicated repositories so
that language-specific discovery does not depend on finding a subdirectory in a
Go-oriented monorepo.

The canonical source, specification, and release workflows remain in
[`axisvela/praxo-core`](https://github.com/axisvela/praxo-core). A dedicated
repository is either a publication source or a discovery mirror; the registry
version remains the authority for what consumers install.

## Implemented Languages

| Language | Repository | Role |
| --- | --- | --- |
| Python | [axisvela/praxo-core-python](https://github.com/axisvela/praxo-core-python) | Discovery mirror of `language/python`; includes `spec/` for conformance |
| TypeScript | [axisvela/praxo-core-typescript](https://github.com/axisvela/praxo-core-typescript) | Discovery mirror of `language/typescript`; includes `spec/` for conformance |
| Java | [axisvela/praxo-core-java](https://github.com/axisvela/praxo-core-java) | Discovery mirror of `language/java`; includes `spec/` |
| Rust | [axisvela/praxo-core-rust](https://github.com/axisvela/praxo-core-rust) | Discovery mirror of `language/rust`; includes `spec/` |
| C# / .NET | [axisvela/praxo-core-csharp](https://github.com/axisvela/praxo-core-csharp) | Discovery mirror of `language/csharp`; includes `spec/` |
| R | [axisvela/praxo-core-r](https://github.com/axisvela/praxo-core-r) | Discovery mirror of `language/r`; includes `spec/` |
| Elixir | [axisvela/praxo-core-elixir](https://github.com/axisvela/praxo-core-elixir) | Discovery mirror of `language/elixir`; includes `spec/` |
| Ruby | [axisvela/praxo-core-ruby](https://github.com/axisvela/praxo-core-ruby) | RubyGems publication source |
| PHP | [axisvela/praxo-core-php](https://github.com/axisvela/praxo-core-php) | Packagist publication source |
| Lua | [axisvela/praxo-core-lua](https://github.com/axisvela/praxo-core-lua) | Dedicated Lua repository |
| Swift | [axisvela/praxo-core-swift](https://github.com/axisvela/praxo-core-swift) | Swift Package Index source |
| Julia | [axisvela/praxo-core-julia](https://github.com/axisvela/praxo-core-julia) | Julia General Registry mirror |
| V | [axisvela/praxo-core-v](https://github.com/axisvela/praxo-core-v) | Split V repository |
| OCaml | [axisvela/praxo-core-ocaml](https://github.com/axisvela/praxo-core-ocaml) | Split OCaml repository |
| Nim | [axisvela/praxo-core-nim](https://github.com/axisvela/praxo-core-nim) | Split Nim repository |
| D | [axisvela/praxo-core-d](https://github.com/axisvela/praxo-core-d) | DUB publication source |
| Erlang | [axisvela/praxo-core-erlang](https://github.com/axisvela/praxo-core-erlang) | Discovery mirror of `language/erlang`; includes `spec/` |
| Perl | [axisvela/praxo-core-perl](https://github.com/axisvela/praxo-core-perl) | Discovery mirror of `language/perl`; includes `spec/` |
| Haskell | [axisvela/praxo-core-haskell](https://github.com/axisvela/praxo-core-haskell) | Discovery mirror of `language/haskell`; includes `spec/` |
| Dart | [axisvela/praxo-core-dart](https://github.com/axisvela/praxo-core-dart) | Discovery mirror of `language/dart`; includes `spec/` |
| Zig | [axisvela/praxo-core-zig](https://github.com/axisvela/praxo-core-zig) | Discovery mirror of `language/zig`; includes `spec/` |
| C | [axisvela/praxo-core-c](https://github.com/axisvela/praxo-core-c) | Discovery mirror of `language/c`; includes `spec/` |
| C++ | [axisvela/praxo-core-cpp](https://github.com/axisvela/praxo-core-cpp) | Discovery mirror of `language/cpp`; includes `spec/` |
| Fortran | [axisvela/praxo-core-fortran](https://github.com/axisvela/praxo-core-fortran) | Discovery mirror of `language/fortran`; includes `spec/` |
| COBOL | [axisvela/praxo-core-cobol](https://github.com/axisvela/praxo-core-cobol) | Discovery mirror of `language/cobol`; includes `spec/` |
| PowerShell | [axisvela/praxo-core-powershell](https://github.com/axisvela/praxo-core-powershell) | Discovery mirror of `language/powershell`; includes `spec/` |
| MATLAB | [axisvela/praxo-core-matlab](https://github.com/axisvela/praxo-core-matlab) | Discovery mirror of `language/matlab` with the shared MATLAB/Octave core |
| GNU Octave | [axisvela/praxo-core-octave](https://github.com/axisvela/praxo-core-octave) | Discovery mirror of `language/octave` with the shared MATLAB/Octave core |
| Delphi / Free Pascal | [axisvela/praxo-core-delphi](https://github.com/axisvela/praxo-core-delphi) | Discovery mirror of `language/delphi`; includes `spec/` |
| Objective-C | [axisvela/praxo-core-objc](https://github.com/axisvela/praxo-core-objc) | Discovery mirror of `language/objc`; includes `spec/` |

Go remains at the repository root because its module path is
`github.com/axisvela/praxo-core/v2`. Bridges under `bindings/` and language
samples under `examples/` remain in the monorepo.

## Why Mirrors Include `spec/`

A mirror keeps the canonical `language/<language>` tree and the shared `spec/`
vectors so its tests and conformance runner work. It does not replace the
monorepo release workflow. Mirrors are refreshed from the canonical source; if a
mirror lags, use the monorepo and the registry version. Do not infer registry
availability, conformance, or production readiness from the existence of a
repository.

## Adding or Updating a Repository

1. Keep the canonical source under `language/<language>` in the monorepo.
2. Mirror that directory plus `spec/`, `LICENSE`, and a language-specific README.
3. Reuse the language README's registry, install, and scope text; link back to
   the canonical source and documentation.
4. Run the language's conformance and tests in the mirror before publishing it.
5. Add the repository to this page and to the language's `REGISTRY.md` or
   `llms.txt` entry when it becomes active.
