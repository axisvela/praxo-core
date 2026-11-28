# Repository Layout and Source Migration

Language source is grouped by responsibility. The Go module, public `pkg/...`
imports, package names, normative wire contract, and existing release tags are
unchanged. This is a source-tree migration, not a new framework release.

| Location | Purpose |
| --- | --- |
| `pkg/`, `internal/`, `cmd/` | Go reference implementation and bridge CLI |
| `language/<language>/` | Independent language implementations, tests, build output, per-language `CHANGELOG.md` |
| `language/powershell/` | PowerShell Core wrapper over the C# Core |
| `bindings/shell/`, `bindings/powershell/` | Bridge wrappers over the bridge runtime |
| `language/javascript/examples/`, `language/kotlin/examples/`, `language/scala/examples/`, `language/groovy/examples/`, `language/clojure/examples/`, `language/fsharp/examples/`, `language/opencl/examples/` | Samples consuming TypeScript, Java, .NET, or C |
| `language/go/examples/` | Go reference examples and cross-language integration examples |
| `adapters/` | Optional integrations |
| `spec/` | Normative contract, shared vectors, and parity inventories |
| `docs/` | Public documentation |
| `docs/languages/<language>/` | Per-language documentation; may hold examples, adapter notes, and release pages |
| `build/` | Local, Git-ignored artifacts, environments, logs, drafts, and scratch files |

## Updating a Source Checkout

The previous `sdk/<language>/` source paths have moved to
`language/<language>/`. Update source-based consumers, CI scripts, package
paths, and editor configuration. The `sdk/` directory is not kept as a shim.

Root-level `python/`, `typescript/`, `java/`, `rust/`, `c/`, `cpp/`, `csharp/`,
`php/`, `ruby/`, `perl/`, `lua/`, `dart/`, `swift/`, `julia/`, `r/`, `d/`,
`zig/`, `cobol/`, and `fortran/` are now under `language/`.

Root-level `shell/` and `powershell/` are now under `bindings/`. Root-level
`examples/` moved under `language/go/examples/`. Sample-only language trees are at
`language/javascript/examples/`, `language/kotlin/examples/`,
`language/scala/examples/`, `language/groovy/examples/`, and
`language/clojure/examples/`. The F# and OpenCL samples are at `language/fsharp/examples/` and
`language/opencl/examples/`. The Visual Basic sample remains with the .NET Core at
`language/csharp/samples/VbSample/`.

Update local scripts, CI working directories, source dependency paths, and
paths in editor or build configuration. For example, from the repository root:

```bash
pip install ./language/python
cmake -S language/c -B build/c
swift build --package-path language/swift
```

Swift and C consumers using a source checkout must select the new package or
source directory explicitly. A normal Swift Git package dependency cannot
select a nested manifest by URL alone; use a local package path or an appropriate
distribution wrapper. No root Swift package is introduced by this move.

Keep old tags pinned if you need their historical layout. New checkouts use the
new paths; compatibility shims for old root-level directories are not provided.
Do not reuse an old CMake build cache across source locations. Configure a fresh
build directory after updating.

## Language Documentation and Build Layout

Each language owns a documentation directory at
`docs/languages/<language>/`. The main page is `index.md`; future examples,
adapter notes, and release pages belong in the same directory instead of the
shared language root.

Language release notes live next to the implementation at
`language/<language>/CHANGELOG.md` and are linked from the language README.

`build/` is a local, Git-ignored workspace. Keep generated output out of
version control and group it by lifecycle:

```text
build/
  artifacts/    release archives and compiled binaries
  envs/         virtualenvs, Composer homes, consumer installs
  caches/       CMake, Nim, Composer, Elixir, and OCaml caches
  logs/         timestamped logs and CI snapshots
  drafts/       issue and release drafts awaiting a durable home
  scratch/      one-off scripts and temporary inputs
  toolchain/    reusable local tool assets such as a CA bundle
  work/         publication checkouts and ad-hoc package validation
```

`build/php-split/` and `build/ocaml-package/` are fixed tool outputs referenced
by package documentation. Language-specific build caches may remain under
`language/<language>/build` during migration; new tooling should prefer the
owned build directory and document any exception. Anything under `build/` is
disposable unless it is a draft, retained evidence, or a reusable tool asset
that has been moved to a durable location.

## What Did Not Change

Do not change imports such as `praxo`, `@axisvela/praxo-core`,
`com.axisvela.praxo`, or the Go module path merely because the source moved.
Existing tag prefixes such as `python/v0.2.0` identify the same historical
release. Source tags still do not imply package-registry publication.

Run each language's documented conformance, API, and test commands from its new
location. See [Core support](../../languages/support.md) for feature and distribution limits.
