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
