# Compatibility Lab

**Status:** evidence tooling, 2026-10-30. The lab is not a stable public API.

The compatibility lab runs the existing deterministic Core conformance checks for
selected language implementations and writes a reproducible report. It answers a
narrow question: do the declared vector groups and parity checks pass for these
implementations on this machine and toolchain?

It does not prove full Go feature parity, provider behavior, live-service
integration, production readiness, or security. Use the
[language support matrix](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md)
and the [verification evidence](../project/verification-evidence.md) page for
those separate claims.

## Scope

The first scope is Python, TypeScript, Java, and Rust. Fortran and COBOL are the
second batch; the Linux CI job runs all six. Each entry runs the implementation's
own conformance entry point:

| Language | Commands |
| --- | --- |
| Python | `conformance/run.py`, `api-snapshot.py --check`, `api-signatures.py --check` |
| TypeScript | `npm run build`, `npm run api:check`, `npm run conformance` |
| Java | `mvn -q -DskipTests package`, `ApiSnapshot --check`, conformance runner |
| Rust | `cargo run --quiet --bin conformance`, `api-snapshot.py --check` |
| Fortran | `run-tests.py` (native tests, vectors, API snapshot) |
| COBOL | `run-tests.py` (native tests, vectors, API snapshot) |

The lab covers the shared contract vectors, API snapshots or signatures, and,
where the implementation has it, its parity check. It does not start a model,
call a provider, use credentials, or run a live workspace provider.

## Run

From the repository root:

```bash
python scripts/compatibility_lab.py --install --strict
```

- `--install` runs the language setup step (`npm ci` for TypeScript) before the
  build.
- `--strict` treats skipped languages or toolchains as a failure.
- `--languages python,java` limits the run.
- `--languages python,typescript,java,rust,fortran,cobol` runs the full Linux CI
  set.
- `--timeout 300` sets a per-command timeout.

The command writes:

- `build/compatibility-lab/report.json`
- `build/compatibility-lab/report.md`

The report records the Git revision and dirty state, platform, toolchain
versions, every command, exit code, duration, and bounded stdout/stderr tails.
It preserves failures and skips rather than replacing them with later runs.

## Current Evidence

The 2026-10-30 local run passed the first four implementations; a follow-up
local run also passed Fortran. COBOL is exercised by the Linux CI job because
the local host does not have GnuCOBOL:

| Language | Result | Toolchain |
| --- | --- | --- |
| Python | passed | Python 3.14.6 |
| TypeScript | passed | Node.js 24.18.0 |
| Java | passed | OpenJDK 21.0.8 |
| Rust | passed | Cargo 1.96.0 |
| Fortran | passed | GNU Fortran 16.2.0 |
| COBOL | Linux CI batch | GNU COBOL |

The first local run was from a workspace with uncommitted evidence-tooling
changes, so it is not a clean-SHA release record. Use the CI artifact and the
merged revision when citing the full six-language set.

## Adding A Language

Add a language definition to `scripts/compatibility_lab.py` with:

- an executable conformance entry point in the language tree;
- a toolchain version command;
- any required build/setup command;
- a stable working directory.

The language must already have a released or declared conformance runner. Do not
add a language merely to increase the count. A new entry should be reviewed with
the same contract, parity, and evidence separation used by the language matrix.

## Limits

- Contract conformance only, not feature coverage or operational evidence.
- One platform and one toolchain set per run.
- No provider, model, network, sandbox, HITL, checkpoint, or effect-recovery
  scenario.
- A passing report is not a security review or production certification.
