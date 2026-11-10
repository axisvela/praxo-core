# Verification Evidence

**Status:** public evidence summary, 2026-11-09.

This page indexes the verification claims PRAXO-CORE can support today. It is a
public summary, not a production certificate, penetration test, or claim that
every implementation and deployment inherits the same result. Raw run records
and full environment logs remain in restricted internal storage; this page
records the claim level, result, and remaining limits.

For the EC-01 through EC-14 mapping across Core and its product consumers, see
the [Execution Correctness Evidence Index](execution-correctness-evidence.md).

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
| Go Core | Tests, vet, build, API snapshot, race, fuzz and module-security CI; current main and release workflow checks; `v2.7.0` is the current release (2026-11-09); the `current-go-consumer` CI job installs the recommended version from the registry and runs deterministic allow/deny checks; `v2.6.0` resolves from the public module proxy in a clean external module; a separately recorded clean external-module install and minimal-agent smoke cover `v2.5.2` | Contract/unit + CI + local integration | JSON Schema and plugin manifest fuzz runs have hit a 10s deadline and passed on rerun; slow-input risk remains under investigation; a non-CI clean install smoke for `v2.7.0` was not rerun; the recorded install covers one platform and a minimal agent |
| Go long-running recipe | File-backed store with idempotent submit, response loss, child-process restart, separate verifier, fencing with lease expiry/renewal/revocation, deterministic pre/post-rename fault injection, fail-closed corrupt state, a standalone service binary with health/readiness, basic metrics, example Prometheus scrape/retention/alert configs (config-validated; no live collector), environment-based configuration, file-based token/secret rotation (issuance external), and graceful shutdown, configurable file/SQLite/Postgres lease backends with reload-modify-save (SQLite verified; Postgres gated by `PRAXO_POSTGRES_DSN` and unverified here), process-level crash before and after the rename boundary, a gated 100-submission load/fault test with a fresh-checkout reproduction script, a separate verifier binary with its own token/secret, and a no-lease concurrent-writer boundary test | Contract/unit + local integration | L4 application recipe; no production deployment, collector/retention/alerting, OS-level power loss, production lease coordination, trusted clock, or exactly-once |
| Cross-language conformance | Python, TypeScript, Java, Rust, Fortran, and COBOL compatibility lab runs deterministic vector, API snapshot/signature, and parity checks; Linux CI and local runs are recorded | Contract/unit + CI | Six languages only; COBOL was verified locally with GnuCOBOL and on Linux CI; no provider, HITL, checkpoint, sandbox, or production evidence; one platform and toolchain set per run; non-author reproduction pending |
| Python published package | PyPI `praxo-core==0.4.1` is published from source tag `python/v0.4.1`. The release workflow built and smoke-tested the wheel and sdist before publication; the package includes Harmovela and MCP adapters. Historical local checks cover `0.3.2` and `0.2.4` | Registry publication + release-workflow artifact smoke + post-publication consumer check | One platform/toolchain; same-machine clean venv, not an independent or non-author consumer; no provider or production evidence |
| Python published-package upgrade | `scripts/test_python_upgrade.py` installs PyPI `0.2.4`, runs the unchanged consumer fixture and governed compatibility checks, upgrades to `0.3.0`, and reruns the full starter/governed suite | CI + registry upgrade | One version pair; does not prove arbitrary upgrade paths, independent consumers, or production behavior |
| TypeScript published package | npm `@axisvela/praxo-core@0.2.2` is published from source tag `typescript/v0.2.2` and is the latest version. The release workflow built and consumed the package tarball; `0.2.2` README includes absolute registry/coding-agent links; the post-publication consumer script installed `0.2.2` from npm in a clean temporary project and passed starter/governed checks locally. The historical smoke covers `0.1.5` | Registry publication + release-workflow tarball smoke + post-publication consumer check | One platform/toolchain; not an independent consumer; no provider or production evidence |
| TypeScript published-package upgrade | `scripts/test_typescript_upgrade.py` installs npm `0.1.5`, runs the unchanged consumer and governed compatibility checks, upgrades to `0.2.0`, and reruns the full starter/governed suite | CI + registry upgrade | One version pair; does not prove arbitrary upgrade paths, independent consumers, or production behavior |
| Rust published crate | crates.io `praxo-core==0.4.0` is published from source tag `rust/v0.4.0`; the recorded clean temporary-project install smoke covers `0.1.4` | Registry publication + historical local install smoke | The registry smoke covers `0.1.4`, not `0.4.0`; one platform; not an independent consumer; no provider or production evidence |
| Dart published package | `praxo_core==0.1.1` installed from pub.dev into a clean project; the program imported `package:praxo_core/praxo_core.dart` and returned `hello` from a minimal agent | Local install smoke | One platform; same-machine project, not an independent or non-author consumer; minimal agent only, no provider or production evidence |
| Ruby published gem | RubyGems `praxo-core==0.4.1` is published from source tag `ruby/v0.4.1`; the gem source is `axisvela/praxo-core-ruby`. `0.4.0`, `0.3.0`, and `0.2.0` remain available. The recorded clean temporary-directory smoke covers `0.1.0` | Registry publication + historical local install smoke | Registry `0.4.1` smoke was not rerun; one platform; not an independent consumer; no provider or production evidence |
| Lua published rock | LuaRocks `praxo-core==0.4.1-1` is published through `.github/workflows/lua-release.yml`, which builds the source rock, installs it in a clean tree, and runs the installed smoke. The published `0.4.1-1` rock was also installed into a clean temporary tree and the consumer starter passed outside the repository; `0.4.0-1`, `0.3.0-1`, and `0.2.0-1` remain available | Registry publication + CI install smoke + local consumer install | One platform; not an independent consumer; no provider or production evidence |
| PHP published package | Packagist publishes `axisvela/praxo-core==0.4.0` from split tag `v0.4.0`; `v0.3.0` and `v0.2.0` remain available | Registry publication | No Composer install smoke is recorded; one platform; not an independent consumer; no provider or production evidence |
| C# published package | `Praxo.Core==0.3.0` was built, tested, packed, and pushed to NuGet by GitHub Actions Trusted Publishing from source tag `csharp/v0.3.0` | CI + registry | No local .NET SDK or consumer install smoke; one package version; no provider or production evidence |
| MATLAB File Exchange package | `PRAXO-CORE 0.2.1` is published at File Exchange entry `185166` with the generated toolbox image and MIT license | Registry publication | MATLAB runtime verification and consumer install smoke are not recorded; Octave verification does not establish MATLAB behavior |
| PowerShell Core | PowerShell Gallery `praxo-core-ps==0.2.0` is published from the versioned module. CI builds the C# Core, runs the C# conformance and behavior suites, wrapper smoke tests, and the PowerShell API snapshot | Registry + contract/unit + CI | Shared C# runtime, not a separate agent loop; behavior evidence is inherited from the C# Core; no consumer install smoke or provider evidence |
| Elixir published package | Hex `praxo_core==0.5.1` is published from source tag `elixir/v0.5.1` with HexDocs `0.5.1`; `0.5.0` failed before publication; `0.4.1`, `0.4.0`, `0.3.0`, and `0.2.0` remain available. `0.4.1` resolved in a clean Mix project and the consumer starter passed locally; `0.5.1` install smoke was not rerun | Registry publication + historical local consumer install | One platform; not an independent consumer; no provider or production evidence |
| Erlang published package | Hex `praxo_core_erlang==0.4.0` is published from source tag `erlang/v0.4.0`; `0.3.1` and `0.2.0` remain available. The historical `0.1.1` row was fetched by a clean rebar3 project | Registry publication + historical local install smoke | Consumer install smoke was not rerun for `0.4.0`; one platform; no independent consumer; no provider or production evidence |
| D published package | `praxo-core==0.1.0` fetched from DUB/code.dlang.org with `dub fetch praxo-core` | Registry metadata + fetch | No compile or independent consumer smoke; one package version; no provider or production evidence |
| Java published package | Maven Central `com.axisvela:praxo-core:0.4.1` is published with sources, javadoc, and GPG signatures. Central validated the deployment before publication; the post-publication consumer script resolved `0.4.1` from Maven Central and passed starter/governed checks locally | Registry publication + Central validation + post-publication consumer check | One deployment/platform/toolchain; not an independent consumer; no provider or production evidence |
| Java published-package upgrade | `scripts/test_java_upgrade.py` resolves Maven Central `0.3.0`, runs the unchanged consumer and governed compatibility checks, upgrades to `0.4.0`, and reruns the full starter/governed suite | CI + registry upgrade | One version pair; does not prove arbitrary upgrade paths, independent consumers, or production behavior |
| Extended consumer starters (Ruby/PHP/Elixir/Lua) | Deterministic allow/deny starters in `examples/consumer-ruby`, `consumer-php`, `consumer-elixir`, and `consumer-lua` pass in source-mode locally. After configuring the local proxy CA, RubyGems `praxo-core==0.4.1`, Hex `praxo_core==0.4.1`, and LuaRocks `praxo-core==0.4.1-1` installs were run outside the repository and the starters passed. Composer installed published `axisvela/praxo-core==0.4.1` and the starter passed without a bridge; the package declares `autoload.files` and ships `api/0.4.1.txt` | Contract/unit + local registry installs | Extended-language starters; no governed negative matrix; one platform; no provider, identity, isolation, or production evidence |
| Cross-language agent behavior | All sixteen wired languages pass all twenty authorization, lifecycle, cancellation, validation, call-limit, parallel-tool, run-isolation, PII, checkpoint, capacity, SSE-truncation, stream-failure, and HITL-decision scenarios in the source. Agent-capable languages use scenario-level or self-test coverage; extended languages use native-suite coverage. Parallel tools for COBOL, Lua, PHP, and Fortran are delegated to caller-provided batch callbacks. Other implementations are optional. The clean-tree CI report at `b6218e5` records 320 passed, 0 unsupported, and no failures | Scenario tests + CI | All sixteen wired languages reach 20/20 in the source; some extended rows are suite-level and a failure is not isolated to a scenario; the earlier local run at `4ffd83b` is historical, not current evidence; not a throughput/stress test, not full feature parity, provider, sandbox, or production evidence |
| Governed workspace | Policy-required configuration, final-argument authorization, single-use approvals, post-approval edits, queued revocation, fail-closed dependency errors | Contract/unit | Example-level contract; not a Core profile, authenticated identity service, or durable approval store |
| Context trust | Memory, skill, tool-result and summary source separation; digest-bound approved skills; text restore; late System injection rejection | Contract/unit | Opt-in example path; not a general prompt-injection filter, source authenticator, or durable lineage proof |
| Containment | Windows path/process/WASM controls; Linux path and symlink controls in a verbose CI job; local VFS operations use `os.Root` after policy checks | Contract/unit + CI | Windows symlink cases skipped without privilege; policy decisions remain check-then-use; Linux cgroup v2 and independent review remain open; the pinned wazero API does not expose per-instruction fuel metering, so CPU bounding is deadline/cancellation-based rather than fuel-based |
| Workspace adapters | Shared conformance and fake-provider tests for E2B, Daytona, OpenSandbox, CubeSandbox | Contract/unit | All live provider tests skipped without credentials; no contract promotion |
| OpenTelemetry | Runnable in-memory example emits `run.started`, `tool.call`, `run.completed`; allowlist excludes tool arguments/results | Example + unit | No collector, OTLP backend, sampling, retention, or production telemetry verification |
| A2A interoperability | Google ADK consumes published Core `v2.5.1` A2A with no local Core replacement; success, denial, failure, timeout, authentication, TLS, cross-origin, and concurrent consumer fixtures | Local integration | Loopback deterministic fixture, not a deployed peer or production load test |
| Agent IAM contracts | Direct and gateway-shaped Agent IAM examples against contract fakes; credential time-window, key, signature, and subject checks | Contract/unit | NOMIVELA/EIDOVELA/AEGIVELA responses are fakes; the demo has no proof replay cache or body-bound gateway assertion |
| Coding-agent skill discovery | Claude Code `2.1.196` installed `agent-skills/praxo-integration` as a temporary skills-directory plugin; `plugin list` reported it loaded and `plugin details` listed the skill component (2026-11-08, `bdd36d7`; issue #15) | Local structural check | One tool and platform; that CLI did not run a model task or published-package integration; not adoption evidence |
| Coding-agent skill task | opencode `1.18.18` discovered `agent-skills/praxo-integration` from a project-local `.opencode/skills/praxo-integration/SKILL.md`, then completed a deterministic Python task using published PyPI `praxo-core==0.3.2` with explicit tool scope and allow/deny tests (3/3 passed; model `deepseek/deepseek-flash`; Python 3.14.6; 2026-11-08, `7004a08`) | Local structural check + local task execution | One tool, one task, one platform; first-pass success without repair; no governed negative matrix, live model, authentic identity, durable approvals, effect commit, exactly-once, or isolation evidence; not adoption evidence |
| AKROVELA embedded PRAXO-CORE | AKROVELA embeds published PRAXO-CORE `v2.6.0` through a product-owned adapter: exact-operation tools, mandatory policy, bounded budgets, redacted telemetry, and a PostgreSQL Run/reconciliation journal; a deterministic slice with a test model and local PostgreSQL is recorded as locally verified in the AKROVELA repository (`b5e5da9`, 2026-11-08) | Local integration (product repository) | No production model provider, Agent HTTP endpoint, observations, independent verifier, ROS 2 execution, hardware effect, live KINETOVELA integration, or E1-E8 pilot run; product-owned evidence, not Core acceptance |
| Integration recovery | Real local Symbivela, Ontovela, Rheovela, Orchadyn, Praxovela, LIMENORA, and integration-domain services; 8 steps, 5 products, 4 gates, 13 evidence artifacts, 11/11 report checks; preserve/verify denials and silent-rerun rejection | Local integration | Disposable local databases and fixed IDs; no production, network partition, concurrent load, independent reproduction, or deployment verification |
| Product effect ledgers | RHEOVELA effect/durable/crash tests and PRAXOVELA tenant-scoped effect-ledger tests, including in-memory/SQLite lifecycle and reconciliation | Contract/unit (product repositories) | In-process SQLite/temp files; not a live PostgreSQL cluster or a cross-service transaction |

## Public Evidence Links

- [Compatibility lab](../languages/compatibility-lab.md) and the [recorded CI compatibility job](https://github.com/axisvela/praxo-core/actions/runs/41000572198/job/123883752839)
- [Behavior lab](../languages/behavior-lab.md) and the [CI behavior job at `b6218e5`](https://github.com/axisvela/praxo-core/actions/runs/41407891314/job/125153985339)

CI links above point to recorded runs. They are evidence for the revision named
by the run, not proof that the current `main` passes.
Registry links name the current published version; the consumer-smoke rows above
name the version that was actually installed.

- [praxo-core 0.3.2 on PyPI](https://pypi.org/project/praxo-core/0.3.2/)
- [@axisvela/praxo-core 0.2.2 on npm](https://www.npmjs.com/package/@axisvela/praxo-core/v/0.2.2)
- [praxo-core 0.4.0 on crates.io](https://crates.io/crates/praxo-core/0.4.0)
- [praxo_core 0.1.1 on pub.dev](https://pub.dev/packages/praxo_core)
- [praxo-core 0.4.0 on RubyGems](https://rubygems.org/gems/praxo-core/versions/0.4.0)
- [praxo-core 0.4.1-1 on LuaRocks](https://luarocks.org/modules/hanhhuiwen/praxo-core)
- [praxo_core 0.5.1 on Hex](https://hex.pm/packages/praxo_core/0.5.1)
- [Praxo.Core 0.3.0 on NuGet](https://www.nuget.org/packages/Praxo.Core/0.3.0)
- [axisvela/praxo-core 0.4.0 on Packagist](https://packagist.org/packages/axisvela/praxo-core)
- [praxo_core 0.4.0 on Hex](https://hex.pm/packages/praxo_core/0.4.0)
- [praxo_core_erlang 0.4.0 on Hex](https://hex.pm/packages/praxo_core_erlang/0.4.0)
- [praxo-core 0.1.0 on DUB](https://code.dlang.org/packages/praxo-core)
- [com.axisvela:praxo-core 0.4.1 on Maven Central](https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.4.1/)
- [Governed workspace example](https://github.com/axisvela/praxo-core/tree/main/examples/governed-workspace)
- [Governed execution design](../reference/governed-execution.md)
- [OpenTelemetry runnable example](https://github.com/axisvela/praxo-core/tree/main/adapters/otel/example)
- [A2A interoperability example](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-adk-order-cancellation)
- [Agent IAM examples](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-agent-iam)
- [Integration recovery demo](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/integration-recovery-local)
- [Workspace adapter directory](https://github.com/axisvela/praxo-core/tree/main/adapters/workspace)
- [Containment assessment](../security/containment.md)
- [RHEOVELA](https://github.com/axisvela/rheovela), [PRAXOVELA](https://github.com/axisvela/praxovela), and [AKROVELA](https://github.com/axisvela/akrovela) repositories

## Not Claimed

- Production readiness, deployed SLOs, or capacity under load.
- Independent security review, penetration testing, or compliance certification.
- Generic exactly-once execution or a cross-service transaction.
- Live verification of external workspace providers.
- Live Postgres verification: a local attempt on 2026-11-09 with PostgreSQL 18.1
  on Windows did not complete (server exited with `0xC0000142`); the gated
  Postgres tests require `PRAXO_POSTGRES_DSN` and a healthy server.
- Windows symlink containment when the test host cannot create symlinks.
- Test results for a different commit, tag, binary, or dependency resolution.
- Package-registry availability inferred from a source tag.

## Reporting A Gap

If a claim cannot be reproduced, open an issue with the commit, platform,
commands, inputs, expected result, observed result, and whether the mismatch is a
test defect or a behavior defect. Do not replace a failed record with a later
successful retry; keep both.
