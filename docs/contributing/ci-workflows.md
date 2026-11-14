# CI Workflows

CI is split by path so a language-only change does not run the full matrix.
`ci.yml` remains the core/shared and scheduled full-matrix entry point.

## Workflow Map

| Workflow | Scope | Triggered by |
| --- | --- | --- |
| `ci.yml` | Go/core, shared checks, bridges, behavior/compatibility labs, quality, security, full matrix | Changes outside ignored language/example/adapter paths; schedule; manual dispatch |
| `ci-python.yml` | Python conformance and consumer | `language/python/**` |
| `ci-typescript.yml` | TypeScript conformance, consumer, JavaScript sample | `language/typescript/**` |
| `ci-java.yml` | Java conformance, consumer, Kotlin/Scala/Groovy/Clojure samples | `language/java/**` |
| `ci-rust.yml` | Rust conformance | `language/rust/**` |
| `ci-dotnet.yml` | C# conformance and PowerShell Core | `language/csharp/**`, `language/powershell/**` |
| `ci-extended.yml` | Ruby, PHP, Elixir, Erlang, Lua | Their `language/<language>/**` paths |
| `ci-native.yml` | C, C++, Fortran, COBOL, OpenCL sample | Their paths and `language/opencl/examples/**` |
| `ci-optional.yml` | Haskell, Swift, Dart, Julia, R | Their `language/<language>/**` paths |
| `ci-optional2.yml` | MATLAB, Octave, OCaml, Objective-C, Nim, V, D, Zig, Perl | Their `language/<language>/**` paths |
| `ci-adapters.yml` | Adapter modules and adapter module-security | `adapters/**` |
| `ci-examples.yml` | Go examples, SDK examples, Go consumer and recipes | `examples/**` and selected language example paths |
| `docs.yml` | Documentation build, registry checks, consumer pins | `docs/**`, metadata, selected scripts and workflows |

Shared changes under `spec/`, `scripts/`, and `.github/` still trigger the full
`ci.yml` matrix. This is intentional: they can affect every language contract.

Documentation-only changes are handled by `docs.yml`; `ci.yml` ignores
`docs/**`, Markdown files, `mkdocs.yml`, and `requirements-docs.txt`.

## Adding or Changing a Language Workflow

1. Add the workflow under `.github/workflows/`.
2. Trigger on `language/<language>/**` and its own workflow file.
3. Include the language's conformance, consumer, and sample jobs.
4. Add `language/<language>/**` to `paths-ignore` in `ci.yml`.
5. Keep shared `spec/` and compatibility coverage in `ci.yml`; do not duplicate
   the full matrix in every language workflow.
6. Update the branch protection required checks to the new
   `<workflow> / <job>` names.

## Required Checks

Required checks are named `<workflow> / <job>`, for example:

- `ci-python / python-conformance`
- `ci-java / java-conformance`
- `ci-dotnet / csharp-conformance`
- `ci-adapters / adapters`

When a workflow is split, update branch protection in the same change window.
Otherwise pull requests wait for a check name that no longer exists.

## Local Equivalents

Use the commands in the repository `AGENTS.md` for the same language gates. A
path-scoped workflow does not lower the acceptance bar; it only avoids running
unrelated jobs.
