# Behavior Lab

**Status:** evidence tooling, 2026-10-30. The lab is not a stable public API.

The behavior lab runs named agent scenarios in Go, Python, TypeScript, and Java
and writes one comparison report. Rust, Fortran, and COBOL are extended
languages with narrower scenario or native-suite coverage. It answers a
narrower question than the [compatibility lab](compatibility-lab.md): do the
implementations make the same authorization, lifecycle, cancellation,
validation, call-limit, parallel-tool execution, run isolation, PII,
checkpoint, capacity, and stream-failure decisions when exercised through their
own test suites?

It does not prove complete feature parity, provider behavior, live-service
integration, production readiness, or security. A passing report compares the
listed scenarios only.

## Scope

| Scenario | Behavior checked | Go | Python | TypeScript | Java |
| --- | --- | --- | --- | --- | --- |
| `final-arguments` | Mutated arguments are reauthorized before effects | scenario | scenario | scenario | self-test group |
| `final-name` | Final name is checked against the allowlist and policy | scenario | scenario | scenario | self-test group |
| `unchanged-single-auth` | An unchanged call is authorized once | scenario | scenario | scenario | self-test group |
| `initial-denial` | Initial denial prevents middleware and effects | scenario | scenario | scenario | self-test group |
| `startup-cleanup` | Before-run failure cleans entered middleware without run events | scenario | scenario | scenario | self-test group |
| `after-run-continue` | Later after-run callbacks still run after a failure | scenario | scenario | scenario | self-test group |
| `cleanup-failclosed` | Cleanup failure fails a successful run closed | scenario | scenario | scenario | self-test group |
| `model-cancel-cleanup` | Cancellation during model work runs after-run and emits failed | scenario | scenario | scenario | self-test group |
| `tool-cancel-cleanup` | Cancellation during tool work stops effects and runs after-run | scenario | scenario | scenario | self-test group |
| `schema-number-unicode` | Fractional integers are rejected and string length counts code points | scenario | scenario | scenario | scenario |
| `call-limit` | Model and tool call limits fail closed | scenario | scenario | scenario | self-test group |
| `pii-tool-history` | Nested tool-call history is redacted without mutating input | scenario | scenario | scenario | scenario |
| `checkpoint-content` | Allowlist round-trips nested payload content | scenario | scenario | scenario | scenario |
| `capacity-failclosed` | Context budget fails closed instead of dropping required input | scenario | scenario | scenario | self-test group |
| `parallel-tools` | Tools start concurrently up to the limit and keep result order | scenario | scenario | scenario | self-test group |
| `run-state-isolation` | Call-limit state is isolated across concurrent runs | scenario | scenario | scenario | self-test group |
| `stream-callback-error` | Stream callback failure aborts instead of completing the run | scenario | scenario | scenario | scenario |
| `sse-truncated` | SSE streams without completion are rejected | scenario | scenario | scenario | self-test group |
| `sse-half-packet` | SSE half-packets fail instead of being silently dropped | scenario | scenario | scenario | self-test group |

`scenario` means a test named for that behavior. `self-test group` means one
Java self-test executable covers several scenarios, so a passing group does not
identify which scenario assertion failed. The report records that distinction
instead of treating group coverage as scenario-level evidence.

## Extended Coverage

| Scenario | Rust | Fortran | COBOL |
| --- | --- | --- | --- |
| `schema-number-unicode` | scenario | unsupported | unsupported |
| `call-limit` | scenario | native suite | native suite |
| `pii-tool-history` | scenario | native suite | native suite |
| `checkpoint-content` | scenario | native suite | native suite |
| `capacity-failclosed` | scenario | native suite | native suite |
| `run-state-isolation` | scenario | unsupported | unsupported |

`native suite` means the implementation's full native test executable passed.
It is not isolated to the named scenario, so a failure cannot be attributed from
this cell alone. Other Rust, Fortran, and COBOL scenarios remain `unsupported`.
The report shows those cells explicitly instead of dropping the languages.

## Run

From the repository root, after building TypeScript and compiling Java test
classes:

```bash
cd language/typescript; npm ci; npm run build; cd ../..
cd language/java; mvn -q -DskipTests test-compile; cd ../..
python scripts/behavior_lab.py --strict --timeout 300
python scripts/behavior_lab.py --strict --timeout 600 --languages go,python,typescript,java,rust,fortran,cobol
```

The seven-language run also needs a Rust toolchain plus `gfortran`, `gnucobol`,
`g++`, CMake, and Ninja; Fortran builds its pinned RE2 bridge. The native
Fortran/COBOL suite command is cached within one report, so it runs once.

- `--strict` fails on `failed`, `skipped`, `not_run`, and unsupported cells in
  the four core languages. Extended-language holes remain `unsupported`.
- `--languages go,python` limits the run.
- `--timeout 300` sets a per-command timeout.
- `--output-dir build/behavior-lab` changes the report location.

The command writes a new directory for each execution:

- `build/behavior-lab/<run-id>/report.json`
- `build/behavior-lab/<run-id>/report.md`
- `build/behavior-lab/latest.json` (pointer to the newest report)

The report records the run ID, UTC start/finish, the Git revision and dirty
state captured before the run, platform, each scenario, the commands used, exit
code, duration, and bounded stdout/stderr tails. Cells are one of `passed`,
`failed`, `skipped`, `not_run`, or `unsupported`. Earlier run directories are not
overwritten; `latest.json` is only a convenience pointer.

## Current Evidence

The four-language local nineteen-scenario run on 2026-10-31 passed all 76
cells. The seven-language local run passed 90 cells with 43 explicit
`unsupported` cells and no failures. Both runs used a working tree with
uncommitted changes, so they are not clean-SHA records. Use the clean-SHA Linux
CI behavior job and artifact for the revision you are citing.

## Limits

- Nineteen selected scenarios, not full agent or contract parity.
- Go and Python use scenario-level tests; TypeScript uses `node --test` name
  filters; some Java self-tests cover more than one scenario.
- Rust has scenario-level tests for selected rows. Fortran and COBOL use
  native-suite coverage, not scenario-isolated assertions.
- The parallel scenario uses deterministic barriers; it is not a throughput or
  stress test. SSE tests use local fixtures, not a provider.
- No provider, model, network, sandbox, HITL, checkpoint persistence, or
  effect-recovery scenario.
- A passing report is not a security review or production certification.
