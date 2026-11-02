# Behavior Lab

**Status:** evidence tooling, 2026-11-02. The lab is not a stable public API.

The behavior lab runs named agent scenarios across sixteen wired
implementations and writes one comparison report. The agent-capable tier is Go,
Python, TypeScript, Java, Rust, R, and C#; the extended tier is C, PHP, Fortran,
COBOL, Ruby, Elixir, Erlang, C++, and Lua. Other declared implementations are
optional and outside the current behavior program. It answers a
narrower question than the [compatibility lab](compatibility-lab.md): do the
implementations make the same authorization, lifecycle, cancellation,
validation, call-limit, parallel-tool execution, run isolation, PII,
checkpoint, capacity, and stream-failure decisions when exercised through their
own test suites?

It does not prove complete feature parity, provider behavior, live-service
integration, production readiness, or security. A passing report compares the
listed scenarios only.

## Capability Tiers

Behavior tier is separate from contract tier. See the
[support policy](support.md) for the definition.

| Tier | Languages | Current status |
| --- | --- | --- |
| Agent-capable | Go, Python, TypeScript, Java, Rust, R, C# | 20/20 for every agent-capable implementation |
| Extended | C, PHP, Fortran, COBOL, Ruby, Elixir, Erlang, C++, Lua | All twenty scenarios for C, PHP, Fortran, COBOL, Ruby, Elixir, Erlang, C++, and Lua |
| Optional | Other declared implementations | Outside the current behavior program |

R and C are now wired. C# and PHP include the three lifecycle scenarios, and R
and C contribute native-suite coverage for the data and state scenarios their
suites assert. COBOL `0.3.0` covers all twenty scenarios through its native
suite; its parallel-tools case delegates concurrent execution to a
caller-provided batch dispatcher, and the native test verifies the batch limit
and ordered results rather than OS threads. Ruby `0.3.0` also reaches 20/20 with
native-suite coverage for cancellation, stream callbacks, SSE truncation and
half packets, bounded parallel tools, and run-scoped call limits. C++ `0.3.0`
also reaches 20/20 with `std::async` parallel tools and native SSE parsing.
Elixir `0.3.0` reaches 20/20 with `Task.async` parallel tools, cancellation,
stream callbacks, and a native SSE parser. Erlang `0.3.0` reaches 20/20 with
spawned-process parallel tools and the same lifecycle coverage. Lua `0.3.0`
reaches 20/20 with caller-provided `batch_invoke` cooperative tools, cancellation,
stream callbacks, and a native SSE parser. PHP `0.3.0` reaches 20/20 with
caller-provided `batchToolInvoker` Fibers for parallel tools. Fortran `0.5.0`
reaches 20/20 with cancellation, stream callbacks, a native SSE parser, and a
caller-provided parallel batch callback.

## Scope

The table below shows scenario-isolated evidence for the four original core
implementations. Agent-capable Rust, R, and C#, plus the wired extended
languages, are reported in the [matrix](behavior-lab-matrix.md).

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
| `hitl-decision` | Interrupted calls apply approve, edit, reject, and respond decisions | scenario | scenario | scenario | self-test group |

`scenario` means a test named for that behavior. `self-test group` means one
Java self-test executable covers several scenarios, so a passing group does not
identify which scenario assertion failed. The report records that distinction
instead of treating group coverage as scenario-level evidence.

## Extended Coverage

| Scenario | Rust | Fortran | COBOL | Ruby | Elixir | Erlang | C++ | PHP | C# | Lua |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `schema-number-unicode` | scenario | unsupported | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite |
| `call-limit` | scenario | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite |
| `pii-tool-history` | scenario | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite |
| `checkpoint-content` | scenario | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite |
| `capacity-failclosed` | scenario | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite | native suite |
| `run-state-isolation` | scenario | unsupported | native suite | native suite | native suite | native suite | native suite | native suite | native suite | unsupported |

`native suite` means the implementation's full native test executable passed.
It is not isolated to the named scenario, so a failure cannot be attributed from
this cell alone. All sixteen wired languages now cover all twenty scenarios in
the source; optional implementations remain outside this program.

