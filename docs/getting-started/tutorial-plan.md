# Tutorial Plan

Browse the [unified Tutorial Catalog](tutorial-catalog.md) by industry, language,
scenario and capability. It combines this plan's earlier themes, the hundred
candidate goals, existing application tutorials, guides, recipes and mechanism
examples with separate counts. This page retains delivery standards and scoped
verification status rather than duplicating that inventory.

**Status:** public planning reference, 2026-11-23. This page records delivery
standards and scoped application-tutorial status. It is not a release schedule or a
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

## Language Selection Gate

The current phase prioritizes batch delivery of basic scenario entry points,
discovery and attracting users. Complete useful, accurately scoped starting
paths before broad optimization; use actual usage feedback to choose deeper
work. A short, honest runtime rationale is sufficient for a Core integration
example. This gate does not require a demonstrated ecosystem advantage or a
named consumer before publishing such an example.

Every new or substantially revised tutorial must include a section titled
`Why this language and runtime?`. A candidate language assignment is a discovery
hint, not a recommendation, comparative advantage or integration evidence.
Existing tutorials without this section remain unaudited for runtime fit.

The section must answer all of these questions:

- **Selection basis:** Which existing host, libraries, deployment constraints or
  named consumer justify keeping execution in this runtime?
- **Demonstrated fit:** Which specific code path and test actually exercise that
  integration? Separate implemented behavior from a possible future integration.
- **Choose when:** What concrete application conditions make this path useful?
- **Do not choose when:** When would a simpler workflow or another runtime be a
  better starting point? Identify alternatives without unsupported rankings.
- **Evidence limit:** Is this Core integration only, an exercised ecosystem
  integration, or an independently reproduced consumer integration?

Language-level guidance must describe the language and ecosystem itself, not only how
the Core is wired. State relevant runtime, concurrency, typing, tooling, platform or
library characteristics and their trade-offs. Do not invent superlatives or comparative
benchmarks. Keep Praxo integration notes separate from language traits so pages do not
become interchangeable.

"This language can implement the task" is insufficient. Generic tool callbacks,
JSON fixtures and a scripted model establish Core integration only. Compilation
does not establish low latency, small deployment size, safety, formal correctness
or suitability for a regulated domain. An existing host can justify an integration
example without proving the language is uniquely suited to the business task.

Do not add a second-language copy solely to fill the scenario matrix. Require a
distinct host integration, dependency or deployment question and a testable
outcome first. For example, OTP supervision needs a supervised failure/recovery
test; a Flutter claim needs an exercised Flutter entry; a structured-rule claim
needs actual parsing/evaluation and counterexamples, not precomputed findings.
Retain useful generic slices as Core integration examples instead of inventing
ecosystem advantages for them.

This gate is a claim-quality requirement, not a mandate to deepen every tutorial.
Keep useful low-cost discovery examples even without an established consumer,
but label their conditional runtime fit honestly. Invest in deeper host behavior
when a named consumer, reproduction attempt or concrete usage feedback identifies
the need. Basic runnable commands and truthful behavior claims remain required
regardless of adoption; comprehensive depth audits are not a prerequisite for
publishing an accurately scoped integration example.

## Scenario Map

| Language / ecosystem | Tutorial outcome | Distinct value | Shared backend |
| --- | --- | --- | --- |
| Java | Order exception review | Enterprise Web entry, JUnit, published Maven Core | Orders |
| Python | Onboarding checklist and ticket draft | Retriever/structured output and application service shape | Onboarding (planned) |
| TypeScript | Customer support reply with streaming | Front-end/Node integration and SSE | Orders |
| C# | Employee or order service desk | ASP.NET Core, OIDC-ready service boundary | Orders; HR planned |
| Go | Incident coordination | Reference Core, application-owned source, event sink for telemetry | Implemented; local fixture checks pass |
| PowerShell | Windows service/disk diagnostics | Fixed read-only native operations, local machine checks | None (local diagnostics) |
| Perl | Log and batch inspection | Native text processing and legacy automation | Operations planned |
| COBOL | Banking batch exception review | Deterministic batch path and review boundary | Existing batch fixture |
| Fortran | Simulation diagnostics | Numerical evidence before model interpretation | Implemented; local fixture checks pass |
| Julia | Experiment comparison | Native numerical work and experiment drafts | Analysis planned |
| R | Data quality and statistical report | Native statistics with evidence-linked narrative | Analysis planned |
| Octave / MATLAB | Signal and sensor trend review | Native matrix/signal processing; Octave vs MATLAB evidence split | Analysis planned |
| Lua | Embed in an existing host | Host callbacks and small-footprint integration | Host-specific |
| Rust | IoT gateway diagnosis | Edge deployment, explicit read-only adapter contract, process plugins | Implemented and CI verified |
| Zig | Small gateway health check | Minimal deployment and explicit platform limits | Implemented and CI verified |
| C | Constrained host diagnostic component | Caller-owned memory/network/transport contract | Implemented; local fixture checks pass |
| C++ | Industrial edge maintenance | Existing device SDK wrapped as scoped tools | Implemented; local fixture checks pass |

