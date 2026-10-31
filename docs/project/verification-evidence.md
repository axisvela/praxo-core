# Verification Evidence

This page indexes the verification claims PRAXO-CORE can support today. It is a
public summary, not a production certificate, penetration test, or claim that
every implementation and deployment inherits the same result. Raw run records
and full environment logs remain in restricted internal storage; this page
records the claim level, result, and remaining limits.

See the [test evidence standard](../contributing/test-evidence.md) for the
required environment, configuration, procedure, data, result, and findings
record.

## Claim Levels

| Level | Meaning |
| --- | --- |
| Contract/unit | Deterministic repository tests, fakes, vectors, or API snapshots |
| Local integration | Real local binaries and databases on loopback, with disposable state |
| Independent/production | Reproduced by an independent party or observed in a deployed environment |

Current public evidence does not establish the third level unless a row says so.
A source tag, `complete` matrix label, or passing vector suite is not production
evidence.

## Current Evidence

| Area | Verified | Level | Limits |
| --- | --- | --- | --- |
| Go Core | Tests, vet, build, API snapshot, race, fuzz and module-security CI; current main and release workflow checks; published `v2.5.2` installed from a clean external module without `replace` | Contract/unit + CI + local integration | JSON Schema and plugin manifest fuzz runs have hit a 10s deadline and passed on rerun; slow-input risk remains under investigation; consumer install covers one platform and a minimal agent |
| Cross-language conformance | Python, TypeScript, Java, Rust, Fortran, and COBOL compatibility lab runs deterministic vector, API snapshot/signature, and parity checks; Linux CI and local runs are recorded | Contract/unit + CI | Six languages only; COBOL was verified locally with GnuCOBOL and on Linux CI; no provider, HITL, checkpoint, sandbox, or production evidence; one platform and toolchain set per run; non-author reproduction pending |
| Python published package | `praxo-core==0.2.3` installed from PyPI into a clean venv; a minimal agent invoked a tool, returned the final answer, and reported version `0.2.3` | Local install smoke | One platform; same-machine clean venv, not an independent or non-author consumer; no provider or production evidence |
| TypeScript published package | `@axisvela/praxo-core@0.1.3` installed from npm into a clean temporary project; the package reported version `0.1.3`, exported `Agent` and `Registry`, and reported `SPEC_VERSION` `0.2.0` | Local install smoke | One platform; same-machine temporary project, not an independent or non-author consumer; import smoke only, no provider or production evidence |
| Rust published crate | `praxo-core==0.1.4` installed from crates.io into a clean temporary project; the program reported `SDK_VERSION` `0.1.4` and `SPEC_VERSION` `0.2.0` | Local install smoke | One platform; same-machine temporary project, not an independent or non-author consumer; version and import smoke only, no provider or production evidence |
| Dart published package | `praxo_core==0.1.1` installed from pub.dev into a clean project; the program imported `package:praxo_core/praxo_core.dart` and returned `hello` from a minimal agent | Local install smoke | One platform; same-machine project, not an independent or non-author consumer; minimal agent only, no provider or production evidence |
| Ruby published gem | `praxo-core==0.1.0` installed from RubyGems into a clean temporary directory; the program required `praxo` and returned `hello` from a minimal agent | Local install smoke | One platform; same-machine temporary directory, not an independent or non-author consumer; minimal agent only, no provider or production evidence |
| C# published package | `Praxo.Core==0.1.2` built, tested, packed, and pushed to NuGet by GitHub Actions Trusted Publishing | CI + registry | No local .NET SDK or consumer install smoke; one package version; no provider or production evidence |
| Elixir published package | `praxo_core==0.1.1` installed from Hex into a clean Mix project; the project reported version `0.1.1` and loaded `Praxo.Agent` | Local install smoke | One platform; same-machine project, not an independent or non-author consumer; package-only release, HexDocs not published; no provider or production evidence |
| Erlang published package | `praxo_core_erlang==0.1.1` fetched and compiled by a clean rebar3 project; the project loaded `praxo_agent` from the package | Local install smoke | One platform; same-machine project, not an independent or non-author consumer; no provider or production evidence |
| D published package | `praxo-core==0.1.0` fetched from DUB/code.dlang.org with `dub fetch praxo-core` | Registry metadata + fetch | No compile or independent consumer smoke; one package version; no provider or production evidence |
| Java published package | `com.axisvela:praxo-core:0.3.0` published to Maven Central with sources, javadoc, and GPG signatures | Local release deploy + Central validation | Local Maven deploy behind a proxy; no independent consumer install smoke; no provider or production evidence |
| Cross-language agent behavior | Go, Python, TypeScript, and Java run nineteen authorization, lifecycle, cancellation, validation, call-limit, parallel-tool, run-isolation, PII, checkpoint, capacity, SSE-truncation, and stream-failure scenarios; Rust has selected scenario tests; Fortran/COBOL/Ruby/Elixir/Erlang/C++/PHP/C# use native-suite coverage for selected rows; Linux CI and local reports are recorded | Scenario tests + CI | Core coverage is four languages and nineteen scenarios; selected extended-language rows use suite coverage; some Java group self-tests and native suites do not isolate failures to a scenario; not a throughput/stress test; not full feature parity, provider, HITL, sandbox, or production evidence |
| Governed workspace | Policy-required configuration, final-argument authorization, single-use approvals, post-approval edits, queued revocation, fail-closed dependency errors | Contract/unit | Example-level contract; not a Core profile, authenticated identity service, or durable approval store |
| Context trust | Memory, skill, tool-result and summary source separation; digest-bound approved skills; text restore; late System injection rejection | Contract/unit | Opt-in example path; not a general prompt-injection filter, source authenticator, or durable lineage proof |
| Containment | Windows path/process/WASM controls; Linux path and symlink controls in a verbose CI job; local VFS operations use `os.Root` after policy checks | Contract/unit + CI | Windows symlink cases skipped without privilege; policy decisions remain check-then-use, Linux cgroup v2, WASM fuel, and independent review remain open |
| Workspace adapters | Shared conformance and fake-provider tests for E2B, Daytona, OpenSandbox, CubeSandbox | Contract/unit | All live provider tests skipped without credentials; no contract promotion |
| OpenTelemetry | Runnable in-memory example emits `run.started`, `tool.call`, `run.completed`; allowlist excludes tool arguments/results | Example + unit | No collector, OTLP backend, sampling, retention, or production telemetry verification |
| A2A interoperability | Google ADK consumes published Core `v2.5.1` A2A with no local Core replacement; success, denial, failure, timeout, authentication, TLS, cross-origin, and concurrent consumer fixtures | Local integration | Loopback deterministic fixture, not a deployed peer or production load test |
| Agent IAM contracts | Direct and gateway-shaped Agent IAM examples against contract fakes; credential time-window, key, signature, and subject checks | Contract/unit | NOMIVELA/EIDOVELA/AEGIVELA responses are fakes; the demo has no proof replay cache or body-bound gateway assertion |
| Integration recovery | Real local Symbivela, Ontovela, Rheovela, Orchadyn, Praxovela, LIMENORA, and integration-domain services; 8 steps, 5 products, 4 gates, 13 evidence artifacts, 11/11 report checks; preserve/verify denials and silent-rerun rejection | Local integration | Disposable local databases and fixed IDs; no production, network partition, concurrent load, independent reproduction, or deployment verification |
| Product effect ledgers | RHEOVELA effect/durable/crash tests and PRAXOVELA tenant-scoped effect-ledger tests, including in-memory/SQLite lifecycle and reconciliation | Contract/unit (product repositories) | In-process SQLite/temp files; not a live PostgreSQL cluster or a cross-service transaction |

