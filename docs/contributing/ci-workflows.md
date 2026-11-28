# CI Workflows

CI is split by path so a language-only change does not run the full matrix.
`ci.yml` remains the core/shared and scheduled full-matrix entry point.

## Workflow Map

| Workflow | Scope | Triggered by |
| --- | --- | --- |
| `ci.yml` | Go/core, shared checks, bridges, quality, security, full matrix | Every main push; path-filtered PRs; schedule; manual dispatch |
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
| `ci-additional.yml` | Dart, Perl, D, Delphi example matrix | Their example and SDK source dependencies |
| `ci-additional2.yml` | PowerShell and MATLAB/Octave example matrix | Their example and shared-runtime dependencies |
| `ci-additional3.yml` | Swift, Julia, Haskell, OCaml, Nim, V, Zig, Objective-C example matrix | Their example and SDK source dependencies |
| `ci-examples.yml` | Go examples, SDK examples, Go consumer and recipes | `language/go/examples/**` and selected language example paths |
| `docs.yml` | Documentation build, registry checks, consumer pins | `docs/**`, metadata, selected scripts and workflows |
| `ci-applications.yml` | Reference applications | Application changes and their SDK dependencies |
| `ci-tutorials.yml` | Tutorial catalog and runnable tutorials | Catalog inputs and tutorial/SDK dependencies |
| `ci-labs.yml` | Behavior and compatibility labs | Selected SDKs, shared dependencies, schedule, manual dispatch |
| `ci-bridge.yml` | Go bridge and shared-runtime bindings | Bridge and Go/core dependencies |

Shared changes under `spec/` and `.github/actions/`, plus scripts without an
explicit docs-only scope, still trigger full test matrices. Known documentation,
registry/discovery, and mirror helpers are listed in `DOCS_SCRIPTS` in
`scripts/ci_changes.py`; they run docs/mirror validation rather than SDK runtimes.
Discovery JSON and SDK documentation Markdown, README, REGISTRY, and llms entries
also stay in docs/mirror/catalog checks, including nested tutorial READMEs.
Markdown under normative `spec/` is still a shared contract input, except the
documentation-only implementation status page `spec/languages.md`. Markdown in
source directories, such as embedded prompts, retains runtime checks unless it
matches a conventional documentation filename or documentation directory.
Package/build manifests still select runtime
gates because they can change actual dependencies.
Each test workflow also runs fully when its own workflow file changes or when
manually dispatched. Other workflow changes do not request a global full run.
Scheduled runs remain full runs.

Root README and ordinary documentation-only changes are handled by `docs.yml`.
Tutorial catalog documentation also runs the catalog check, not every tutorial.
PR triggers remain path-filtered. Every main push starts both `ci.yml` and
`docs.yml` because the release gate requires successful main-push results from
both workflows for that exact commit; manual runs cannot substitute. Docs-only
and independently owned SDK/application pushes run the real `ci.yml` changes
and routing checks without selecting its runtime portfolio. Dedicated SDK gates
remain scoped. Mirror pull-request checks are isolated from serialized mirror
writes.

Jobs are filtered before expanding their matrices. SDK changes select that SDK's
tests, consumers, examples, tutorials, applications, and dependent shared-runtime
samples. Application-only changes select application jobs, not SDK or consumer
jobs. Go/core changes retain Go, bridge, adapter, security, and quality coverage.
Ordinary push/PR jobs belong to their dedicated workflows. Duplicate portfolio
jobs in `ci.yml` run only for full requests; unique portfolio gates remain scoped.
Lab language arguments are intersections with the selected languages, and their
toolchain setup and build steps are filtered too. The bundled SDK examples keep
all their checks but execute only the selected SDK's steps. Cross-SDK service
integration runs require a full request.

`LANGUAGE_SCRIPTS` scopes the PHP package builder and tests to PHP. The Ubuntu
`php-package` gate runs `scripts/test_php_package.py` with PHP and Composer;
documentation uses an explicit metadata test list instead of discovering runtime
script tests on README-only changes. The full-only portfolio `script-tests` job
retains the complete script test suite, including tests without a dedicated owner.
Superseded push and pull-request test runs are cancelled within the same workflow
and event/ref; manual and scheduled runs are not cancelled by those runs.

## Adding or Changing a Language Workflow

1. Add the workflow under `.github/workflows/`.
2. Include the language's conformance, consumer, and sample jobs with explicit
   `language/<language>` paths in commands or working directories.
3. Run `python scripts/sync_ci_routing.py` to regenerate triggers and job filters.
4. Run `python scripts/sync_ci_routing.py --check` and
   `python -m unittest discover -s scripts -p test_ci_changes.py -v`, plus
   `python -m unittest discover -s scripts -p test_ci_execution.py -v` (PyYAML).
5. Review indirect dependencies in `scripts/ci_changes.py`. The generator reads
   explicit language paths, consumer job names, scoped scripts, and lab selections;
   dependencies hidden inside other scripts need explicit routing and tests.
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
