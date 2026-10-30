# Behavior Lab

**Status:** evidence tooling, 2026-10-30. The lab is not a stable public API.

The behavior lab runs named agent scenarios in Go, Python, TypeScript, and Java
and writes one comparison report. It answers a narrower question than the
[compatibility lab](compatibility-lab.md): do the implementations make the same
authorization, middleware lifecycle, and cancellation decisions when exercised
through their own test suites?

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

`scenario` means a test named for that behavior. `self-test group` means one
Java self-test executable covers several scenarios, so a passing group does not
identify which scenario assertion failed. The report records that distinction
instead of treating group coverage as scenario-level evidence.

Rust, Fortran, COBOL, and the remaining implementations are outside the first
scope. They should be added only after they expose equivalent agent lifecycle
hooks and named behavior tests.

## Run

From the repository root, after building TypeScript and compiling Java test
classes:

```bash
cd language/typescript; npm ci; npm run build; cd ../..
cd language/java; mvn -q -DskipTests test-compile; cd ../..
python scripts/behavior_lab.py --strict --timeout 300
```

- `--strict` fails on `failed`, `skipped`, `not_run`, and `unsupported` cells.
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

The four-language local run on 2026-10-30 passed all 36 cells. The run was made
from a working tree with uncommitted evidence-tooling changes, so it is not a
clean-SHA record. Use the CI artifact and merged revision when citing the
behavior report as evidence.

## Limits

- Nine selected scenarios, not full agent or contract parity.
- Go and Python use scenario-level tests; TypeScript uses `node --test` name
  filters; Java uses group self-tests.
- No provider, model, network, sandbox, HITL, checkpoint, or effect-recovery
  scenario.
- A passing report is not a security review or production certification.
