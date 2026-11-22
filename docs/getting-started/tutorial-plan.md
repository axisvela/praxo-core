# Tutorial Plan

**Status:** public planning reference, 2026-11-22. This page is the single public
entry point for application-shaped tutorials. It is not a release schedule or a
promise that every language receives every tutorial.

The goal is not to duplicate the thirteen mechanism themes in every language. It
is to show **why an Agent belongs in that language's ecosystem**: a Web service,
an operations shell, an analytics workflow, a host embedder, or a constrained
device. Each tutorial keeps one coherent application path and a small number of
important boundaries.

## Where the Plan Lives

| Layer | Location | Purpose |
| --- | --- | --- |
| Public direction | This page and the [roadmap](../project/roadmap.md) | Scenario map, status, boundaries, links |
| Per-language entry | `language/<language>/Tutorial/README.md` | What that language can build and how to run it |
| Execution detail | Internal `PRAXOVELA-EE/docs/praxo-core/planning/shared-business-tutorials.md` | Sequencing, acceptance, run records, staffing/product notes |
| Shared business APIs | [agent-tutorial-services](https://github.com/axisvela/agent-tutorial-services) | Synthetic contracts, fixtures, local service tests |
| Evidence | [Verification Evidence](../project/verification-evidence.md) | Exact revision, scope, and limits |

`Tutorial/` is a sibling of `examples/`. Existing mechanism examples keep their
published paths. Business APIs stay outside Core and `spec/`; they are teaching
contracts, not framework compatibility promises.

## Scenario Map

| Language / ecosystem | Tutorial outcome | Distinct value | Shared backend |
| --- | --- | --- | --- |
| Java | Order exception review | Enterprise Web entry, JUnit, published Maven Core | Orders |
| Python | Onboarding checklist and ticket draft | Retriever/structured output and application service shape | Onboarding (planned) |
| TypeScript | Customer support reply with streaming | Front-end/Node integration and SSE | Orders |
| C# | Employee or order service desk | ASP.NET Core, OIDC-ready service boundary | Orders; HR planned |
| Go | Incident coordination | Reference Core, plugins, telemetry, long-running operations | Operations planned |
| PowerShell | Windows service/disk diagnostics | Fixed read-only native operations, local machine checks | None (local diagnostics) |
| Perl | Log and batch inspection | Native text processing and legacy automation | Operations planned |
| COBOL | Banking batch exception review | Deterministic batch path and review boundary | Existing batch fixture |
| Fortran | Simulation diagnostics | Numerical evidence before model interpretation | Analysis planned |
| Julia | Experiment comparison | Native numerical work and experiment drafts | Analysis planned |
| R | Data quality and statistical report | Native statistics with evidence-linked narrative | Analysis planned |
| Octave / MATLAB | Signal and sensor trend review | Native matrix/signal processing; Octave vs MATLAB evidence split | Analysis planned |
| Lua | Embed in an existing host | Host callbacks and small-footprint integration | Host-specific |
| Rust | IoT gateway diagnosis | Edge deployment, HTTP model adapter, process plugins | Devices planned |
| Zig | Small gateway health check | Minimal deployment and explicit platform limits | Devices planned |
| C | Constrained host diagnostic component | Caller-owned memory/network/transport contract | Devices planned |
| C++ | Industrial edge maintenance | Existing device SDK wrapped as scoped tools | Devices planned |

These are candidate paths. A language moves from candidate to implemented only
when its tutorial has runnable commands, tests, and recorded evidence.

## Current Status

| Tutorial | Core integration | Verification | Limits |
| --- | --- | --- | --- |
| Python order review | Native Core, HTTP tool, fixed order scope, draft-only | Local and hosted CI against the public local service | Deterministic model; no live provider or external consumer |
| TypeScript order support | Native Core, HTTP tool, fixed order scope | Local and hosted CI against the public local service | Deterministic model; CLI, not a Web frontend |
| Java order review | Native Core, JUnit, loopback Web, real-service CLI | Mock/Web JUnit and real-service CLI passed in Linux CI | Java Web-to-real-backend and live model not verified |
| C# order service desk | ASP.NET Core, native Core, CLI and Web | Self-tests plus real-service CLI and Web in Linux CI | Deterministic model; no production identity |
| PowerShell Windows diagnostics | Shared C# Core through the module | Local Windows tests and hosted Windows CI | No Gallery install, repair, remote host or live model |
| Perl log triage | Native Perl Core, fixed fixture log, severity report | Local Perl 5.40.3 tests and Linux CI | No arbitrary path, shell, alert delivery or live model |
| COBOL, R, Julia, Octave, Lua, Rust, Zig, C, C++ | Not implemented as Tutorial entries | Not run | Candidate paths only |

See [Verification Evidence](../project/verification-evidence.md) for exact run
IDs and scope. "Passed in CI" does not mean production readiness, independent
adoption, or a public hosted business service.

## Shared Business Services

The maintained teaching backend is public MIT source at
[agent-tutorial-services](https://github.com/axisvela/agent-tutorial-services).
It runs locally on loopback and has no hosted endpoint. Python, TypeScript, Java
and C# order tutorials share its synthetic order contract while keeping their own
Core, tools, policy and model adapters.

The original `demo-repository` remains private. Core CI pins an immutable public
backend revision, so it does not need a private token. Business service code must
not be copied into Core or `spec/`.

## Tutorial Delivery Standard

Every implemented tutorial should provide:

1. a named task and explicit non-goals;
2. a deterministic mode with no provider credentials or public service;
3. an optional live-model mode that reuses the same business tools;
4. at least one denial or dependency-failure path with zero unintended effects;
5. an application-owned boundary for identity, persistence, approval and effect
   reconciliation;
6. an exact run command, expected output, and nonzero failure behavior;
7. a test entry that CI can run;
8. a scope statement: source, local, CI, real local service, live provider, and
   independent reproduction as separate evidence levels.

Tutorials should not add a new Core or wire API unless a named consumer
demonstrates a reusable gap. Application-specific tools belong in the tutorial,
not in `pkg/...` or `spec/`.

## Next Work

1. Add an analytics path (R or Julia) that separates computed evidence from model
   narrative.
2. Reuse the COBOL batch exception example rather than creating a new bank model.
3. Add device tutorials only when a concrete runtime and transport contract exist.
4. Turn each verified tutorial into a consumer test-authorized path, not just a
   maintainer demo.

Language count is not the goal. Fewer complete, differentiated paths are more
useful than many isolated mechanism checks.
