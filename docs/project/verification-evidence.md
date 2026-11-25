# Verification Evidence

**Status:** public evidence summary, updated 2026-11-25. Earlier records retain
their original revisions and limits.

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

### Tutorial CI Follow-up (2026-11-25)

The `ci-tutorials` workflow [45537631891](https://github.com/axisvela/praxo-core/actions/runs/45537631891)
passed at `dfdfd55873368c921fed29ad201d20986a935866`. Its jobs cover the scenario
catalog, new language slices, the nine runtime-aligned paths, and shared-service
integrations. Java, Swift and Objective-C tutorial runtime jobs passed on their
configured hosted runners; the native compiled-language jobs also passed. This
supersedes earlier pending-CI labels, not local Windows toolchain limitations.
MATLAB-named tutorial jobs use Octave; commercial Delphi is not verified by Free
Pascal. Consult the pinned workflow and individual jobs for exact commands and
platforms. This is deterministic fixture/CI evidence, not verification of every
SDK feature, later revisions, live models, full reference applications, or
independent consumers. Earlier failed runs remain failures at their revisions.

Separately, adapter workflow [45541181220](https://github.com/axisvela/praxo-core/actions/runs/45541181220)
passed at `71f78a7a`, including `adapters/otel` module-security after the
OpenTelemetry `1.47.0` update. Comprehensive workflow `45533451233` failed at
`d7916382` on that module-security job. The later adapter pass does not constitute
a full comprehensive-CI rerun at HEAD.

Evidence is grouped by area. Treat each row as scoped to the revision, artifact,
and date it names.

### Core, Execution, and Live Model

| Area | Verified | Level | Limits |
| --- | --- | --- | --- |
| Go Core | Tests, vet, build, API snapshot, race, fuzz and module-security CI; current main and release workflow checks; `v2.10.0` is the current release (2026-11-20); the `current-go-consumer` CI job installs the recommended version from the registry and runs deterministic allow/deny checks; `v2.6.0` resolves from the public module proxy in a clean external module; a separately recorded clean external-module install and minimal-agent smoke cover `v2.5.2` | Contract/unit + CI + local integration | JSON Schema and plugin manifest fuzz runs have hit a 10s deadline and passed on rerun; slow-input risk remains under investigation; the docs CI published-upgrade check moved an unchanged consumer from `v2.5.0` to `v2.10.0` and passed deterministic allow/deny checks; a direct pkg.go.dev page check for `v2.10.0` is not recorded here; the install evidence is still CI-driven, not an independent non-author consumer |
| Live-model Ollama cross-validation | Go `qwen3.5:4b`, TypeScript/Python `qwen2.5:0.5b`, C# `qwen2.5:0.5b`, and Rust `qwen2.5:0.5b` each completed a `get_time` tool-call path against local Ollama. Python used an injected `http.client` transport because standard `urllib` hangs in this environment. C# was run through the built DLL because the apphost/`dotnet run` path did not return in this shell; the run printed the current UTC time on 2026-11-22. Rust was built with `cargo build --offline` and run from the resulting binary; its model-generated time text was reported but is not a correctness claim | Local integration | One local endpoint/platform; the Python transport, C# DLL invocation, and Rust offline build are local workarounds, not the documented paths; model output quality and time-format correctness are not assessed; hosted endpoint, billed calls, and independent reproduction not tested |
| Go long-running recipe | File-backed store with idempotent submit, response loss, child-process restart, separate verifier, fencing with lease expiry/renewal/revocation, deterministic pre/post-rename fault injection, fail-closed corrupt state, a standalone service binary with health/readiness, basic metrics, example Prometheus scrape/retention/alert configs (config-validated; no live collector), environment-based configuration, file-based token/secret rotation (issuance external), and graceful shutdown, configurable file/SQLite/Postgres lease backends with reload-modify-save (SQLite verified; Postgres gated by `PRAXO_POSTGRES_DSN` and unverified here), process-level crash before and after the rename boundary, a gated 100-submission load/fault test with a fresh-checkout reproduction script, a separate verifier binary with its own token/secret, and a no-lease concurrent-writer boundary test | Contract/unit + local integration | L4 application recipe; no production deployment, collector/retention/alerting, OS-level power loss, production lease coordination, trusted clock, or exactly-once |
| Representative end-to-end chain | Go `examples/representative-chain`: real Ollama `qwen3.5:4b` -> MCP `record` tool -> final-argument policy -> governed child delegation -> OTel spans and loopback Harmovela events -> edited denial with zero effects. Recorded 2026-11-17: output `DONE`, effects parent=1/child=1, child calls=2, 10 spans, 10 events, denied effect 0 | Local integration | One local model/platform; in-memory MCP and loopback Harmovela; not remote or production; no independent reproduction, load, or fault test |
| Python representative chain | `language/python/examples/representative-chain`: deterministic parent/child -> MCP `record` tool -> final-argument policy -> governed delegation -> OTel/Harmovela in-memory transports -> edited denial with zero effects. Recorded 2026-11-17: output `DONE`, effects parent=1/child=1, child calls=2, 7 spans/events, denied effect 0 | Contract/unit | Deterministic models, in-memory MCP and sink transports; no live provider, remote service, identity, or production evidence; complements the Go real-model chain |
| TypeScript representative chain | `language/typescript/examples/representative-chain`: deterministic parent/child -> MCP `record` tool -> final-argument policy -> governed delegation -> OTel/Harmovela in-memory transports -> edited denial with zero effects. Recorded 2026-11-17: output `DONE`, effects parent=1/child=1, child calls=2, 7 spans/events, denied effect 0 | Contract/unit | Deterministic models, in-memory MCP and sink transports; no live provider, remote service, identity, or production evidence; complements the Go real-model chain |
| Cross-language representative chains | Go real-model chain plus deterministic chains for Python, TypeScript, Java, C#, Rust, R, C, C++, Fortran, COBOL, PHP, Ruby, Elixir, Erlang, Lua, Perl, V, Nim, Dart, Julia, D, OCaml, Haskell, Zig, the shared MATLAB/Octave implementation, Delphi / Free Pascal, Objective-C, Swift, and PowerShell. Each covers MCP-style record, final authorization, child delegation, OTel/Harmovela events, and a denied edit with zero effects. Recorded 2026-11-17 (Swift and PowerShell 2026-11-18): deterministic chains report `DONE`, effects parent=1/child=1, child calls=2, at least 3 event classes, denied effect 0; Perl/V/Nim/Dart/Julia/D/OCaml/Haskell/Zig/MATLAB-Octave/Delphi/Swift/PowerShell report 10 spans/events and Objective-C reports 7; MATLAB/Octave execution evidence is GNU Octave 11.3.0 only and native MATLAB remains unverified; Delphi evidence is Free Pascal 3.2.2 and commercial Delphi compatibility remains unverified; Objective-C evidence is clang/GNUstep and Apple Foundation remains unverified; Swift evidence is Swift 6.4.2 with direct `swiftc`/`lld` linking on Windows, while SwiftPM `swift build` and macOS runtime remain unverified locally; PowerShell evidence is PowerShell 7.7.0 on .NET 11 over the shared C# Core built for `net8.0`, not a separate PowerShell runtime implementation; C 17/17 and C++ 8/8 ctest; COBOL full suite includes the chain; Fortran direct 20 checks | Contract/unit + local integration | Deterministic models and in-memory/transport seams; no live provider or remote services; Fortran full gate blocked by local executable removal; no independent reproduction or production evidence |
| Cross-language conformance | Python, TypeScript, Java, Rust, Fortran, and COBOL compatibility lab runs deterministic vector, API snapshot/signature, and parity checks; Linux CI and local runs are recorded | Contract/unit + CI | Six languages only; COBOL was verified locally with GnuCOBOL and on Linux CI; no provider, HITL, checkpoint, sandbox, or production evidence; one platform and toolchain set per run; non-author reproduction pending |

### Packages, Identity Examples, and Consumer Runs

Shared order tutorial slice (2026-11-22): Core `3c2063f9` and synthetic backend
revision `fe85622b3445c41d53fbada8e0199c8f1b353ec5`. Local backend tests plus
Python/TypeScript clients passed four test methods (Python source mode,
TypeScript installed npm `0.9.0`). Java compilation and mock-backed Agent/Web
JUnit passed in Linux CI [45031868787](https://github.com/axisvela/praxo-core/actions/runs/45031868787).
The original backend repository was private: full three-language integration was skipped,
not passed. Earlier Core run `45031542641` failed during private repository
checkout before tests. The original backend CI did not start. These are maintainer teaching fixtures, not independent adoption,
live-provider, public-service, refund, or durable-transaction evidence.

Public backend follow-up (2026-11-22): the approved teaching subset is now MIT
source at [agent-tutorial-services](https://github.com/axisvela/agent-tutorial-services),
revision `8b7820edbf9150b5b8c90fe73368a1bba8854186`. Its standalone backend CI
[45032761254](https://github.com/axisvela/agent-tutorial-services/actions/runs/45032761254)
passed. Local backend plus Python/TypeScript checks passed again (four test
methods). The original demo repository remains private. The new Core full-client
gate pins the public commit and needs no private credentials; results are not
inferred from backend CI or from the earlier Java mock tests.

Full native-client integration passed in Core
[run 45033109188](https://github.com/axisvela/praxo-core/actions/runs/45033109188)
at `8b0593bb`, using backend `8b7820e`, Ubuntu 26.04, Python 3.12.16,
Node 24.22.3 and Temurin 21.0.13. The job installed PyPI `0.10.0`, npm `0.9.0`
and Maven Central `0.11.0`. All four unittest methods passed, including each
native client's successful draft, Agent denial, server-side tenant denial and
unavailable-store checks. Java mock/Web JUnit also passed separately. This is
loopback deterministic CLI integration, not a live model, a hosted business
service, Java Web-to-real-backend verification, or independent consumer evidence.

C# service-desk follow-up passed in Core
[run 45034303513](https://github.com/axisvela/praxo-core/actions/runs/45034303513)
at `ae953050`, backend `cd08b09` (2026-11-22). C# used NuGet `0.10.0` on .NET 8.
Standalone native/ASP.NET Core self-tests passed; all five backend unittest
methods passed, including four native CLI clients and a real C# Web-to-backend
path with authentication denial, draft creation/replay and unavailable-store
checks. This extends the C# scope beyond mock transports, not the Java Web
scope. Models are deterministic and credentials are public fixtures; no live
provider, production authentication, public hosting or independent adoption.

PowerShell Windows diagnostics tutorial (2026-11-22): local Windows PowerShell
7.7.0 ran four checks successfully using the shared C# Core Debug build in source
mode. Fixture mode performed two read-only tool calls; an out-of-scope service
was denied before reads (`reads=0`); simulated dependency failure exited nonzero
after one read; local mode read `Spooler` status and system-drive free space with
`source=local_machine`. The tutorial registers no mutating tools. Hosted Windows CI
[45036962205](https://github.com/axisvela/praxo-core/actions/runs/45036962205)
also passed at `5afe6e35`: it built C# Core Debug and ran all four source-mode
checks, including local service/disk reads. No Gallery install, live model,
remote host, repair, administrator operation, production monitoring or independent
adoption is verified.

Perl log-triage tutorial (2026-11-22): local Perl 5.40.3 in source mode passed
the success report, policy denial and simulated dependency failure. Success read
the fixed fixture once and reported two errors, one warning and two info lines
with an empty `mutating_actions` list; the out-of-scope log was denied before any
read (`reads=0`); simulated dependency failure exited nonzero after one read.
Linux CI [45038008192](https://github.com/axisvela/praxo-core/actions/runs/45038008192)
also passed at `3b5edcc7`. No arbitrary path, shell execution, alert delivery,
live model, production log pipeline or independent adoption is verified.

R data-quality tutorial (2026-11-22): local R 4.6.1 in source mode passed the
success report, policy denial and simulated dependency failure. The report
contained six rows, one missing amount, five complete rows, four regions, mean
amount 118 and max score 0.95, with an empty `mutating_actions` list; an
out-of-scope dataset was denied before any read (`reads=0`); simulated
dependency failure exited nonzero after one read. Linux CI
[45039622807](https://github.com/axisvela/praxo-core/actions/runs/45039622807)
also passed at `e89c9037`. No arbitrary file/SQL/shell, package installation,
live model, causal claim, production pipeline or independent adoption is verified.

COBOL batch-exception tutorial (2026-11-22): local GnuCOBOL 2.0.0 and Python 3.14
passed the tutorial wrapper and its three underlying scenarios. The reviewed
path produced advisory output while preserving batch output and exceptions; the
unavailable and timeout paths produced no advisory output and left both files
unchanged. This reuses the existing deterministic handoff fixture, not a second
bank model. Linux CI [45040372057](https://github.com/axisvela/praxo-core/actions/runs/45040372057)
also passed at `01d9b1ff`. No real posting, payment, durable queue, recovery
proof, live model or independent consumer evidence is claimed.

Julia experiment-comparison tutorial (2026-11-22): local Julia 1.13.2 in source
mode passed success, policy denial and simulated dependency failure. The report
contained five samples, baseline mean 0.74, candidate mean 0.784, delta 0.044,
winner `candidate` and an empty `mutating_actions` list; an out-of-scope dataset
was denied before any read (`reads=0`); simulated dependency failure exited
nonzero after one read. Linux CI
[45041423996](https://github.com/axisvela/praxo-core/actions/runs/45041423996)
also passed at `bbf12c42`. No arbitrary data, model-provided Julia execution,
package install, live model, causal claim, production platform or independent
adoption is verified.

Octave/MATLAB signal-trends tutorial (2026-11-22): local GNU Octave 11.3.0
passed success, policy denial and simulated dependency failure. The report
contained ten samples, mean 0.42, peak-to-peak 1, RMS about 0.53075, two
threshold anomalies and first anomaly index 4, with an empty `mutating_actions`
list; an out-of-scope dataset was denied before any tool call (`reads=0`);
simulated dependency failure returned `TOOL_ERROR` after one call. Linux CI
[45042266323](https://github.com/axisvela/praxo-core/actions/runs/45042266323)
also passed at `0664a194`. Native MATLAB, arbitrary file/code execution, device
control, live model, production signal pipeline and independent adoption are not
verified.

Python office-Q&A tutorial (2026-11-22): local Python 3.14 with Core source mode
passed success, policy denial and simulated index failure. The answer cited the
`handbook` fixture and contained the travel-approval sentence; an out-of-scope
scope was denied before any tool call (`reads=0`); simulated index failure failed
after one call. Linux CI
[45043537084](https://github.com/axisvela/praxo-core/actions/runs/45043537084)
also passed at `cfd850a6`. No arbitrary file/connector, email/calendar action,
live provider, production document store, public hosting or independent adoption
is verified.

TypeScript customer-support tutorial (2026-11-22): local Node 24 passed the SSE
success case with a `shipping` citation, missing-credential 401, simulated
dependency 503 before a stream start, and an out-of-scope order denied by Agent
policy before HTTP effects. The final reply said `order-100` was delayed. Linux
CI [45086046576](https://github.com/axisvela/praxo-core/actions/runs/45086046576)
also passed at `39558592`. No reply send, order change, refund, live provider,
public endpoint or independent adoption is verified.

Java wealth-review tutorial (2026-11-22): the tutorial main class and JUnit test
compiled locally with `javac` against the local Core classes. Local Maven/JVM
execution is blocked by the workstation launcher, so no local JUnit result is
claimed. The test is configured to cover draft-only success, `acct-200` policy
denial, portfolio dependency failure, and the Web health/401/200/503 boundary.
Linux CI [45088386879](https://github.com/axisvela/praxo-core/actions/runs/45088386879)
also passed at `827d47ca`; the first CI run exposed a fixture using `acct-100`
for the `acct-200` denial test, which was fixed before the passing run. No trade,
transfer, market data, production identity, live model, public hosting or
independent adoption is verified.

C# sales/CRM tutorial (2026-11-22): local .NET 8 build and self-tests passed
draft-only success with zero CRM writes, `customer-200` policy denial, simulated
CRM dependency failure, and the Web health/401/200/503 boundary. The self-test
uses an ephemeral loopback ASP.NET Core listener. Linux CI
[45093076768](https://github.com/axisvela/praxo-core/actions/runs/45093076768)
also passed at `00641594`. No CRM write, email send, real customer, production
identity, live model, public hosting or independent adoption is verified.

Lua host-embedding tutorial (2026-11-22): local Lua 5.4.6 passed a host event
through the native Lua Core. The report contained the fixed `device-100` snapshot,
a `draft_only` `notify_operator` draft with `review_required`, and an empty
`device_writes` array; an out-of-scope device was denied before callbacks
(`reads=0`); simulated telemetry failure failed after one read. Linux CI
[45095923385](https://github.com/axisvela/praxo-core/actions/runs/45095923385)
also passed at `9163d03a`. No real device protocol, command, socket, production
identity, live model, public hosting or independent adoption is verified.

Rust IoT gateway tutorial (2026-11-23): local Rust with the published
`praxo-core==0.10.0` crate passed success, policy denial and simulated adapter
failure. The success report contained the fixed `device-100` snapshot, a
`draft_only`, `review_required` `open_ticket` draft and zero device writes; the
out-of-scope `device-200` was denied before the adapter (`reads=0`); simulated
adapter failure returned `GATEWAY_READ_FAILED` after one read. `cargo fmt
--check` and `cargo run --locked -- --test` passed locally. Linux CI
[45098362060](https://github.com/axisvela/praxo-core/actions/runs/45098362060)
also passed at `a78de75e`. The adapter is an in-process fixture; no MQTT, OPC UA,
socket, device command, live model, public hosting or independent adoption is
verified.

Zig gateway-health tutorial (2026-11-23): local Zig 0.17.0 with the native Zig
Core passed success, policy denial and simulated adapter failure. The success
report contained the fixed `gateway-100` snapshot (`health=degraded`, disk `91`,
memory `78`), a `draft_only`, `review_required` `restart_telemetry` draft and zero
device writes; the out-of-scope `gateway-200` was denied before the adapter
(`reads=0`); simulated adapter failure returned `GatewayReadFailed` after one
read. Linux CI
[45102354617](https://github.com/axisvela/praxo-core/actions/runs/45102354617)
also passed at `0b2f15d6`. The adapter is an in-process fixture; no MQTT, OPC UA,
socket, device command, live model, public hosting or independent adoption is
verified.

| Area | Verified | Level | Limits |
| --- | --- | --- | --- |
| Python published package | PyPI `praxo-core==0.10.0` is published from source tag `python/v0.10.0`. The docs CI published-upgrade check installed `0.2.4`, ran the unchanged consumer and governed checks, upgraded to `0.10.0`, and reran the suite successfully. Historical local checks cover `0.3.2` and `0.2.4` | Registry publication + CI upgrade | One version pair; a post-publication consumer install outside CI for `0.10.0` is not recorded here; one platform/toolchain; not an independent or non-author consumer; no provider or production evidence |
| Python published-package upgrade (historical pair) | `scripts/test_python_upgrade.py` installs PyPI `0.2.4`, runs the unchanged consumer fixture and governed compatibility checks, upgrades to `0.3.0`, and reruns the full starter/governed suite | CI + registry upgrade | One version pair; does not prove arbitrary upgrade paths, independent consumers, or production behavior |
| TypeScript published package | npm `@axisvela/praxo-core@0.9.0` is published from source tag `typescript/v0.9.0`. The docs CI published-upgrade check moved an unchanged consumer from `0.1.5` to `0.9.0` and passed the governed checks. The consumer example lockfiles now use the registry `0.9.0` integrity; the earlier copied `0.8.1` integrity made `npm ci` fail with EINTEGRITY | Registry publication + CI upgrade + fresh lockfile install | One version pair; the docs CI install is CI-driven, not an independent consumer; one platform; no provider or production evidence |
| TypeScript published-package upgrade (historical pair) | `scripts/test_typescript_upgrade.py` installs npm `0.1.5`, runs the unchanged consumer and governed compatibility checks, upgrades to `0.2.0`, and reruns the full starter/governed suite | CI + registry upgrade | One version pair; does not prove arbitrary upgrade paths, independent consumers, or production behavior |
| Rust published crate | crates.io `praxo-core==0.10.0` is published from source tag `rust/v0.10.0`. The release workflow ran `cargo test`, conformance, API snapshot, and package dry-run before publish. The recorded local registry install smoke covers `0.1.4` | Registry publication + release-workflow gates | Post-publication consumer install for `0.10.0` not recorded; one platform; not an independent consumer; no provider or production evidence |
| Dart published package | `praxo_core==0.7.0` is published on pub.dev from source tag `dart/v0.7.0`. A prior clean project installed `0.6.1`, imported `package:praxo_core/praxo_core.dart`, and passed the deterministic consumer check. The `0.7.0` release workflow passed conformance, API snapshot, tests, dry-run, and archive checks; a post-publication install for `0.7.0` was not rerun | Registry publication + clean-project install smoke | One platform; same-machine project, not an independent or non-author consumer; no real provider or target-platform verification; pub.dev score/downloads are not adoption evidence |
| Ruby published gem | RubyGems `praxo-core==0.9.2` is published from source tag `ruby/v0.9.2`. The release workflow ran conformance, API snapshot, native tests, gem build, an isolated Bundler check, and publication. `0.9.2` refreshes the RubyGems README and gem description; `0.9.1` removed the undeclared `base64` dependency | Registry publication + release-workflow gates + CI consumer | The CI `current-ruby-consumer` job installed the published gem and passed the allow/deny starter on 2026-11-21 (run `44913820352`); one platform; not an independent consumer; no provider or production evidence |
| Lua published rock | LuaRocks `praxo-core==0.8.1-1` is published through `.github/workflows/lua-release.yml`, which builds the source rock, installs it in a clean tree, runs the installed smoke, and publishes. `0.8.1-1` expands the rockspec description and README | Registry publication + release-workflow install smoke + CI consumer | The CI `current-lua-consumer` job installed `0.8.1-1` and passed on 2026-11-21 (run `44917317881`); one platform; not an independent consumer; no provider or production evidence |
| PHP published package | Packagist publishes `axisvela/praxo-core==0.8.1` from split tag `v0.8.1`. On 2026-11-18 Composer 2.11.2 installed its dist archive into a previously absent `vendor` directory with a fresh cache; `composer test` printed `php consumer tests passed`. Installed metadata identifies split commit `378c5f4ecf4728b2676d34fcbaf97c5f9c9cab8a` and Composer `autoload.files`. Source tag `php/v0.8.2` and split tag `v0.8.2` were pushed later; Packagist still listed `0.8.1` at check time | Registry publication + fresh Composer install + published-package consumer | Windows / PHP 8.5.12; TLS extensions enabled per command and trusted proxy CA supplied without disabling verification. One platform; not an independent consumer; no provider or production evidence |
| C# published package | `Praxo.Core==0.10.0` is published from source tag `csharp/v0.10.0`. The release workflow built, tested, packed, and pushed it; the public NuGet index lists `0.10.0` | Registry publication + release-workflow gates | A clean consumer install for `0.10.0` is not recorded here; one platform; not an independent consumer; no provider or production evidence |
| C# OIDC/JWKS service authentication | `language/csharp/examples/service` verifies RS256/RS384/RS512 JWTs with issuer/audience checks, provider discovery, a five-minute JWKS cache, and one refresh on an unknown `kid`. A loopback discovery/JWKS test covers allow, wrong audience, expired token, wrong issuer, unknown key, and unavailable provider; run with `dotnet run --project language/csharp/examples/service -- --test` (2026-11-22) | Contract/unit + local loopback | One example and platform; no hosted identity provider, key rotation, revocation integration, or independent reproduction; not an identity provider or production security guarantee |
| Java OIDC/JWKS service authentication | `language/java/examples/service` implements the same RS256/RS384/RS512, provider-discovery, JWKS-cache, issuer/audience, tenant, and fail-closed behavior, with loopback discovery/JWKS tests in source. `mvn -q -f language/java/examples/service/pom.xml compile exec:java -Dexec.args=--test` passes in Linux CI (GitHub Actions run 45005327661, Temurin 21.0.13, 2026-11-22) | CI runtime on Ubuntu | The local Windows `java`/`javaw` launcher hangs before main; one CI platform; no hosted provider, key rotation, revocation integration, or independent reproduction |
| Ruby OIDC/JWKS service authentication | `language/ruby/examples/service` verifies RS256/RS384/RS512 JWTs with discovery, a five-minute JWKS cache, issuer/audience, tenant, and fail-closed behavior. The scripted transport covers allow, wrong audience, expired token, wrong issuer, unknown key, and unavailable provider; `ruby language/ruby/examples/service/service.rb` passed with Ruby 3.4.12 (2026-11-22) | Contract/unit | Scripted transport, not a hosted provider; no key rotation, revocation integration, or independent reproduction |
| PHP OIDC/JWKS service authentication | language/php/examples/service implements the same RS256/RS384/RS512, discovery, JWKS-cache, issuer/audience, tenant, and fail-closed checks. php ... service.php passed with PHP 8.5.12 and OpenSSL enabled (2026-11-22) | Contract/unit | Scripted transport, not a hosted provider; no key rotation, revocation integration, or independent reproduction |
| Rust OIDC/JWKS service authentication | language/rust/examples/service/src/oidc.rs verifies RS256/RS384/RS512 JWTs with discovery, a five-minute JWKS cache, issuer/audience, tenant, and fail-closed behavior. Static signed vectors plus scripted discovery/JWKS cover allow, wrong audience, expired, wrong issuer, unknown key, and unavailable provider; cargo test passed in Linux CI (run 45012247475, 2026-11-22) | CI contract/unit | Static fixtures and scripted transport; no hosted provider, key rotation, revocation integration, or independent reproduction |
| Haskell published package | Hackage `praxo-core-0.8.0` is published from source tag `haskell/v0.8.0`. The release workflow ran native tests, API/parity checks, and `cabal sdist`/publication | Registry publication + release-workflow gates | A post-publication consumer install for `0.8.0` is not recorded here; one platform; not an independent consumer; no provider evidence |
| MATLAB File Exchange package | `PRAXO-CORE 0.5.0` is the published File Exchange version at entry `185166`; source tag `matlab/v0.8.0` exists and the 0.8.0 upload remains pending | Registry publication | MATLAB runtime verification and consumer install smoke are not recorded; Octave verification does not establish MATLAB behavior |
| PowerShell Core | PowerShell Gallery `praxo-core-ps==0.8.1` is published and recorded in the registry metadata. The release workflow built the C# Core, ran wrapper tests and the API snapshot, and the Gallery reported `0.8.1` as published | Registry publication + release-workflow gates + CI consumer | The CI `current-powershell-consumer` job installed `0.8.1` from PSGallery and passed the allow/deny starter on 2026-11-21 (run `44917317881`); one platform; not an independent consumer; no provider evidence |
| Perl published package | CPAN `Praxo-Core==0.7.1` is published from source tag `perl/v0.7.1`. The release workflow ran conformance, API snapshot, tests, and `make dist`, then published. `0.7.1` ships `README.pod` instead of Markdown | Registry publication + release-workflow gates + isolated `cpanm` install recorded for `0.6.1` | No post-publication consumer install for `0.7.1` is recorded; MetaCPAN indexing may lag the upload; one platform; no provider evidence |
| R source release | Source tag `r/v0.11.0` was created and the `r-release` workflow passed build/check. r-universe rebuilt `praxocore==0.11.0` from source commit `d59cb301` on 2026-11-21 | Source release + r-universe rebuild | No post-publication R consumer install; one platform; no provider or production evidence |
| Swift source release | Source tag `swift/v0.7.1` and split tag `0.7.1` were pushed. The split repository contains the updated Package.swift, Sources, Tests, examples, and API snapshot. Swift Package Index still listed `0.7.0` as latest at check time | Source release + split tag pushed + pending SPI index | No Swift build/test or post-publication consumer run is recorded here; macOS runtime remains unverified; one platform; no provider or production evidence |
| Elixir published package | Hex `praxo_core==0.10.0` is published from source tag `elixir/v0.10.0`. The release workflow ran conformance, API snapshot, native tests, and Hex publication | Registry publication + release-workflow gates | A post-publication consumer install for `0.10.0` is not recorded here; one platform; not an independent consumer; no provider evidence |
| Erlang published package | Hex `praxo_core_erlang==0.9.0` is published from source tag `erlang/v0.9.0`. The release workflow ran conformance, API snapshot, native tests, and Hex publication | Registry publication + release-workflow gates | A post-publication consumer install for `0.9.0` is not recorded here; one platform; not an independent consumer; no provider evidence |
| D published package | DUB/code.dlang.org lists `praxo-core==0.6.1` from split tag `v0.6.1`. Source tag `d/v0.7.0` is newer; 0.7.0 features are not in the split package | Registry publication | No compile or independent consumer smoke for `0.6.1`; one platform; no provider or production evidence |
| Java published package | Maven Central `com.axisvela:praxo-core:0.11.0` is published from source tag `java/v0.11.0` with sources, javadoc, and GPG signatures. The earlier tag push ran build-only, which is why the publication gap was not caught before the consumer pin moved; the docs CI fresh consumer install resolved `0.11.0` and passed the starter/governed checks (run `44731906136`) | Registry publication + Central validation + fresh consumer install | Hosted docs CI success; not an independent consumer; local Maven/JVM execution hangs on this workstation; one platform; no provider or production evidence |
| Java published-package upgrade (historical pair) | `scripts/test_java_upgrade.py` resolves Maven Central `0.3.0`, runs the unchanged consumer and governed compatibility checks, upgrades to `0.4.0`, and reruns the full starter/governed suite | CI + registry upgrade | One version pair; does not prove arbitrary upgrade paths, independent consumers, or production behavior |
| Extended consumer starters (Ruby/PHP/Elixir/Lua) | Deterministic allow/deny starters in `examples/consumer-ruby`, `consumer-php`, `consumer-elixir`, and `consumer-lua` pass in source-mode locally. Recorded registry install checks covered RubyGems `praxo-core==0.4.1`, Hex `praxo_core==0.4.1`, LuaRocks `praxo-core==0.4.1-1`, and Composer `axisvela/praxo-core==0.4.1`; these are historical versions. Current published versions are in Registry Publication Status | Contract/unit + historical local registry installs | Extended-language starters; no governed negative matrix; one platform; no provider, identity, isolation, or production evidence |
| Consumer test template fixture runs | On 2026-11-22 the template commands were run against maintainer-owned consumer fixtures: Go `go test -mod=readonly -run Governed ./...` passed; Python `test_governed.py` passed 5/5 with `PYTHONPATH=language/python`; TypeScript `npm test` passed 9/9; C# printed the allow/deny output; Rust printed the allow/deny output with `CARGO_HTTP_CHECK_REVOKE=false`; Ruby printed `ruby consumer tests passed`; PHP printed `php consumer tests passed`; Elixir printed `elixir consumer tests passed`; Lua printed `lua consumer tests passed` when run from the repository root. Java `mvn -q test` did not finish within 180s on the local JVM launcher | Contract/unit + local fixture runs | Maintainer-owned fixtures, not external consumers; Python/Ruby/Elixir/Lua used source or local package paths; Java is covered by CI evidence, not this local run; Rust required a local TLS revocation workaround; one platform and toolchain set; no provider, identity, isolation, or production evidence |
| Python structured-output application | `language/python/examples/structured-output-app` turns a directory of text files into validated JSON-lines results, records rejected model output separately, and resumes successful sources. Recorded 2026-11-22 from a source checkout with `PYTHONPATH=language/python`: first run `processed=1 skipped=0 failed=1`, resume `processed=0 skipped=1 failed=1`; `test_app.py` passes 2/2; the example is included in `ci-examples` | Contract/unit + local application run | Maintainer fixture/source mode; deterministic model by default; JSON-lines files are not a database, queue, or exactly-once ledger; no live endpoint, external consumer, or production evidence |
| C#, Rust, and Java live-model local runs | On 2026-11-22 the local Ollama endpoint answered a Python `http.client` OpenAI-compatible request in 3.37s. The C# live-model example completed a real `get_time` tool call against local Ollama and printed a time when run through the built DLL (`dotnet language/csharp/examples/live-model/bin/Debug/net8.0/Praxo.LiveModel.dll`); the apphost/`dotnet run` path did not return in this shell. The Rust live-model built with `cargo build --offline` and completed a `get_time` call from the resulting binary; its model-generated time text was malformed but the tool path completed. The Java live-model was not run locally because the local JVM launcher hangs. The C# example disables proxy use for loopback URLs, and the Rust live-model dependency is updated to `praxo-core==0.10.0` | Local integration for C# and Rust; local attempt / blocked for Java | C# and Rust used local launcher/build workarounds; model output quality is not assessed; Java has no successful local live-model run; one local endpoint/platform; no hosted provider, billed call, independent reproduction, or production evidence |

### Reference Applications

| Area | Verified | Level | Limits |
| --- | --- | --- | --- |
| PHP Laravel content-review precursor | Local working tree (uncommitted) on 2026-11-25: `language/php/application/content-review` installs published `axisvela/praxo-core==0.8.1` and Laravel `12.74.0`; `vendor/bin/phpunit` passes 7/7 tests with 29 assertions. Coverage includes the article review draft with `publications_executed=0`, missing and mismatched tenants rejected with zero content reads, `article-200` policy-denied with zero reads/drafts, dependency failure returning `TOOL_ERROR` after one read and no draft, and the Artisan command success/failure paths. `php artisan content:review-article article-100` reports `reads=1`, `drafts=1`, `publications_executed=0`; `article-200` exits 1 with `AGENT_POLICY_DENIED`; `--simulate-failure` exits 1 with `TOOL_ERROR` | Contract/unit + local host runtime | PHP 8.5.12 with manually enabled extensions and a local CA/proxy workaround; deterministic model and in-memory fixture article store; this is a host-integration precursor, not the AI-native editorial studio; no live provider, hosted service, real CMS database, production identity, or independent consumer; application CI matrix added but not run; commit revision pending |
| PHP AI-native editorial studio | Local working tree (uncommitted) on 2026-11-25: `language/php/application/ai-editorial-studio` installs published `axisvela/praxo-core==0.8.1` and Laravel `12.74.0`; `vendor/bin/phpunit` passes 9/9 tests with 56 assertions. The brief workflow retrieves sources, saves a model-written `draft_only` artifact, attaches taxonomy, and creates a `review_requested` request with `publications_executed=0`; repository counts are one draft, one review, zero publications. `Publish immediately: ...` is policy-denied with zero effects; tenants and content-index failures are also covered. A hosted live run with DeepSeek `deepseek-flash` recorded `model=live`, a four-step trace (`search_content` -> `draft_article` -> `suggest_taxonomy` -> `request_publish_review`), a model-written rationale (858 characters in the latest run), and `publications_executed=0`; the model explicitly avoided inventing Q3 facts and used placeholders instead. The live run used a custom cURL transport for the local proxy/CA | Contract/unit + local host runtime + hosted live model | Deterministic and hosted live runs; fixture content index and in-memory draft/review repository; no Drupal host, real CMS, durable draft store, production identity, independent consumer, or production deployment; live transport was a custom cURL override; CI matrix added but not run; commit revision pending |
| Java AI commerce assistant (source only) | Source added at `language/java/application`: Spring Boot `3.4.5`, published `com.axisvela:praxo-core:0.11.0`, tenant filter, application-owned catalog and draft services, five tools with `checkout` always denied, model rationale and `agent_trace`, deterministic model, six main tests plus a catalog-failure test. The local JDK 25 JVM hangs even with redirected stdin, so no local compile, test, or live-model result exists. A Linux CI job is added but has not run | Source / CI pending (not verified) | No local compilation or test result; no live-model run; no CI result; no live provider, payment, real catalog, production identity, or independent consumer; do not claim Java tests or live reasoning pass until CI records them |
| Elixir AI ops copilot | Local working tree (uncommitted) on 2026-11-25: `language/elixir/application` on Elixir `1.20.4` / OTP `29`; `PRAXO_CORE_PATH=.. mix test` passes 6/6. The application supervises a telemetry store and remediation executor; success drafts a `draft_only` remediation with model diagnosis/rationale and `executions=0`; direct remediation is policy-denied with zero effects; `service-200` and a mismatched tenant are denied before read; telemetry failure returns `TELEMETRY_UNAVAILABLE` after one read and no draft; killing the telemetry process restarts it under the supervisor. A hosted live run with DeepSeek `deepseek-flash` recorded `model=live`: the model chose `search_signals(service-100)`, then `draft_remediation` with a model-written diagnosis and rationale, and finished with `executions=0`. An earlier attempt used the display name `checkout` and was policy-denied before the authorized service id was added to the prompt | Contract/unit + local OTP host + hosted live model | Source-mode deterministic tests and a hosted live run via `:httpc` proxy/CA; local Hex install and CI not run; fixture telemetry and in-memory executor; no live telemetry, production cluster, real remediation, durable state, production identity, independent consumer, or production deployment; commit revision pending |
| Erlang AI ops copilot | Local working tree (uncommitted) on 2026-11-25: `language/erlang/application` compiles the Erlang Core source and OTP application with OTP `29`; `python language/erlang/application/run-tests.py` passes 6/6. The application supervises a telemetry store and remediation executor; success drafts a `draft_only` remediation with model diagnosis/rationale and `executions=0`; direct remediation, `service-200`, and tenant mismatch are denied; telemetry failure returns `TELEMETRY_UNAVAILABLE` after one read; killing the telemetry process restarts it. A hosted DeepSeek `deepseek-flash` live run recorded `model=live`: the model chose `search_signals(service-100)`, then `draft_remediation` with a model-written diagnosis and rationale, and finished with `executions=0`; the transport used `httpc` with proxy/CA | Contract/unit + local OTP host + hosted live model | Source-mode Core compile, not a registry/rebar install; Erlang CI added but not run; fixture telemetry and in-memory executor; no live telemetry, production cluster, real remediation, durable state, production identity, independent consumer, or production deployment |
| Go AI infrastructure agent | Local working tree (uncommitted) on 2026-11-25: `language/go/application` uses a local module replace to the Go reference source; `go test ./...` passes 8/8. The app exposes HTTP and CLI entry points with tenant verification, application-owned telemetry/executor services, governed tools, and `agent_trace`. Success returns a `draft_only` remediation with model diagnosis/rationale and `executions=0`; direct remediation, `service-200`, and tenant mismatch are denied; telemetry failure returns `TOOL_ERROR`; invalid model output is rejected. A hosted DeepSeek `deepseek-flash` live run recorded `model=live`, a three-step trace (`search_signals` -> `draft_remediation` -> final report), a 350-character diagnosis, a 523-character rationale, and `executions=0` | Contract/unit + local Go host + hosted live model | Local module replace, not a registry install; Go CI added but not run; fixture telemetry and in-memory executor; no live telemetry, production cluster, real remediation, durable state, production identity, independent consumer, or production deployment |
| Rust AI edge gateway agent | Local working tree (uncommitted) on 2026-11-25: `language/rust/application` uses a local path dependency to the Rust reference source; `cargo test --offline` passes 6/6. The CLI uses an application-owned `GatewayAdapter`, governed tools, policy, and `agent_trace`. Success returns a `draft_only` remediation with diagnosis/rationale and `executions=0`; direct remediation, `device-200`, and tenant mismatch are denied; gateway failure returns `TOOL_ERROR`; invalid model output is rejected. The live path is wired, but the local TLS backend build is blocked by missing native C headers for `ring`, so no live run is recorded | Contract/unit + local Rust host | Local path dependency, not crate-registry evidence; Rust CI added but not run; fixture adapter and deterministic model; live reasoning is blocked, not verified; no real MQTT, OPC UA, socket, device write, production identity, independent consumer, or production deployment |
| C++ AI industrial edge agent | Local working tree (uncommitted) on 2026-11-25: `language/cpp/application` builds through the local Core CMake target with MinGW; the `--test` entry passes five CLI checks. The CLI uses an application-owned `GatewayAdapter`, governed tools, policy, and `agent_trace`. Success returns a `draft_only` remediation with diagnosis/rationale and `executions=0`; direct remediation, `device-200`, and tenant mismatch are denied; gateway failure maps to `TOOL_ERROR`. The live path is not implemented because the Core adapter requires an application-supplied HTTP transport | Contract/unit + local C++ host | Local Core CMake/source build, not registry-package evidence; C++ CI added but not run; fixture adapter and deterministic model; no live-model reasoning, real fieldbus/OPC UA/device write, production identity, independent consumer, or production deployment |
| COBOL AI batch exception analyst | Local working tree (uncommitted) on 2026-11-25: `language/cobol/application` compiles the native COBOL Core with GnuCOBOL `2.0.0`; `python language/cobol/application/run-tests.py` passes the five internal checks plus a batch-file check. The COBOL `praxo-run` loop reads `exceptions.tsv`, calls model-selected `read_exception` and `draft_advisory`, and writes review-only rows to `advisory.tsv`. Public success records diagnosis/rationale with `executions=0`; private records are denied before read; direct `post_adjustment` is denied with zero effects; tenant mismatch is denied before the model; a weak advisory without diagnosis/rationale is denied. The build-only executable stays under ignored `language/cobol/build/`, and no executable is committed | Contract/unit + local GnuCOBOL host | Native COBOL source build, not a registry-package install; COBOL CI added but not run; fixture exception file and deterministic scripted model; no live-model transport, real ledger/posting/settlement, durable queue/recovery, production identity, independent consumer, or production deployment |
| Reference-app live reasoning | PHP AI editorial studio, Elixir AI ops copilot, Erlang AI ops copilot, and Go AI infrastructure agent recorded live runs on 2026-11-25 with hosted DeepSeek `deepseek-flash`. Java AI commerce has source-level trace/rationale but no compile or live run; Rust has deterministic tests but its live path is blocked by the local TLS backend build; C++ has deterministic tests but no live HTTP transport; COBOL has deterministic tests but no bundled HTTP/TLS transport. Deterministic scripted models remain harness tests | Local hosted live-model integration (PHP/Elixir/Erlang/Go); source only (Java/Rust/C++/COBOL) | PHP used a custom cURL transport; Elixir/Erlang used `httpc` with proxy/CA; Go used the default OpenAI-compatible client; Rust/C++/COBOL live is blocked or missing; no independent reproduction, production deployment, cost/latency campaign, Drupal/payment/real telemetry, or production identity |

### Cross-Language Behavior and Integration Safety

| Area | Verified | Level | Limits |
| --- | --- | --- | --- |
| Cross-language delegation governance | All sixteen wired languages plus Perl, V, Nim, Dart, Julia, D, OCaml, Haskell, Zig, MATLAB/Octave (shared), and Delphi / Free Pascal have application-level negative checks for child scope narrowing, parent/child policy composition, sibling budgets, depth/child limits, cancellation before effects, and final-argument reauthorization. Recorded 2026-11-17: Go/Python/TypeScript/Rust/R/PHP/Ruby/Elixir/Erlang/Lua 6/6 each; C 16/16 ctest; C++ 7/7 ctest; COBOL full suite including 6 governance cases; Fortran direct governance 23 checks; C# 6/6 via ProjectReference; Java compile only; Perl/V/Nim/Dart/Julia/D/OCaml/Haskell/Zig/MATLAB-Octave/Delphi 6/6 each | Contract/unit + local integration | Application-level examples, not Core-enforced inheritance; Fortran full gate blocked by local executable removal, Java runtime blocked by JVM hang; MATLAB evidence is GNU Octave only; Delphi evidence is Free Pascal 3.2.2; no independent reproduction or production evidence |
| Cross-language agent behavior | All sixteen wired languages pass all twenty authorization, lifecycle, cancellation, validation, call-limit, parallel-tool, run-isolation, PII, checkpoint, capacity, SSE-truncation, stream-failure, and HITL-decision scenarios in the source. Agent-capable languages use scenario-level or self-test coverage; extended languages use native-suite coverage. Parallel tools for COBOL, Lua, PHP, and Fortran are delegated to caller-provided batch callbacks. Other implementations are optional. The clean-tree CI report at `b6218e5` records 320 passed, 0 unsupported, and no failures | Scenario tests + CI | All sixteen wired languages reach 20/20 in the source; some extended rows are suite-level and a failure is not isolated to a scenario; the earlier local run at `4ffd83b` is historical, not current evidence; not a throughput/stress test, not full feature parity, provider, sandbox, or production evidence |
| Governed workspace | Policy-required configuration, final-argument authorization, single-use approvals, post-approval edits, queued revocation, fail-closed dependency errors | Contract/unit | Example-level contract; not a Core profile, authenticated identity service, or durable approval store |
| Context trust | Memory, skill, tool-result and summary source separation; digest-bound approved skills; text restore; late System injection rejection | Contract/unit | Opt-in example path; not a general prompt-injection filter, source authenticator, or durable lineage proof |
| Containment | Windows path/process/WASM controls; Linux path and symlink controls in a verbose CI job; local VFS operations use `os.Root` after policy checks | Contract/unit + CI | Windows symlink cases skipped without privilege; policy decisions remain check-then-use; Linux cgroup v2 and independent review remain open; the pinned wazero API does not expose per-instruction fuel metering, so CPU bounding is deadline/cancellation-based rather than fuel-based |
| Workspace adapters | Shared conformance and fake-provider tests for E2B, Daytona, OpenSandbox, CubeSandbox | Contract/unit | All live provider tests skipped without credentials; no contract promotion |
| OpenTelemetry | Runnable in-memory example emits `run.started`, `tool.call`, `run.completed`; allowlist excludes tool arguments/results | Example + unit | No collector, OTLP backend, sampling, retention, or production telemetry verification |
| A2A interoperability | Google ADK consumes published Core `v2.5.1` A2A with no local Core replacement; success, denial, failure, timeout, authentication, TLS, cross-origin, and concurrent consumer fixtures | Local integration | Loopback deterministic fixture, not a deployed peer or production load test |
| Agent IAM contracts | Direct and gateway-shaped Agent IAM examples against contract fakes; credential time-window, key, signature, and subject checks | Contract/unit | NOMIVELA/EIDOVELA/AEGIVELA responses are fakes; the demo has no proof replay cache or body-bound gateway assertion |

### Coding-Agent and Adoption

| Area | Verified | Level | Limits |
| --- | --- | --- | --- |
| Coding-agent skill discovery | Claude Code `2.1.196` installed `agent-skills/praxo-integration` as a temporary skills-directory plugin; `plugin list` reported it loaded and `plugin details` listed the skill component (2026-11-08, `bdd36d7`; issue #15) | Local structural check | One tool and platform; that CLI did not run a model task or published-package integration; not adoption evidence |
| Coding-agent skill task | opencode `1.18.18` discovered `agent-skills/praxo-integration` from a project-local `.opencode/skills/praxo-integration/SKILL.md`, then completed a deterministic Python task using published PyPI `praxo-core==0.3.2` with explicit tool scope and allow/deny tests (3/3 passed; model `deepseek/deepseek-flash`; Python 3.14.6; 2026-11-08, `7004a08`) | Local structural check + local task execution | One tool, one task, one platform; first-pass success without repair; no governed negative matrix, live model, authentic identity, durable approvals, effect commit, exactly-once, or isolation evidence; not adoption evidence |

### Product and Embedded Evidence

| Area | Verified | Level | Limits |
| --- | --- | --- | --- |
| AKROVELA embedded PRAXO-CORE | AKROVELA embeds published PRAXO-CORE `v2.10.0` through a product-owned adapter: exact-operation tools, mandatory policy, bounded budgets, redacted telemetry, and a PostgreSQL Run/reconciliation journal. The AKROVELA repository records a deterministic P1 slice with a test model and local PostgreSQL (`b5e5da9`, 2026-11-08), an F5 local API/PostgreSQL simulation at `a5e8e1d` (2026-11-22), and an E1-E8 deterministic/local component matrix at `f8fd4d7` (2026-11-22). The F5 run passed 6/6 cases with duplicate submission remaining idempotent, scope mismatch returning `403`, terminal API restart preserving receipts, `full_api_e2e=local_dev_passed`, `database_receipt_durability=terminal_restart_verified`, and `mid_execution_crash_recovery=verified`; `stage_3_4_p2_acceptance=not_claimed`. The E1-E8 matrix passes all eight requirements; this is not P2 acceptance. A G1-G8 deterministic/local component matrix at `907b1eb` (2026-11-22) maps 46 tests; all mapped checks pass, including G2 unexposed-tool denial and G6 assembly, compaction, offload, and restore. G2/G6 local simulation is not applicable to the F5 direct-operation API, so full P2 acceptance is not claimed. The product upgraded from Core `v2.6.0` to `v2.10.0` at `9ac0e53` and recorded the verification at `054e98a` (2026-11-22); `go build ./...`, `go vet ./...`, and `go test ./...` pass, including PostgreSQL-gated recorder/runtime tests against a disposable local PostgreSQL 17 database. | Local integration (product repository); component/fixture scope | No production model provider, Agent HTTP endpoint, real ROS 2/Gazebo/Linux execution, hardware effect, independent observation source/verifier, live KINETOVELA integration, or E1-E8 pilot acceptance; the F5 API run uses a simulated bridge/source and disposable local database; the E1-E8 and G1-G8 matrices are deterministic/local component evidence, not P2 simulation acceptance; G1-G8 has G2/G6 simulation not-applicable; product-owned evidence, not Core acceptance or independent adoption |
| Bridge recall surface | Source audit of `cmd/praxo-bridge` and `internal/bridge` at `4bcb39c2` (2026-11-21): `run` and `event stream` pass the request prompt directly to `agent.Run`; no memory constructor, recall injection, system-role promotion, or session-message store is present, and `tool list` returns an empty list | Contract/source audit | Source-only audit; no live provider or end-to-end Bridge memory test; does not prove absence in future changes, other tools, or provider-side behavior |
| Integration recovery | Real local Symbivela, Ontovela, Rheovela, Orchadyn, Praxovela, LIMENORA, and integration-domain services; 8 steps, 5 products, 4 gates, 13 evidence artifacts, 11/11 report checks; preserve/verify denials and silent-rerun rejection | Local integration | Disposable local databases and fixed IDs; no production, network partition, concurrent load, independent reproduction, or deployment verification |
| Product effect ledgers | RHEOVELA effect/durable/crash tests and PRAXOVELA tenant-scoped effect-ledger tests, including in-memory/SQLite lifecycle and reconciliation | Contract/unit (product repositories) | In-process SQLite/temp files; not a live PostgreSQL cluster or a cross-service transaction |

## Public Evidence Links

- [Compatibility lab](../languages/compatibility-lab.md) and the [recorded CI compatibility job](https://github.com/axisvela/praxo-core/actions/runs/41000572198/job/123883752839)
- [Behavior lab](../languages/behavior-lab.md) and the [CI behavior job at `b6218e5`](https://github.com/axisvela/praxo-core/actions/runs/41407891314/job/125153985339)

CI links above point to recorded runs. They are evidence for the revision named
by the run, not proof that the current `main` passes.
Registry links name the current published version; the consumer-smoke rows above
name the version that was actually installed.

- [Current registry versions and addresses](../languages/registry-status.md)
- [praxo-core 0.10.0 on PyPI](https://pypi.org/project/praxo-core/0.10.0/)
- [@axisvela/praxo-core 0.9.0 on npm](https://www.npmjs.com/package/@axisvela/praxo-core/v/0.9.0)
- [praxo-core 0.10.0 on crates.io](https://crates.io/crates/praxo-core/0.10.0)
- [praxo_core 0.7.0 on pub.dev](https://pub.dev/packages/praxo_core/versions/0.7.0)
- [praxo-core 0.9.2 on RubyGems](https://rubygems.org/gems/praxo-core/versions/0.9.2)
- [praxo-core 0.8.1-1 on LuaRocks](https://luarocks.org/modules/hanhhuiwen/praxo-core)
- [praxo_core 0.10.0 on Hex](https://hex.pm/packages/praxo_core/0.10.0)
- [Praxo.Core 0.10.0 on NuGet](https://www.nuget.org/packages/Praxo.Core/0.10.0)
- [axisvela/praxo-core 0.8.1 on Packagist](https://packagist.org/packages/axisvela/praxo-core)
- [praxo_core_erlang 0.9.0 on Hex](https://hex.pm/packages/praxo_core_erlang/0.9.0)
- [praxo-core-ps 0.8.1 on PowerShell Gallery](https://www.powershellgallery.com/packages/praxo-core-ps/0.8.1)
- [Praxo-Core 0.7.1 on MetaCPAN](https://metacpan.org/dist/Praxo-Core)
- [praxo-core 0.6.1 on DUB](https://code.dlang.org/packages/praxo-core)
- [com.axisvela:praxo-core 0.11.0 on Maven Central](https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.11.0/)
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
- An all-green CI status. Cancelled, failed, or not-run jobs are not passes;
  use the recorded CI links and their stated limits.

## Reporting A Gap

If a claim cannot be reproduced, open an issue with the commit, platform,
commands, inputs, expected result, observed result, and whether the mismatch is a
test defect or a behavior defect. Do not replace a failed record with a later
successful retry; keep both.
