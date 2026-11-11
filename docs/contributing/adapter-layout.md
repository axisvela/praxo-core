# Core and Adapter Layout

Keep the execution kernel and optional integrations separate. Core code must not
import provider SDKs, HTTP clients used only by an adapter, or product packages.
Adapters are optional, may change independently, and must not widen the Go API.

## Go

- Core: `pkg/...`
- Optional adapters: `adapters/<name>/` as independent modules
- Shared specification: `spec/`

## Independent Core Implementations

Use an `adapters/` subdirectory inside the language package. Keep public module
or package names stable when a move would otherwise break consumers; use a
re-export or a thin compatibility file at the old path.

| Language | Adapter location | Status |
| --- | --- | --- |
| Python | `praxo/adapters/` | separated |
| TypeScript | `src/adapters/` | separated |
| Java | `src/main/java/com/axisvela/praxo/adapters/` | separated |
| Ruby | `lib/praxo/adapters/` | separated |
| PHP | `src/Adapters/` | separated |
| Perl | `lib/Praxo/Adapters/` | separated |
| Nim | `src/praxo/adapters/` | separated |
| Dart | `lib/src/adapters/` | separated |
| C# | `Praxo.Core/Adapters/` | separated (same namespace) |
| Swift | `Sources/PraxoCore/Adapters/` | separated (same module) |
| Julia | `src/adapters/` | separated |
| Lua | `praxo/adapters/` | separated; old-path wrappers remain |
| Haskell | `src/Praxo/Adapters/` | planned; keep module re-exports |
| Rust | `src/adapters/` | separated; root re-exports remain |
| Elixir | `lib/praxo/adapters/` | separated; module names stay stable |
| Erlang | `src/adapters/` | planned; update build/app module list |
| OCaml | separate adapter module | planned |
| C / C++ / Fortran | `adapters/<language>/` | planned; update build includes |
| Delphi / Objective-C / MATLAB / Octave / Zig / V / D | `adapters/` | planned; update build/tests |
| PowerShell | C# runtime | inherited; no separate adapter code |

## Rules

1. Core code must compile and pass conformance without adapter files.
2. Adapter files are optional and must not be imported by core entry points.
3. Adapter tests may use injected transports; a live provider is not required.
4. Keep public paths stable during a move; add a re-export or compatibility file.
5. Update the API snapshot scanner when adapters move to a nested directory.
6. Update the language README, `REGISTRY.md`, and tests in the same change.
7. Do not add a dependency that changes the MIT license boundary.
