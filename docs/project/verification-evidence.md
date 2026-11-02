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
| Python published package | PyPI `praxo-core==0.3.0` is published from source tag `python/v0.3.0`. The recorded clean-venv install and minimal-agent smoke covers `0.2.4`, not `0.3.0` | Registry publication + historical local install smoke | Registry `0.3.0` smoke was not rerun; one platform; same-machine clean venv, not an independent or non-author consumer; no provider or production evidence |
| TypeScript published package | npm `@axisvela/praxo-core@0.2.0` is staged from source tag `typescript/v0.2.0`; the recorded clean temporary-project install smoke covers `0.1.5` | Registry staging + historical local install smoke | `0.2.0` is staged, not verified as a public install; smoke was not rerun; one platform; not an independent consumer; no provider or production evidence |
| Rust published crate | crates.io `praxo-core==0.1.4` is installed from a clean temporary project and reports `SDK_VERSION` `0.1.4`; source tag `rust/v0.3.0` is newer than the crate | Registry install smoke + source release | The registry smoke covers `0.1.4`, not `0.3.0`; one platform; not an independent consumer; no provider or production evidence |
| Dart published package | `praxo_core==0.1.1` installed from pub.dev into a clean project; the program imported `package:praxo_core/praxo_core.dart` and returned `hello` from a minimal agent | Local install smoke | One platform; same-machine project, not an independent or non-author consumer; minimal agent only, no provider or production evidence |
| Ruby published gem | RubyGems `praxo-core==0.3.0` and `0.2.0` are published; the recorded clean temporary-directory smoke covers `0.1.0` | Registry publication + historical local install smoke | Registry `0.3.0` smoke was not rerun; one platform; not an independent consumer; no provider or production evidence |
| Lua published rock | LuaRocks `praxo-core==0.3.0-1` and `0.2.0-1` are published; a local rock build and module load passed | Registry publication + local build smoke | Registry install smoke is pending; one platform; not an independent consumer; no provider or production evidence |
| PHP published package | Packagist split tags `v0.3.0` and `v0.2.0` are published from `axisvela/praxo-core-php` | Registry publication | No Composer install smoke is recorded; one platform; not an independent consumer; no provider or production evidence |
| C# published package | `Praxo.Core==0.3.0` was built, tested, packed, and pushed to NuGet by GitHub Actions Trusted Publishing from source tag `csharp/v0.3.0` | CI + registry | No local .NET SDK or consumer install smoke; one package version; no provider or production evidence |
| Elixir published package | Hex `praxo_core==0.3.0` and backfilled `0.2.0` are published; source tag `elixir/v0.4.0` is newer. The historical `0.1.1` row was installed from Hex into a clean Mix project | Registry metadata + historical local install smoke | Consumer install smoke was not rerun for `0.3.0`/`0.2.0`; HexDocs are not published; one platform; no independent consumer; no provider or production evidence |
| Erlang published package | Hex `praxo_core_erlang==0.3.1` and backfilled `0.2.0` are published; source tag `erlang/v0.4.0` is newer. The historical `0.1.1` row was fetched by a clean rebar3 project | Registry metadata + historical local install smoke | Consumer install smoke was not rerun for `0.3.1`/`0.2.0`; one platform; no independent consumer; no provider or production evidence |
| D published package | `praxo-core==0.1.0` fetched from DUB/code.dlang.org with `dub fetch praxo-core` | Registry metadata + fetch | No compile or independent consumer smoke; one package version; no provider or production evidence |
| Java published package | Maven Central `com.axisvela:praxo-core:0.3.0` is published with sources, javadoc, and GPG signatures; source tag `java/v0.4.0` is not published | Local release deploy + Central validation | No consumer install smoke; `0.4.0` registry publication is pending; one platform; no provider or production evidence |
| Cross-language agent behavior | All sixteen wired languages pass all twenty authorization, lifecycle, cancellation, validation, call-limit, parallel-tool, run-isolation, PII, checkpoint, capacity, SSE-truncation, stream-failure, and HITL-decision scenarios in the source. Agent-capable languages use scenario-level or self-test coverage; extended languages use native-suite coverage. Parallel tools for COBOL, Lua, PHP, and Fortran are delegated to caller-provided batch callbacks. Other implementations are optional. The clean-tree CI report at `b6218e5` records 320 passed, 0 unsupported, and no failures | Scenario tests + CI | All sixteen wired languages reach 20/20 in the source; some extended rows are suite-level and a failure is not isolated to a scenario; the earlier local run at `4ffd83b` is historical, not current evidence; not a throughput/stress test, not full feature parity, provider, sandbox, or production evidence |
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
- [Behavior lab](../languages/behavior-lab.md) and the [current CI behavior job](https://github.com/axisvela/praxo-core/actions/runs/41407891314/job/125153985339)
Registry links name the current published version; the consumer-smoke rows above
name the version that was actually installed.

- [praxo-core 0.3.0 on PyPI](https://pypi.org/project/praxo-core/0.3.0/)
- [@axisvela/praxo-core 0.1.5 on npm](https://www.npmjs.com/package/@axisvela/praxo-core/v/0.1.5)
  (the `0.2.0` package is staged, not yet a public install claim)
- [praxo-core 0.1.4 on crates.io](https://crates.io/crates/praxo-core/0.1.4)
- [praxo_core 0.1.1 on pub.dev](https://pub.dev/packages/praxo_core)
- [praxo-core 0.3.0 on RubyGems](https://rubygems.org/gems/praxo-core/versions/0.3.0)
- [praxo-core 0.3.0-1 on LuaRocks](https://luarocks.org/modules/hanhhuiwen/praxo-core)
- [Praxo.Core 0.3.0 on NuGet](https://www.nuget.org/packages/Praxo.Core/0.3.0)
- [praxo_core 0.3.0 on Hex](https://hex.pm/packages/praxo_core/0.3.0)
- [praxo_core_erlang 0.3.1 on Hex](https://hex.pm/packages/praxo_core_erlang/0.3.1)
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