C# has native-suite coverage for `final-arguments`, `final-name`,
`unchanged-single-auth`, and `initial-denial`. The extended languages have
native-suite coverage for all twenty scenarios, including cancellation, stream
callback failure, SSE truncation and half packets, parallel tools, and run-state
isolation. The full cell-by-cell matrix and per-language reports are in the
[Behavior Lab Matrix](behavior-lab-matrix.md).

## Run

From the repository root, after building TypeScript, compiling Java test
classes, and building the C++ tests:

```bash
cd language/typescript; npm ci; npm run build; cd ../..
cd language/java; mvn -q -DskipTests test-compile; cd ../..
cmake -S language/cpp -B language/cpp/build
cmake --build language/cpp/build
python scripts/behavior_lab.py --strict --timeout 300
python scripts/behavior_lab.py --strict --timeout 600 --languages go,python,typescript,java,rust,fortran,cobol,ruby,elixir,erlang,cpp,php,csharp,lua,r,c
```

The sixteen-language run needs a Rust toolchain plus `gfortran`, `gnucobol`,
`g++`, C and C++ build directories, CMake, and Ninja; Ruby; Elixir 1.20.4 on
Erlang/OTP 29; PHP 8.4; the .NET 8 SDK; R; and Lua 5.4. Fortran builds its
pinned RE2 bridge. The native Fortran/COBOL/Erlang/C++/PHP/C#/Lua/R suite
commands, the C `ctest` suite, the Ruby test runner, and the Elixir `mix run`
suite are cached within one report, so each runs once.
`scripts/cpp_behavior_suite.py` adds the C++ compiler runtime directory to
`PATH` before invoking `ctest`. Build the C suite before running the lab:

```bash
cmake -S language/c -B language/c/build
cmake --build language/c/build
```

- `--strict` fails on `failed`, `skipped`, `not_run`, and unsupported cells in
  the four scenario-wired core languages. Holes in other tiers remain
  `unsupported`.
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

The clean-tree CI run at `b6218e5` on 2026-11-02 (run
`20261102T074406Z-700663b3`) passed the sixteen-language set with 320 passed, 0
explicitly unsupported, and no failures: every wired language reaches 20/20.
The [Behavior Lab Matrix](behavior-lab-matrix.md) reflects that report and links
the [behavior job](https://github.com/axisvela/praxo-core/actions/runs/41407891314/job/125153985339).
COBOL reaches 20/20 through native-suite coverage, with parallel tools delegated
to a caller-provided batch dispatcher. Ruby, C++, Elixir, Erlang, Lua, PHP,
Fortran, C, and the agent-capable SDKs also reach 20/20; all sixteen now include
the HITL decision scenario.

## Limits

- Twenty selected scenarios, not full agent or contract parity.
- Go and Python use scenario-level tests; TypeScript uses `node --test` name
  filters; some Java self-tests cover more than one scenario.
- All sixteen wired languages pass all twenty scenarios in the source. COBOL
  reaches 20/20 through its native suite; its parallel-tools case delegates
  concurrency to a caller-provided batch dispatcher, so the native test verifies
  the batch limit and ordered results rather than OS threads. Ruby also reaches
  20/20 through native threads and its native suite.
  C++ reaches 20/20 through `std::async` parallel tools and its native suite.
  Elixir reaches 20/20 through `Task.async` parallel tools and its native suite.
  Erlang reaches 20/20 through spawned-process parallel tools and its native
  suite. Lua reaches 20/20 through caller-provided cooperative batch tools and
  its native suite. PHP reaches 20/20 through Fibers in `batchToolInvoker` and
  its native suite. Fortran reaches 20/20 through a caller-provided parallel
  batch callback and its native suite. This is suite coverage, not
  scenario-isolated assertions.
- The parallel scenario uses deterministic barriers; it is not a throughput or
  stress test. SSE tests use local fixtures, not a provider.
- No provider, model, network, sandbox, HITL, checkpoint persistence, or
  effect-recovery scenario.
- A passing report is not a security review or production certification.
