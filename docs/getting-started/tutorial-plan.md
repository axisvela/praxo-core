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

## Extended Scenario Catalog

The catalog below broadens the application map without creating a commitment to
build every entry. Choose the primary language by runtime fit, available tools,
and a named consumer; keep the tutorial boundary narrow.

| Scenario | Primary language(s) | Why this language/ecosystem | Status |
| --- | --- | --- | --- |
| Knowledge Q&A and document assistant | Python, TypeScript | Retrieval, citations, structured answers, streaming UI | Python office Q&A implemented and CI verified |
| Customer service / contact center | TypeScript, C# | Web/SSE, ASP.NET Core, identity and audit | TypeScript customer-support implemented and CI verified |
| Marketing content and segmentation | Python, R | Content workflows plus native statistical segments | Planned |
| Office productivity | Python, C# | Documents, email/calendar tools, .NET integration | Python office Q&A next |
| Sales / CRM | C#, TypeScript | Enterprise authentication and web integration | Planned |
| Wealth / retail finance | Java, R | Service boundaries plus risk/return analysis | Planned |
| Insurance claims | Python, Java | Document extraction, approval, audit boundaries | Planned |
| Procurement / ERP | Java, C# | Enterprise systems and application-owned identity | Planned |
| Factory / manufacturing | C++, Rust | OPC UA/device SDK seams, edge deployment | Planned |
| Industrial automation | C++, Rust, Octave | Device SDK plus signal analysis | Planned |
| Consumer electronics | Lua, C, Rust | Host embedding, constrained runtime, gateway | Planned |
| Robotics | C++, Rust, Julia | ROS 2 integration, control and numerical analysis | Planned |
| Logistics | Go, Java | Event-driven services and long-running operations | Planned |
| Energy / grid | Rust, C++, Julia | Edge constraints and numerical analysis | Planned |
| Security / SOC | Go, Perl, PowerShell | Services, logs and Windows operations | Planned |
| Healthcare scheduling | C#, Java | Identity, audit and enterprise integration | Planned |
| Legal / compliance | Python, R | Citations, evidence, human-review boundaries | Planned |
| Education / tutoring | TypeScript, Python | Web Q&A and content workflows | Planned |
| Media / content | TypeScript, Python | Streaming, generation and publishing tools | Planned |
| Travel / booking | TypeScript, C# | Web entry and enterprise booking boundaries | Planned |
| Retail / e-commerce | TypeScript, Java | Web storefront and order services | Planned |
| Data platform | Python, R, Julia | Native compute with evidence-linked reports | Planned |

This is a demand map, not a delivery promise. A scenario moves forward only with
a named consumer or maintainer, a concrete task, a deterministic mode, a denial
or failure path, and recorded evidence. A language can own several scenarios, but
the first implementation should reuse its existing Core and adapters rather than
add framework surface.

### Scenario Selection Rules

- Choose the language whose runtime and libraries fit the task, not the one with
  the most existing examples.
- Prefer a local deterministic task with one or two tools over a broad platform
  mock.
- Keep business contracts and synthetic data outside Core and `spec/`.
- Keep identity, durable state, effect reconciliation and approvals application-owned.
- Do not add a new Core API until a consumer proves a reusable gap.
- Treat a passing tutorial as integration evidence, not adoption or production
  readiness.

## Current Status

| Tutorial | Core integration | Verification | Limits |
| --- | --- | --- | --- |
| Python order review | Native Core, HTTP tool, fixed order scope, draft-only | Local and hosted CI against the public local service | Deterministic model; no live provider or external consumer |
| TypeScript order support | Native Core, HTTP tool, fixed order scope | Local and hosted CI against the public local service | Deterministic model; CLI, not a Web frontend |
| Java order review | Native Core, JUnit, loopback Web, real-service CLI | Mock/Web JUnit and real-service CLI passed in Linux CI | Java Web-to-real-backend and live model not verified |
| C# order service desk | ASP.NET Core, native Core, CLI and Web | Self-tests plus real-service CLI and Web in Linux CI | Deterministic model; no production identity |
| PowerShell Windows diagnostics | Shared C# Core through the module | Local Windows tests and hosted Windows CI | No Gallery install, repair, remote host or live model |
| Perl log triage | Native Perl Core, fixed fixture log, severity report | Local Perl 5.40.3 tests and Linux CI | No arbitrary path, shell, alert delivery or live model |
| R data quality | Native R statistics, fixed data frame, computed report | Local R 4.6.1 tests and Linux CI | No arbitrary file/SQL/shell, live model or causal claim |
| COBOL batch exception review | Reuses deterministic batch handoff; separate review worker | Local GnuCOBOL 2.0.0/Python checks and Linux CI | No real posting, durable queue, recovery proof or live model |
| Julia experiment comparison | Native Julia means/delta over fixed results | Local Julia 1.13.2 tests and Linux CI | No arbitrary data/code/package install, live model or causal claim |
| Octave/MATLAB signal trends | Shared signal metrics, threshold anomalies | Local GNU Octave 11.3.0 tests and Linux CI | Native MATLAB unverified; no device control or live model |
| Python office Q&A | Native Core, fixed documents, citation-bearing answer | Local Python 3.14 checks and Linux CI | No arbitrary file/connector, email action or live model |
| TypeScript customer support | Native Core, fixed order/policy tools, SSE stream | Local Node 24 checks and Linux CI | No reply send, order change, refund or live model |
| Lua, Rust, Zig, C, C++ | Not implemented as Tutorial entries | Not run | Candidate paths only |

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

1. Add Java wealth/finance or C# sales/CRM only after a concrete consumer path.
2. Add device tutorials only when a concrete runtime and transport contract exist.
3. Turn each verified tutorial into a consumer test-authorized path, not just a
   maintainer demo.

Language count is not the goal. Fewer complete, differentiated paths are more
useful than many isolated mechanism checks.