## Public Evidence Links

- [Compatibility lab](../languages/compatibility-lab.md) and the [CI compatibility job](https://github.com/axisvela/praxo-core/actions/runs/41000572198/job/123883752839)
- [Behavior lab](../languages/behavior-lab.md) and the [CI behavior job](https://github.com/axisvela/praxo-core/actions/runs/41191022045/job/124507663977)
- [praxo-core 0.2.3 on PyPI](https://pypi.org/project/praxo-core/0.2.3/)
- [@axisvela/praxo-core 0.1.3 on npm](https://www.npmjs.com/package/@axisvela/praxo-core/v/0.1.3)
- [praxo-core 0.1.4 on crates.io](https://crates.io/crates/praxo-core/0.1.4)
- [praxo_core 0.1.1 on pub.dev](https://pub.dev/packages/praxo_core)
- [praxo-core 0.1.0 on RubyGems](https://rubygems.org/gems/praxo-core/versions/0.1.0)
- [praxo-core 0.1.0-1 on LuaRocks](https://luarocks.org/modules/hanhhuiwen/praxo-core)
- [Praxo.Core 0.1.2 on NuGet](https://www.nuget.org/packages/Praxo.Core/0.1.2)
- [praxo_core 0.1.1 on Hex](https://hex.pm/packages/praxo_core/0.1.1)
- [praxo_core_erlang 0.1.1 on Hex](https://hex.pm/packages/praxo_core_erlang/0.1.1)
- [praxo-core 0.1.0 on DUB](https://code.dlang.org/packages/praxo-core)
- [com.axisvela:praxo-core 0.3.0 on Maven Central](https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.3.0/)
- [Governed workspace example](https://github.com/axisvela/praxo-core/tree/main/examples/governed-workspace)
- [Governed execution design](../reference/governed-execution.md)
- [OpenTelemetry runnable example](https://github.com/axisvela/praxo-core/tree/main/adapters/otel/example)
- [A2A interoperability example](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-adk-order-cancellation)
- [Agent IAM examples](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-agent-iam)
- [Integration recovery demo](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/integration-recovery-local)
- [Workspace adapter directory](https://github.com/axisvela/praxo-core/tree/main/adapters/workspace)
- [Containment assessment](../security/containment.md)
- [RHEOVELA](https://github.com/axisvela/rheovela) and [PRAXOVELA](https://github.com/axisvela/praxovela) repositories

## Not Claimed

- Production readiness, deployed SLOs, or capacity under load.
- Independent security review, penetration testing, or compliance certification.
- Generic exactly-once execution or a cross-service transaction.
- Live verification of external workspace providers.
- Windows symlink containment when the test host cannot create symlinks.
- Test results for a different commit, tag, binary, or dependency resolution.
- Package-registry availability inferred from a source tag.

## Reporting A Gap

If a claim cannot be reproduced, open an issue with the commit, platform,
commands, inputs, expected result, observed result, and whether the mismatch is a
test defect or a behavior defect. Do not replace a failed record with a later
successful retry; keep both.