These are candidate paths. A language moves from candidate to implemented only
when its tutorial has runnable commands, tests, and recorded evidence.

## Extended Scenario Catalog

The [100 Agent Scenarios](agent-scenarios.md) catalog adds stable IDs across sixteen
domains, bounded acceptance and candidate assignments for all 31 current Core
entries. Its full scenarios are candidates; related existing slices do not count
as completed end-to-end applications. The second batch (CY, CT, TL, MD, LJ, BE,
AE and OG) explicitly separates candidate outcomes, existing related slices and
full-implementation status. No full implementation of these hundred goals is
currently recorded.

The catalog below broadens the application map without creating a commitment to
build every entry. Choose the primary language by runtime fit, available tools,
and a named consumer; keep the tutorial boundary narrow.

| Scenario | Primary language(s) | Why this language/ecosystem | Status |
| --- | --- | --- | --- |
| Knowledge Q&A and document assistant | Python, TypeScript | Retrieval, citations, structured answers, streaming UI | Python office Q&A implemented and CI verified |
| Customer service / contact center | TypeScript, C# | Web/SSE, ASP.NET Core, identity and audit | TypeScript customer-support implemented and CI verified |
| Marketing content and segmentation | Python, R | Content workflows plus native statistical segments | R marketing segmentation implemented (local; CI job added, not yet run); Python content workflow planned |
| Office productivity | Python, C# | Documents, email/calendar tools, .NET integration | Python office Q&A next |
| Sales / CRM | C#, TypeScript | Enterprise authentication and web integration | C# sales/CRM implemented and CI verified |
| Wealth / retail finance | Java, R | Service boundaries plus risk/return analysis | Java wealth review CI verified; R wealth analysis implemented (local; CI job added, not yet run) |
| Insurance claims | Python, Java | Document extraction, approval, audit boundaries | Python claims triage implemented (local; CI job added, not yet run); Java planned |
| Procurement / ERP | Java, C# | Enterprise systems and application-owned identity | Planned |
| Factory / manufacturing | C++, Rust | OPC UA/device SDK seams, edge deployment | Rust gateway adapter fixture implemented and CI verified; real OPC UA/device SDK planned |
| Industrial automation | C++, Rust, Octave | Device SDK plus signal analysis | Planned |
| Consumer electronics | Lua, C, Rust, Zig | Host embedding, constrained runtime, gateway | Lua host embedding, Rust gateway fixture and Zig gateway health implemented and CI verified |
| Robotics | C++, Rust, Julia | ROS 2 integration, control and numerical analysis | Planned |
| Logistics | Go, Java | Event-driven services and long-running operations | Go logistics checkpoint/resume implemented (local; CI job added, not yet run); Java planned |
| Energy / grid | Rust, C++, Julia | Edge constraints and numerical analysis | Planned |
| Security / SOC | Go, Perl, PowerShell | Services, logs and Windows operations | Go SOC alert triage and evidence-vault implemented (local; CI jobs added, not yet run); Perl/PowerShell planned |
| Healthcare scheduling | C#, Java | Identity, audit and enterprise integration | C# healthcare scheduling implemented (local; CI job added, not yet run); Java planned |
| Legal / compliance | Python, R | Citations, evidence, human-review boundaries | Python legal compliance memo implemented (local; CI job added, not yet run); R planned |
| Education / tutoring | TypeScript, Python | Web Q&A and content workflows | Python education tutoring implemented with Core `Retriever` (local; CI job added, not yet run); TypeScript planned |
| Media / content | TypeScript, Python | Streaming, generation and publishing tools | Planned |
| Travel / booking | TypeScript, C# | Web entry and enterprise booking boundaries | TypeScript travel booking implemented (local; CI job added, not yet run); C# planned |
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
| Ruby FinOps review (SE-07) | Native Ruby Core, tool-computed idle-cost candidate, two-tool review loop | Local source-mode tests pass; CI job added, not yet run | Synthetic two-resource fixture only; no cloud writes, live model, durable memory or verified savings |
| PHP API orchestration (SE-08) | Native PHP Core, two synthetic upstream APIs, review-only mapping draft | Local PHP 8.5 lint/test pass; CI job added, not yet run | No network, credentials, upstream writes, live model or autonomous API discovery |
| Dart meeting coordination (OP-02) | Source Dart Core, fixed calendar evidence, review-only minutes/task draft | Local Dart checks pass; CI job added, not yet run | No calendar API, invitations, attendee identity, live model or durable state |
| Haskell literature review (SC-01) | Source Haskell Core, fixed paper corpus, unverified hypothesis draft | Local runghc checks pass; CI job added, not yet run | No live literature API, citation validation, scientific-validity claim or durable state |
| Nim maintenance triage (IN-01) | Source Nim Core, fixed sensor telemetry, review-only work order | Local nim compile/run checks pass; CI job added, not yet run | No sensor transport, validated failure prediction, dispatch, live model or durable state |
| D executive brief (OP-07) | Source D Core, fixed business variances, review-only brief | Local DMD checks pass; CI job added, not yet run | No metric warehouse, attribution, sends, live model or durable state; D reports `POLICY_ERROR` for denial |
| V production scheduling (IN-02) | Source V Core, fixed job queue, review-only MES/AGV draft | Local V compile/run checks pass; CI job added, not yet run | No ERP/MES data, physical dispatch, live model or durable state |
| Elixir knowledge maintenance (OP-03) | Source Elixir Core, fixed knowledge diff, review-only revision | Local elixirc/elixir checks pass; CI job added, not yet run | No document store, dedup quality, Wiki writes, live model or durable state |
| Erlang AIOps RCA (SE-06) | Source Erlang Core, fixed correlated signals, review-only rollback | Local erlc/escript checks pass; CI job added, not yet run | No live telemetry, root-cause scoring, remediation, live model or durable state |
| OCaml code review (SE-05) | Source OCaml Core, fixed diff/manifest findings, review-only comments | Local `ocaml unix.cma` checks pass; CI job added, not yet run | No real repository, vulnerability database, host writes, live model or durable state |
| Delphi legacy migration (SE-03) | Source Delphi/Free Pascal Core, fixed module inventory, review-only plan | Local Free Pascal 3.2.2 checks pass; CI job added, not yet run | No real dependency graph, automated refactoring, production migration, live model or durable state; commercial Delphi unverified |
| Objective-C privacy agent (PE-03) | Source Objective-C Core, fixed exposure classification, review-only deletion request | Local GNUstep clang checks pass; macOS CI job added, not yet run | No password handling, account access, deletion execution, live model or durable state; Apple Foundation runtime unverified locally |
| TypeScript retail replenishment (CS-05) | Native Core, fixed stock/pricing fixture, review-only purchase order | Local Node 24 checks and offline `npm ci` pass; CI job added, not yet run | No live inventory, pricing change, supplier API, procurement submission, live model or durable state |
| Go zero-trust review (CY-05) | Reference Go Core, fixed access events, review-only permission narrowing | Local `go test`/`go run --test` pass; CI job added, not yet run | Fixed event fixture only; no identity provider, live grants, policy engine, live model or durable state |
| PHP internal service desk (OP-01) | Native PHP Core, fixed employee request, review-only approval | Local PHP 8.5 lint/test pass; CI job added, not yet run | No identity provider, HR/IT connector, provisioning, live model or durable state |
| Delphi RPA reconciliation (OP-04) | Source Delphi/Free Pascal Core, fixed PO/invoice delta, review-only exception | Local Free Pascal 3.2.2 checks pass; CI job added, not yet run | No ERP connector, matching rules, postings, live model or durable state; commercial Delphi unverified |
| Ruby recruiting match (OP-05) | Native Ruby Core, fixed candidate matching, review-only shortlist | Local source-mode checks pass; CI job added, not yet run | Fixed candidate fixture only; no consent, outreach, hiring decision, live model or durable state |
| D quantitative risk (FC-02) | Source D Core, fixed exposure versus risk limit, review-only order | Local DMD checks pass; CI job added, not yet run | No market feed, trade, order routing, risk certification, live model or durable state |
| Dart onboarding plan (OP-06) | Source Dart Core, fixed employee profile, review-only learning path | Local Dart checks pass; CI job added, not yet run | No HR system, permissions, provisioning, live model or durable state |
| Python credit diligence (FC-03) | Native Core, fixed ratios and risk, review-only memo | Local Python 3.14 checks pass; CI job added, not yet run | No bureau/KYC/fraud graph, credit decision, live model or durable state |
| OCaml contract review (FC-05) | Source OCaml Core, fixed clauses and redlines, review-only revision | Local `ocaml unix.cma` checks pass; CI job added, not yet run | No document store, clause extraction, legal advice, live model or durable state |
| Python clinical guidelines (HC-01) | Native Core, fixed guideline citations, review-only summary, abstain | Local Python 3.14 checks pass; CI job added, not yet run | No patient records, clinical validation, diagnosis, live model or durable state |
| OCaml BOM review (IN-05) | Source OCaml Core, fixed parsed drawing and conflicts, review-only BOM | Local `ocaml unix.cma` checks pass; CI job added, not yet run | No CAD/BIM parsing, engineering certification, manufacturing, live model or durable state |
| Python trial screening (HC-03) | Native Core, fixed patient criteria, review-only screening note | Local Python 3.14 checks pass; CI job added, not yet run | No real patient search, consent workflow, enrollment, live model or durable state |
| PHP public approval (CT-03) | Native PHP Core, fixed application documents, review-only parallel tasks | Local PHP 8.5 lint/test pass; CI job added, not yet run | No identity verification, document upload, agency systems, official approval or live model |
| Go pentest lab review (CY-01) | Go reference Core, fixed loopback lab host, review-only defect report | Local Go vet/run/test pass; CI job added, not yet run | No public scanning, exploit chain, defect validation, approval or live model |
| Lua storyboard previs (MD-01) | Lua Core, fixed scene, review-only shot plan with zero renders | Local Lua 5.4 checks pass; CI job added, not yet run | No Unreal integration, media generation, licensing or rendered production |
| C++ traffic signal plan (CT-01) | C++ Core, fixed junction queues, review-only timing within limits | Local MinGW build/test pass; CI job added, not yet run | No signal command, live traffic control, city-scale simulation or live model |
| Zig drone fleet plan (TL-01) | Zig Core, fixed drone waypoints, review-only plan with conflict review | Local `zig run` checks pass (`build-exe` binary quarantined locally); CI job added, not yet run | No flight, avoidance, geofence command or airspace certification |
| Python phishing awareness (CY-04) | Native Core, fixed email indicators, review-only exercise | Local Python 3.14 checks pass; CI job added, not yet run | No live inbox, URL detonation, deceptive sends or infrastructure attack |
| Ruby supply-chain review (CY-07) | Native Core, fixed manifest signals, reviewed version pin | Local Ruby checks pass; CI job added, not yet run | No registry write, dependency update, quarantine or proven malware verdict |
| Rust construction safety (BE-01) | Native Core, fixed inspection labels, review-only remediation checklist | Local cargo build/test pass; CI job added, not yet run | No vision, field access, certified safety finding or remediation authority |
| Perl news fact-check (MD-02) | Native Core, fixed source excerpts, review-only check with cited contradiction | Local Perl checks pass; CI job added, not yet run | No live news crawl, truth guarantee, editorial verdict or publication |
| Go emergency route plan (CT-04) | Go reference Core, fixed closures, review-only relief allocation | Local Go vet/run/test pass; CI job added, not yet run | No live traffic data, operational rescue direction, dispatch or route-safety guarantee |
| Python patent FTO (LJ-02) | Native Core, fixed claim overlap, review-only counsel questions | Local Python 3.14 checks pass; CI job added, not yet run | No exhaustive patent search, claim-chart analysis or non-infringement opinion |
| Ruby community governance (OG-04) | Native Core, fixed issue classes, review-only reviewer request | Local Ruby checks pass; CI job added, not yet run | No automatic closure, maintainer impersonation, moderation or live GitHub access |
| Lua world economy (MD-03) | Lua Core, fixed economy tick, review-only balance with no applied change | Local Lua 5.4 checks pass; CI job added, not yet run | No population scale, equilibrium guarantee or real game-engine integration |
| OCaml architecture graph (OG-01) | OCaml Core, fixed asset graph, review-only change findings | Local OCaml checks pass; CI job added, not yet run | No CMDB discovery, production scanning, standards enforcement or change blocking |
| Python pollution tracing (CT-05) | Native Core, fixed sensor records, review-only investigation hypotheses | Local Python 3.14 checks pass; CI job added, not yet run | No live monitoring, causal attribution, inspection or enforcement finding |
| Lua live show (MD-07) | Lua Core, fixed engagement replay, review-only presentation order | Local Lua 5.4 checks pass; CI job added, not yet run | No audience profiling, coupon sends, promotion or real stream control |
| Dart waste collection (CT-06) | Dart Core, fixed collection queue, review-only schedule under vehicle limits | Local Dart checks pass; CI job added, not yet run | No telemetry, vehicle command, live dispatch or capacity guarantee |
| TypeScript negotiation interpretation (OG-03) | TypeScript Core, fixed transcript and terminology, review-only notes | Local Node checks pass; CI job added, not yet run | No micro-expression inference, mind reading, live interpretation or cultural profiling |
| Python biodiversity alerts (AE-05) | Native Core, fixed labeled observations, review-only ranger alert | Local Python 3.14 checks pass; CI job added, not yet run | No species-recognition guarantee, automatic pursuit or ranger dispatch |
| R budget review (CT-07) | Native R Core, fixed budget execution, review-only performance finding | Local R checks pass; CI job added, not yet run | No real ledger data, official audit judgment or reporting |
| PHP copyright evidence (LJ-05) | Native PHP Core, fixed authorized assets, review-only evidence packet | Local PHP 8.5 lint/test pass; CI job added, not yet run | No broad crawl, automatic DMCA notice, takedown or infringement adjudication |
| Ruby due diligence (LJ-03) | Native Core, fixed ownership/contracts/disputes, review-only risk checklist | Local Ruby checks pass; CI job added, not yet run | No verified acquisition conclusion, valuation or legal opinion |
| Python dubbing plan (MD-04) | Native Core, fixed licensed media, review-only caption and timing plan | Local Python 3.14 checks pass; CI job added, not yet run | No audio synthesis, impersonation, voice cloning or verified lip-sync |
| PHP tender review (BE-04) | Native PHP Core, fixed bid qualifications, review-only similarity flags | Local PHP 8.5 lint/test pass; CI job added, not yet run | No automatic bid submission, qualification decision or collusion verdict |
| R hedge plan (AE-04) | Native R Core, fixed exposure and scenario margins, review-only plan | Local R checks pass; CI job added, not yet run | No futures orders, price lock, market execution or financial advice |
| Dart audiobook production (MD-06) | Dart Core, fixed licensed book, review-only production plan | Local Dart checks pass; CI job added, not yet run | No audio synthesis, voice cloning, mixing or rights guarantee |
| C++ EDA placement (OG-05) | C++ Core, fixed placement grid, review-only layout with stated proxies | Local MinGW build/test pass; CI job added, not yet run | No foundry-valid layout, DRC/LVS sign-off, measured PPA or tapeout |
| Dart digital twin memory (OG-06) | Dart Core, consent-scoped synthetic memory, in-process store/recall/delete | Local Dart checks pass; CI job added, not yet run | No real inbox, passwords, cross-app access, durable store or unrestricted recall |
| Go litigation timeline (LJ-01) | Go reference Core, fixed documents, review-only evidence outline | Local Go vet/run/test pass; CI job added, not yet run | No real case files, privilege review, legal advice or admissibility ruling |
| Python precedent outline (LJ-04) | Native Core, fixed precedents, review-only cited outline | Local Python 3.14 checks pass; CI job added, not yet run | No live legal database, citation validation, sentencing or judicial decision |
| R property forecast (BE-05) | Native R Core, fixed site metrics, review-only forecast with assumptions | Local R checks pass; CI job added, not yet run | No verified probability, return guarantee, valuation or location profiling |
| Python virtual PI (OG-07) | Native Core, fixed research tasks, shared budget and review-only coordination | Local Python 3.14 checks pass; CI job added, not yet run | No external tools, autonomous research or scientific-validity claim |
| R fire spread (AE-02) | Native R Core, fixed weather/fuel cells, review-only spread report | Local R checks pass; CI job added, not yet run | No operational warning, validated fire model, evacuation or firebreak dispatch |
| Rust mining slope (BE-03) | Native Core, fixed displacement indicators, review-only alert | Local cargo build/test pass; CI job added, not yet run | No collapse prediction, evacuation, vehicle dispatch or safety certification |
| Rust livestock monitor (AE-01) | Native Core, fixed herd observations, review-only veterinary request | Local cargo build/test pass; CI job added, not yet run | No veterinary diagnosis, isolation, feeding control or sensor integration |
| C++ mesh review (MD-05) | C++ Core, fixed mesh descriptors, review-only design assessment | Local MinGW build/test pass; CI job added, not yet run | No CAD kernel, topology repair, manufacturability analysis or mechanical certification |
| Lua aquaculture water (AE-03) | Lua Core, fixed oxygen/temperature indicators, review-only action | Local Lua 5.4 checks pass; CI job added, not yet run | No operating sensors, actuator access, aerator/feeder command or water-quality guarantee |
| Go customs reroute (TL-05) | Go reference Core, fixed documents, review-only route draft | Local Go vet/run/test pass; CI job added, not yet run | No customs filing, network access, compliance determination or route execution |
| Rust cold chain (TL-04) | Native Core, fixed temperature excursions, review-only transfer review | Local cargo build/test pass; CI job added, not yet run | No refrigeration control, actuator access, cargo-integrity or clinical guarantee |
| C++ ocean routing (TL-03) | C++ Core, fixed route/weather costs, review-only route | Local MinGW build/test pass; CI job added, not yet run | No weather routing, navigation command, fuel-savings or CII compliance claim |
| D fleet map (TL-06) | Native Core, fixed topology changes, review-only map patch | Local dmd `-run` checks pass; CI job added, not yet run | No vehicle takeover, remote assistance, map deployment or live fleet access |
| Haskell policy simulation (OG-02) | Haskell Core, fixed synthetic population, review-only sensitivity report | Local runghc checks pass; CI job added, not yet run | No tens-of-thousands scale, calibrated simulator or real policy prediction |
| Delphi HVAC settings (BE-02) | Delphi/Free Pascal Core, fixed building environment, review-only settings plan | Local fpc build/test pass; CI job added, not yet run | No BMS command, occupancy surveillance, energy modeling or savings guarantee |
| Rust leak localization (CT-02) | Native Core, fixed pressure anomalies, review-only inspection list | Local cargo build/test pass; CI job added, not yet run | No hydraulic model, valve isolation, field dispatch or leak guarantee |
| C++ container yard (TL-02) | C++ Core, fixed container jobs, review-only schedule | Local MinGW build/test pass; CI job added, not yet run | No crane/AGV command, terminal feed, safety interlock or throughput guarantee |
| Ruby lead nurture (CS-02) | Native Core, fixed business profiles, review-only opt-in outreach | Local Ruby checks pass; CI job added, not yet run | No crawling, scraping, consent automation or unsolicited sends |
| Python molecule screen (SC-02) | Native Core, fixed molecular descriptors, review-only assessment | Local Python 3.14 checks pass; CI job added, not yet run | No docking, ADMET prediction, synthesis or clinical claim |
| Rust lab loop (SC-03) | Native Core, fixed parameter/result loop, review-only next parameters | Local cargo build/test pass; CI job added, not yet run | No instrument actuator, chemical handling, safety interlock or closed-loop control |
| TypeScript localization draft (CS-07) | TypeScript Core, fixed localization rules, review-only localized text | Local Node checks pass; CI job added, not yet run | No legal/tax compliance guarantee, live content system or publication |
| Python CBT exercise (HC-05) | Native Core, fixed CBT exercise, explicit human-review escalation branch | Local Python 3.14 checks pass; CI job added, not yet run | No therapist replacement, diagnosis, live session or unsupervised crisis handling |
| Rust household robot (PE-04) | Native Core, fixed robot observation, review-only bounded action | Local cargo build/test pass; CI job added, not yet run | No perception, motion planning, hardware command, safety interlock or certification |
| Dart chronic care (HC-02) | Dart Core, fixed wearable trends, review-only care alert | Local Dart checks pass; CI job added, not yet run | No device integration, dosage change, treatment decision or clinical claim |
| Haskell test generation (SE-04) | Haskell Core, fixed local fixture, review-only test suite | Local runghc checks pass; CI job added, not yet run | No test execution, coverage measurement, network load or verified result |
| Go fullstack workspace (SE-01) | Go reference Core, fixed allowlisted workspace, bounded edit and fixture diagnostics | Local Go vet/run/test pass; CI job added, not yet run | No host filesystem access, real compiler, deployment or production workspace |
| C# medical coding (HC-04) | Native Core, fixed record completeness, review-only code draft | Local dotnet build/run pass; CI job added, not yet run | No billing submission, reimbursement optimization, false coding or clinical audit |
| C# airport recovery (TL-07) | Native Core, fixed gate/crew/connection constraints, review-only options | Local dotnet build/run pass; CI job added, not yet run | No airport operations, crew legality, live schedule or latency guarantee |
| PHP lead nurture (CS-02) | Native PHP Core, fixed business profiles, review-only opt-in outreach | Local PHP 8.5 lint/test pass; CI job added, not yet run | No crawling, scraping, consent automation or unsolicited sends |
| TypeScript workspace plan (SE-01) | TypeScript Core, fixed allowlisted workspace, bounded edit and fixture diagnostics | Local Node checks pass; CI job added, not yet run | No host filesystem access, real compiler, deployment or production workspace |
| C# test generation (SE-04) | Native Core, fixed local fixture, review-only test suite | Local dotnet build/run pass; CI job added, not yet run | No test execution, coverage measurement, network load or verified result |
| PHP localization draft (CS-07) | Native PHP Core, fixed localization rules, review-only localized text | Local PHP 8.5 lint/test pass; CI job added, not yet run | No legal/tax compliance guarantee, live content system or publication |
| Dart CBT exercise (HC-05) | Dart Core, fixed CBT exercise, explicit human-review escalation branch | Local Dart checks pass; CI job added, not yet run | No therapist replacement, diagnosis, live session or unsupervised crisis handling |
| C++ molecule screen (SC-02) | C++ Core, fixed molecular descriptors, review-only assessment | Local MinGW build/test pass; CI job added, not yet run | No docking, ADMET prediction, synthesis or clinical claim |
| D property forecast (BE-05) | Native Core, fixed site metrics, review-only forecast | Local dmd `-run` checks pass; CI job added, not yet run | No valuation, probability guarantee, return claim or location profiling |
| R weather anomaly (SC-05) | Native R Core, fixed time-series anomalies, review-only notice | Local R checks pass; CI job added, not yet run | No operational forecast, warning issuance, meteorological validation or disaster dispatch |
| Lua irrigation plan (IN-06) | Lua Core, fixed soil/weather observations, review-only request | Local Lua 5.4 checks pass; CI job added, not yet run | No soil sensors, irrigation control, drone dispatch or actuator access |
| C++ materials design (SC-04) | C++ Core, fixed candidate properties, review-only next simulation | Local MinGW build/test pass; CI job added, not yet run | No validated material, simulation physics, fabrication or property guarantee |
| PHP customs reroute (TL-05) | Native PHP Core, fixed document fields, review-only reroute | Local PHP 8.5 lint/test pass; CI job added, not yet run | No customs filing, network access, compliance determination or route execution |
| Python order review | Native Core, HTTP tool, fixed order scope, draft-only | Local and hosted CI against the public local service | Deterministic model; no live provider or external consumer |
| TypeScript order support | Native Core, HTTP tool, fixed order scope | Local and hosted CI against the public local service | Deterministic model; CLI, not a Web frontend |
| Java order review | Native Core, JUnit, loopback Web, real-service CLI | Mock/Web JUnit and real-service CLI passed in Linux CI | Java Web-to-real-backend and live model not verified |
| C# order service desk | ASP.NET Core, native Core, CLI and Web | Self-tests plus real-service CLI and Web in Linux CI | Deterministic model; no production identity |
| PowerShell Windows diagnostics | Shared C# Core through the module | Local Windows tests and hosted Windows CI | No Gallery install, repair, remote host or live model |
| Perl log triage | Native Perl Core, fixed fixture log, severity report | Local Perl 5.40.3 tests and Linux CI | No arbitrary path, shell, alert delivery or live model |
| R data quality | Native R statistics, fixed data frame, computed report | Local R 4.6.1 tests and Linux CI | No arbitrary file/SQL/shell, live model or causal claim |
| R marketing segmentation | Native R segment statistics, fixed customer fixture, draft-only campaign | Local R 4.6.1 checks pass; Linux CI job added, not yet run | Fixed customer fixture only; no message send, campaign launch, arbitrary data or live model |
| COBOL batch exception review | Reuses deterministic batch handoff; separate review worker | Local GnuCOBOL 2.0.0/Python checks and Linux CI | No real posting, durable queue, recovery proof or live model |
| Julia experiment comparison | Native Julia means/delta over fixed results | Local Julia 1.13.2 tests and Linux CI | No arbitrary data/code/package install, live model or causal claim |
| Fortran simulation metrics | Native Fortran Core, fixed ten-sample metrics, draft-only report | Local gfortran 16.2.0/RE2 checks pass; Linux CI job added, not yet run | Fixed metric fixture only; no arbitrary dataset, interpreted model code, package install, publication or live model |
| Octave/MATLAB signal trends | Shared signal metrics, threshold anomalies | Local GNU Octave 11.3.0 tests and Linux CI | Native MATLAB unverified; no device control or live model |
| Python office Q&A | Native Core, fixed documents, citation-bearing answer | Local Python 3.14 checks and Linux CI | No arbitrary file/connector, email action or live model |
| Python insurance claims | Native Core, application-owned claim tool, draft-only decision, `StructuredOutput` schema check | Local Python 3.14 checks pass; Linux CI job added, not yet run | Fixed claim fixture only; no payment, coverage decision, real claims system or live model |
| Python legal compliance | Native Core, fixed policy citations, HITL approval gate, simulated publish | Local Python 3.14 checks pass; Linux CI job added, not yet run | Fixed policy fixture only; no real approval record, document store, legal advice or live model |
| Python education tutoring | Native Core, application-owned `Retriever` (`Document`), draft-only study plan | Local Python 3.14 checks pass; Linux CI job added, not yet run | Fixed lesson corpus only; no student data, assignment creation, curriculum guarantee or live model |
| TypeScript customer support | Native Core, fixed order/policy tools, SSE stream | Local Node 24 checks and Linux CI | No reply send, order change, refund or live model |
| Java wealth review | Native Core, fixed portfolio, draft-only rebalance | Local compile and Linux CI | No trades, transfers, market data or live model |
| C# sales/CRM | Native Core, fixed customer, draft-only follow-up | Local .NET 8 build/self-test and Linux CI | No CRM write, email send or live model |
| C# healthcare scheduling | Native Core, fixed schedule, draft-only booking | Local .NET 8 build/self-test pass; Linux CI job added, not yet run | Fixed schedule fixture only; no patient identity, schedule write, confirmation or live model |
| TypeScript travel booking | Native Core, fixed inventory, draft-only fare hold | Local Node 24 checks pass; Linux CI job added, not yet run | Fixed inventory fixture only; no payment, ticketing, inventory write or live model |
| Lua host embedding | Native Lua Core, host callbacks, draft-only action | Local Lua 5.4.6 checks and Linux CI | No device command, socket or live model |
| Rust IoT gateway | Native Rust Core, read-only `GatewayAdapter`, draft-only action | Local Rust checks and Linux CI | In-process adapter fixture only; no MQTT, OPC UA, socket, device write or live model |
| Zig gateway health | Native Zig Core, read-only `GatewayAdapter` function table, draft-only action | Local Zig 0.17.0 checks and Linux CI | In-process adapter fixture only; no MQTT, OPC UA, socket, device write or live model |
| Go incident coordination | Reference Go Core, application-owned `IncidentSource`, draft-only action, `event.FuncSink` telemetry | Local `go test`/`go run --test` pass; Linux CI job added, not yet run | In-process source and event sink fixtures only; no real incident system, durable workflow, live model or incident write |
| Go SOC alert triage | Reference Go Core, application-owned `AlertSource`, Core `PIIRedactor`, draft-only isolation, `event.FuncSink` audit | Local `go test`/`go run --test` pass; Linux CI job added, not yet run | In-process source/event fixtures only; no real SIEM, host action, live model; live tool args/errors/events not redacted |
| Go logistics checkpoint | Reference Go Core, `checkpoint.Checkpoint` round-trip, two-run resume, draft-only reroute | Local `go test`/`go run --test` pass; Linux CI job added, not yet run | In-memory JSON store only; no database, concurrent store, lease/exactly-once, real logistics system or live model |
| Go evidence vault | Reference Go Core, `vfs/localfs` confined root, path-traversal denial, draft-only finding | Local `go test`/`go run --test` pass; Linux CI job added, not yet run | Temporary vault directory only; no encrypted store, case system, production sandbox or live model |
| R wealth analysis | Native R weighted-risk/concentration metrics, fixed portfolio, draft-only rebalance | Local R 4.6.1 checks pass; Linux CI job added, not yet run | Fixed portfolio fixture only; no trades, market data, financial advice or live model |
| C device diagnostics | Native C Core, application-owned `PxDeviceAdapter` function pointer, draft-only action | Local MinGW gcc/CMake checks pass; Linux CI job added, not yet run | In-process adapter fixture only; no serial bus, socket, device SDK, device write or live model |
| C++ industrial edge | Native C++ Core, application-owned `DeviceAdapter` interface, draft-only action | Local MinGW g++/CMake checks pass; Linux CI job added, not yet run | In-process adapter fixture only; no fieldbus, OPC UA, socket, device SDK, device write or live model |

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
   independent reproduction as separate evidence levels;
9. the language-selection section required by the Language Selection Gate above.

Tutorials should not add a new Core or wire API unless a named consumer
demonstrates a reusable gap. Application-specific tools belong in the tutorial,
not in `pkg/...` or `spec/`.

## Next Work

1. Extend the device tutorials that now cover Rust, Zig, C and C++ with an
   explicit application-owned adapter contract and a deterministic fixture.
   Real MQTT, OPC UA, serial bus, device SDK or runtime validation remains a
   separate, blocked claim until that transport is actually exercised.
2. Turn each verified tutorial into a consumer test-authorized path, not just a
   maintainer demo.

Language count is not the goal. Fewer complete, differentiated paths are more
useful than many isolated mechanism checks.
