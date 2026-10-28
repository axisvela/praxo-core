# Repository Layout and Source Migration

Language source is grouped by responsibility. The Go module, public `pkg/...`
imports, package names, normative wire contract, and existing release tags are
unchanged. This is a source-tree migration, not a new framework release.

| Location | Purpose |
| --- | --- |
| `pkg/`, `internal/`, `cmd/` | Go reference implementation and bridge CLI |
| `language/<language>/` | Independent language implementations |
| `bindings/shell/`, `bindings/powershell/` | Wrappers over the bridge runtime |
| `examples/javascript/`, `examples/kotlin/`, `examples/scala/`, `examples/groovy/`, `examples/clojure/`, `examples/fsharp/`, `examples/opencl/` | Samples consuming TypeScript, Java, .NET, or C |
| `adapters/` | Optional integrations |
| `spec/` | Normative contract, shared vectors, and parity inventories |
| `docs/` | Public documentation |

## Updating a Source Checkout

The previous `sdk/<language>/` source paths have moved to
`language/<language>/`. Update source-based consumers, CI scripts, package
paths, and editor configuration. The `sdk/` directory is not kept as a shim.

Root-level `python/`, `typescript/`, `java/`, `rust/`, `c/`, `cpp/`, `csharp/`,
`php/`, `ruby/`, `perl/`, `lua/`, `dart/`, `swift/`, `julia/`, `r/`, `d/`,
`zig/`, `cobol/`, and `fortran/` are now under `language/`.

Root-level `shell/` and `powershell/` are now under `bindings/`. Root-level
`javascript/`, `kotlin/`, `scala/`, `groovy/`, and `clojure/` are now under
`examples/`. The F# and OpenCL samples are at `examples/fsharp/` and
`examples/opencl/`. The Visual Basic sample remains with the .NET Core at
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

## What Did Not Change

Do not change imports such as `praxo`, `@axisvela/praxo-core`,
`io.axisvela.praxo`, or the Go module path merely because the source moved.
Existing tag prefixes such as `python/v0.2.0` identify the same historical
release. Source tags still do not imply package-registry publication.

Run each language's documented conformance, API, and test commands from its new
location. See [Core support](../languages/support.md) for feature and distribution limits.
