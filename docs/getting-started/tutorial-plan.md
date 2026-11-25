# Tutorial Plan

Browse the [unified Tutorial Catalog](tutorial-catalog.md) by industry, language,
scenario and capability. It combines the earlier themes, hundred candidate goals,
application tutorials, guides, recipes and mechanism examples with separate counts.
This page defines delivery standards and scoped verification, not another inventory.

**Status:** public planning reference, 2026-11-25. Basic scenario slices exist for
the candidate language/scenario assignments. Tutorial CI passed at `dfdfd558` in
[run 45537631891](https://github.com/axisvela/praxo-core/actions/runs/45537631891).
This supersedes the earlier pending-CI notes, not the recorded local limitations.
It is not a release schedule, independent adoption, or a promise of every feature
in every language. No end-to-end reference application for the hundred full goals
is recorded. A bounded slice is accepted against its own scope.

The next-stage priority is the [reference application portfolio](../project/roadmap.md#reference-application-portfolio):
PHP, Java, Elixir/Erlang, Go, C++/Rust, COBOL, Julia, then Ruby. Reuse useful slices,
but demonstrate the host ecosystem and runtime rather than another generic loop.

## Where the Plan Lives

| Layer | Location | Purpose |
| --- | --- | --- |
| Public direction | This page and the [roadmap](../project/roadmap.md) | Scope, priorities, standards and evidence links |
| Canonical inventory | [Tutorial Catalog](tutorial-catalog.md) | Generated scenario, language and source-path index |
| Per-language entry | `language/<language>/Tutorial/README.md` | Runtime rationale, commands and per-tutorial limits |
| Reference application | `language/<language>/application/README.md` | Host integration, install/run commands, evidence and limits |
| Execution detail | Internal `PRAXOVELA-EE/docs/praxo-core/planning/shared-business-tutorials.md` | Sequencing, acceptance, run records and product notes |
| Shared business APIs | [agent-tutorial-services](https://github.com/axisvela/agent-tutorial-services) | Synthetic contracts, fixtures and local service tests |
| Evidence | [Verification Evidence](../project/verification-evidence.md) | Exact revision, scope and limits |

`Tutorial/` is a sibling of `examples/`. Reference applications live at
`language/<language>/application/` and are not part of the generated tutorial
catalog; they are full host integrations rather than tutorial slices. Existing
mechanism examples keep their published paths. Business APIs stay outside Core and
`spec/`; they are teaching contracts, not framework compatibility promises.

## Language Selection Gate

The [runtime-aligned tutorial design](runtime-scenario-design.md) records bounded
paths for V, D, Haskell, OCaml, Erlang, Julia, Octave, COBOL and Zig. Those paths
are inputs to reference applications, not full applications by themselves.

The basic-entry batch is delivered. Keep useful, accurately scoped examples and
use reproduction attempts or actual usage feedback to select deeper work. Basic
examples do not require an established consumer or a demonstrated ecosystem
advantage before publication. Reference applications, however, must exercise a
real host or dependency rather than claim ecosystem value from generic callbacks.

Every new or substantially revised tutorial must include a section titled
`Why this language and runtime?`, answering:

- **Selection basis:** What existing host, libraries, deployment constraints or consumer justify this runtime?
- **Demonstrated fit:** Which executable path and test exercise that integration, rather than a future possibility?
- **Choose when:** Under what application conditions is this a useful starting point?
- **Do not choose when:** Would a simpler workflow, another runtime or external orchestration fit better?
- **Evidence limit:** Is this Core integration, exercised ecosystem integration or independent consumer reproduction?

Language guidance must describe runtime, concurrency, typing, tooling, platform
or library trade-offs, not just Core wiring. Keep integration notes separate from
language traits; avoid unsupported comparative benchmarks or superlatives.
Existing tutorials without the section remain unaudited for runtime fit.

Generic callbacks, JSON fixtures and scripted models establish Core integration
only. Compilation does not establish low latency, small size, formal correctness,
safety or regulated-domain suitability. An existing host can justify a useful
example without proving that language is uniquely suited to an industry.

Do not copy a second language solely to fill a matrix. Require a distinct host,
dependency or deployment question and testable outcome. OTP supervision requires
failure/recovery tests; Flutter claims require an exercised Flutter entry; a rule
language requires parsing/evaluation and counterexamples, not precomputed findings.
Keep generic slices honestly scoped instead of inventing ecosystem advantages.
This is a claim-quality gate, not a requirement to deepen every unused tutorial.

## Scenario Map

The [reference application portfolio](../project/roadmap.md#reference-application-portfolio)
defines the next ordered host integrations. Existing source paths and their
capabilities are indexed in the [catalog](tutorial-catalog.md); the roadmap's host
names are proposals, not claims that Laravel, Spring Boot, Rails or other complete
applications already exist. Prioritize PHP first and finish one coherent path
before opening another broad language campaign.

## Extended Scenario Catalog

The [100 Agent Scenarios](agent-scenarios.md) catalog maps sixteen domains to
stable IDs and candidate language assignments. All hundred goals have related
slices, but no complete end-to-end reference application for those full goals is
recorded. Related slices are not a cross-language parity guarantee. The earlier
themes below remain discovery groupings, not a second delivery backlog; current
source paths and bounded scope come from the generated catalog.

| Scenario | Primary language(s) | Selection question |
| --- | --- | --- |
| Knowledge Q&A and document assistant | Python, TypeScript | Retrieval, citations and structured answers |
| Customer service / contact center | TypeScript, C# | Web/SSE, service identity and audit |
| Marketing content and segmentation | Python, R | Content workflow versus native segment statistics |
| Office productivity | Python, C# | Existing document or office application host |
| Sales / CRM | C#, TypeScript | Application authentication and business APIs |
| Wealth / retail finance | Java, R | Service boundaries and computed risk evidence |
| Insurance claims | Python, Java | Document evidence and human-review boundaries |
| Procurement / ERP | Java, C# | Existing enterprise services and authority |
| Factory / manufacturing | C++, Rust | Actual device SDK or edge transport |
| Industrial automation | C++, Rust, Octave | Device integration versus signal analysis |
| Consumer electronics | Lua, C, Rust, Zig | Existing host and resource constraints |
| Robotics | C++, Rust, Julia | Simulator, device transport and numerical dependencies |
| Logistics | Go, Java | Event-driven services and application-owned recovery |
| Energy / grid | Rust, C++, Julia | Edge integration versus executable optimization |
| Security / SOC | Go, Perl, PowerShell | Services, native logs and Windows operations |
| Healthcare scheduling | C#, Java | Identity, review and application scheduling boundary |
| Legal / compliance | Python, R | Citations and evidence, not legal conclusions |
| Education / tutoring | TypeScript, Python | Web entry and bounded teaching content |
| Media / content | TypeScript, Python | Streaming and explicit publication authority |
| Travel / booking | TypeScript, C# | Inventory, review and booking effects |
| Retail / e-commerce | TypeScript, Java | Existing storefront and order APIs |
| Data platform | Python, R, Julia | Native calculation with evidence-linked reports |

### Scenario Selection Rules

- Choose by host/runtime fit, available tools and a concrete task, not example count.
- Keep basic slices bounded, deterministic and credential-free, with denial or failure checks.
- Keep business contracts and synthetic data outside Core and `spec/`.
- Identity, durable state, approvals and effect reconciliation remain application-owned.
- Add Core APIs only after a consumer demonstrates a reusable gap.
- A passing tutorial is integration evidence, not adoption or production readiness.

## Current Status

Use one revision-scoped CI snapshot rather than duplicated pending/running labels
for each catalog entry. At `dfdfd558`, tutorial run `45537631891` passed all of its
jobs, including the new Java, Swift, Objective-C, native compiled-language slices,
runtime-aligned paths and shared-service integrations. The [workflow](https://github.com/axisvela/praxo-core/blob/dfdfd55873368c921fed29ad201d20986a935866/.github/workflows/ci-tutorials.yml)
defines each command and runner; success is not proof of arbitrary later revisions.

| Evidence | Current scope | Remaining limits |
| --- | --- | --- |
| Basic scenario batch | Source entries plus passing tutorial CI at `dfdfd558` | Not hundred full applications, live models or independent consumers |
| Runtime-aligned paths | V preflight, D parsing, Haskell rules, OCaml diagnostics, OTP recovery, Julia dispatch, Octave vibration, COBOL reconciliation and Zig budget jobs passed | Bounded fixtures; no production availability, solver certification or hardware safety |
| Java, Swift and Objective-C | Tutorial runtime jobs passed on their configured hosted runners | Local Windows JVM/Swift limitations remain; Apple runtime evidence does not extend to every source path |
| MATLAB/Octave | Shared tutorial jobs run with Octave | Native MATLAB remains unverified |
| Delphi / Free Pascal | Tutorial jobs use Free Pascal | Commercial Delphi remains unverified |
| Shared orders service | Python/TypeScript/Java/C# CLI and C# Web integration against loopback teaching backend | Deterministic model; Java Web-to-real-backend, production identity and external adoption not established |
| Ecosystem-native reference applications | PHP has two Laravel 12 paths under `language/php/application/` (7/7 precursor, 9/9 AI-native, Core 0.8.1); a hosted DeepSeek `deepseek-flash` run recorded `model=live`, four tool steps, a model rationale, and zero publications. Elixir AI ops copilot is at `language/elixir/application` (OTP supervision, 6/6 source-mode tests); a hosted DeepSeek run recorded model-selected tools, diagnosis/rationale, `agent_trace`, and zero executions. Erlang AI ops copilot is at `language/erlang/application` (OTP supervision, 6/6 source-mode tests); a hosted DeepSeek run recorded the same tool sequence, diagnosis/rationale, and zero executions. Go AI infrastructure agent is at `language/go/application` (HTTP/CLI, 8/8 tests); a hosted DeepSeek run recorded model-selected tools, 350-character diagnosis, 523-character rationale, `agent_trace`, and zero executions. Rust AI edge gateway agent is at `language/rust/application` (CLI, `GatewayAdapter`, 6/6 tests); live is blocked by the local TLS backend build. Java AI commerce source is at `language/java/application` (Spring Boot, Core 0.11.0) with trace/rationale but no local compile or live run | PHP live run used a custom cURL transport for proxy/CA; Elixir local Hex hit unknown CA and CI uses published Hex; Erlang compiles Core source; Go uses a local module replace; Rust uses a local path dependency and blocked TLS build; Java local JVM blocked; PHP/Java/Elixir/Erlang/Go/Rust CI jobs added but not run; no Drupal host, payment, production identity, independent consumer or production deployment; C++ and priorities 6-8 proposed |

Earlier local verification and CI failures remain historical evidence; the later
passing run does not erase them. See [Verification Evidence](../project/verification-evidence.md)
for exact runs and scope. In particular, CI does not establish a live provider,
public hosted business service, production readiness or independent adoption.

## Shared Business Services

The public MIT [agent-tutorial-services](https://github.com/axisvela/agent-tutorial-services)
backend runs on loopback, without a hosted endpoint. Python, TypeScript, Java and
C# order tutorials share its synthetic contract while retaining native Core,
tools, policy and model adapters. Core CI pins an immutable public backend
revision and needs no private token. The original `demo-repository` stays private;
do not copy business service code into Core or `spec/`.

## Tutorial Delivery Standard

Every implemented tutorial should provide:

1. A named task, explicit non-goals and runtime-selection rationale.
2. A deterministic mode without provider credentials or public services.
3. An optional live-model path reusing the same tools; if absent, say so rather than implying verification.
4. Denial or dependency-failure checks with zero unintended effects.
5. Application-owned identity, persistence, approval and effect-reconciliation boundaries.
6. Exact install/run commands, expected output and nonzero failure behavior.
7. A CI-executable test entry and pinned dependency versions.
8. Separate source, local, CI, live-provider and independent-reproduction evidence.

Reference applications additionally require a real host entry, useful end-to-end
task and separately runnable live-model path under the roadmap's acceptance
criteria. Do not expand Core or wire APIs for application-specific logic.

## Next Work

1. Complete the PHP Laravel path: run the added CI job, record the revision-bound result, and seek consumer reproduction before starting Java.
2. Use the host's actual service, identity and business boundaries; publish deterministic and live-model commands separately.
3. Record denial, dependency failure and host/runtime behavior, then seek consumer reproduction and continued use.
4. Use the bounded selection benchmark to identify friction in those paths, not as a prerequisite for application delivery.

Retain useful basic slices. New host depth should establish ecosystem value, not
increase the language count or require every existing tutorial to be rewritten.
