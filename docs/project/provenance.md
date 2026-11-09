# License and Provenance

PRAXO-CORE is MIT-licensed. See the
[LICENSE](https://github.com/axisvela/praxo-core/blob/main/LICENSE).

## Provenance Rules

- Only AxisVela-owned code, or code with explicit relicensing permission, may
  enter this repository.
- **AxisVela-authorized internal reuse:** PRAXOVELA implementation code may be
  copied into PRAXO-CORE under an internal relicensing record maintained by
  AxisVela.
- Record the source path and source commit for every copied package.
- Do not import AGPL-only third-party packages.
- Preserve copyright notices and third-party notices.
- Contributions require a CLA or equivalent relicensing grant.

## Scoped AKROVELA Recipe Reuse

On 2026-11-09 the project owner authorized selected AxisVela-owned AKROVELA
recovery patterns to be adapted under MIT into application recipes. This grant
does not cover third-party AGPL-only code and does not change AKROVELA's license.
The internal authorization record retains the approval reference and review scope.

Source: `axisvela/akrovela` commit
`bc8ef5fd0ae34a81debf9d83a494a467adc46f36`,
`backend/internal/satellite/agent.go`, `journal.go` and `agent_test.go`.
Destination: `examples/recipes/long-running-go/execution.go`,
`execution_test.go`, `execution_process_test.go` and recovery documentation.
The adaptations retain only generic durable-start, uncertainty and retry-safety
behavior; no product package is imported and no Core public API is added.

## Why MIT

The framework is intended for embedding by:

- PRAXOVELA (AGPL product)
- external products

MIT keeps the framework reusable while the products retain their own licenses.

## PRAXOVELA Relationship

PRAXOVELA remains AGPL-3.0. It consumes the MIT framework but does not relicense
the product. The framework is a separate work with a separate repository.

The reverse direction is authorized under the same internal relicensing
record: PRAXOVELA implementation code may be copied into PRAXO-CORE and
relicensed as MIT. The copy must be recorded with its source path and commit.

## Native Core Work

The `language/cobol/` and `language/fortran/` sources are original MIT-licensed
implementations of the contracts in `spec/`; their source tags are
`cobol/v0.1.1` and `fortran/v0.2.1`. Context compaction in the Fortran Core implementation
follows the reference algorithm in `pkg/agent/context/compact.go`. No
third-party JSON parser source is copied into these Core implementations.

GnuCOBOL, GNU Fortran, and their runtimes are external toolchain dependencies,
not vendored Core source. Their separate licenses and redistribution obligations
continue to apply to compiler and runtime distributions.

Fortran `0.3.0` adds an original MIT C ABI wrapper
around RE2 2025-11-05 (BSD-3-Clause) and Abseil 20250512.1 (Apache-2.0).
The native build fetches immutable upstream revisions rather than copying their
source into this repository, and installs both original license files with the
wrapper. Their licenses and runtime redistribution obligations still apply.
See the [dependency record](https://github.com/axisvela/praxo-core/blob/main/language/fortran/native/DEPENDENCIES.md).
