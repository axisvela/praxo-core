# 100 Agent Scenarios

These hundred goals combine two fifty-scenario batches, not the entire tutorial collection.
The [unified Tutorial Catalog](tutorial-catalog.md) includes earlier application
paths, broad themes, guides and cross-language examples, grouped by industry,
language and capability with explicit counting rules.

This catalog translates one hundred application goals across sixteen domains into bounded tutorial candidates.
It extends the [Tutorial Plan](tutorial-plan.md), not the Core API or support
promise. **All hundred full scenarios are candidates, not completed applications.**
Related tutorials below are narrower teaching slices; their exact verification
and limits remain in the plan. Language assignments are proposed implementation
targets, not new maintainership or delivery commitments.

## The Agent Loop

Each implementation should show a bounded plan, application-owned state, a tool
result, and a subsequent decision based on that result. A single scripted tool
call is a mechanism demonstration, not autonomous end-to-end task completion.

Planning may be deterministic for reproducibility. Persisted observations remain
untrusted data; a Memory Store is not automatic recall. Checkpoint continuation
is not crash-step recovery, an effect ledger, or exactly-once execution. State
must be isolated by consumer, tenant and run. Reauthorize final arguments after
approval edits; scope, call budgets and cancellation remain explicit.

## Status Key

- **Candidate**: full scenario has not been implemented or verified here.
- **Related slice**: an existing narrower tutorial can be reused, not counted as
  completion of the full scenario.
- **Targets**: languages selected for runtime fit; actual feature availability
  follows [language support](../languages/support.md) and per-SDK parity.
- **Full implementation: Not implemented**: no accepted end-to-end implementation
  of the entire described goal is recorded. A related slice or mechanism does not
  change this status. Current full implementations: **0 of 100**.

The first eight domains retain their IDs. The next eight domains explicitly
separate candidate outcomes, related slices and full-implementation status.

Repository links in the tables point to source on `main`, not immutable run evidence.

## Software And IT (8)

| ID | Scenario | Targets | First bounded tutorial outcome / related slice |
| --- | --- | --- | --- |
| SE-01 | End-to-end full-stack development | TypeScript, Go, Dart | Plan a tiny application, edit an allowlisted temporary workspace, build and inspect diagnostics; no deployment |
| SE-02 | Bug diagnosis and repair | Python, Rust, Perl | Reproduce a seeded defect, draft a patch and rerun tests; PR creation requires separate authorization |
| SE-03 | Legacy refactoring and migration | COBOL, Java, Delphi | Produce a dependency inventory and migration draft with unchanged fixture outputs; no automatic production migration |
| SE-04 | Unit-test and load-test generation | Java, C#, Haskell | Generate bounded tests for a local fixture and record results; load only an explicit loopback target |
| SE-05 | Code review and security/license audit | Rust, OCaml, Go | Review a fixed diff and dependency manifest, cite findings and uncertainty; [evidence vault](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/evidence-vault) is a containment slice |
| SE-06 | AIOps RCA and remediation | Go, Elixir, Erlang | Correlate fixture events and draft an approval-gated rollback; [incident coordination](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/incident-coordination) is read/draft only |
| SE-07 | Cloud and FinOps governance | Ruby, PowerShell, D | [Ruby cost-review slice](https://github.com/axisvela/praxo-core/tree/main/language/ruby/Tutorial/finops-review) computes idle-resource costs and drafts a review; no real cloud mutation or credentials; other targets candidate |
| SE-08 | API orchestration and integration | PHP, Java, TypeScript | Map two synthetic APIs, validate schemas and reconcile failure; no arbitrary URL access; [PHP API-orchestration slice](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/api-orchestration) covers two fixture APIs and a review draft |

## Enterprise Operations (7)

| ID | Scenario | Targets | First bounded tutorial outcome / related slice |
| --- | --- | --- | --- |
| OP-01 | Internal IT and HR service desk | C#, PHP, PowerShell | Scope an employee request and draft an approval; [order service desk](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/order-review) does not grant employee permissions |
| OP-02 | Meeting lifecycle management | Dart, Swift, TypeScript | Reconcile fixed calendars, draft minutes/tasks and ask before invitations; [Dart meeting-coordination slice](https://github.com/axisvela/praxo-core/tree/main/language/dart/Tutorial/meeting-coordination) covers calendar evidence and a minutes draft |
| OP-03 | Dynamic enterprise knowledge maintenance | Python, Elixir, OCaml | Detect fixture document changes, deduplicate and draft a cited revision; no automatic Wiki writes |
| OP-04 | Cross-system agentic RPA | Java, C#, Delphi | Reconcile synthetic expense/procurement records and stop on an unknown effect |
| OP-05 | Recruiting and candidate matching | Ruby, PHP, Python | Match synthetic, job-relevant skills and expose explanations; no automated hiring decision or outreach |
| OP-06 | Personalized employee onboarding | Python, Dart, Swift | Plan role-specific lessons with explicit prerequisites; permissions remain application-owned |
| OP-07 | Executive operating brief | R, Julia, D | Compute fixture business deltas and cite metrics; distinguish association from causal attribution; [D executive-brief slice](https://github.com/axisvela/praxo-core/tree/main/language/d/Tutorial/executive-brief) covers fixed variances and a review draft |

## Service And Sales (7)

| ID | Scenario | Targets | First bounded tutorial outcome / related slice |
| --- | --- | --- | --- |
| CS-01 | Multimodal omnichannel customer service | TypeScript, C#, PHP | Draft a resolution from scoped order evidence; [customer support](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/customer-support) is text/SSE, not refunds or multimodal verification |
| CS-02 | B2B prospecting and lead nurture | Ruby, PHP, Elixir | Rank synthetic business profiles and draft an opt-in outreach; no crawling or unsolicited sends |
| CS-03 | Sales-call assistance and review | C#, Swift, TypeScript | Extract objections from a fixture transcript and draft a CRM update; [sales CRM](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/sales-crm) is a follow-up slice |
| CS-04 | Content marketing and publishing | Python, R, Dart | Compute audience segments, draft content and require publication approval; [marketing segmentation](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/marketing-segmentation) sends nothing |
| CS-05 | E-commerce pricing and replenishment | Java, PHP, Ruby | Simulate price/stock constraints and draft a replenishment order; no live pricing changes |
| CS-06 | Churn warning and retention | R, Elixir, Julia | Compute fixture risk signals and draft a consent-aware offer; no inferred sensitive traits or automatic contact |
| CS-07 | Cross-border localization | TypeScript, PHP, Perl | Draft localized fixture product text with cited rule checks; no legal/tax compliance guarantee |

## Finance And Compliance (6)

| ID | Scenario | Targets | First bounded tutorial outcome / related slice |
| --- | --- | --- | --- |
| FC-01 | Investment research and financial statements | R, Julia, Java | Compute ratios from synthetic statements and cite assumptions; [wealth analysis](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/wealth-analysis) is not investment research verification |
| FC-02 | Quantitative execution and risk controls | C++, Rust, D | Replay fixed prices, enforce deterministic risk limits and draft orders; no trades or millisecond-latency claim |
| FC-03 | Credit diligence and fraud review | Java, COBOL, Python | Reconcile synthetic records and produce reviewable evidence; no automated credit denial or fraud adjudication |
| FC-04 | Tax planning and filing | COBOL, Java, Delphi | Validate synthetic ledger totals and draft a filing with cited fixture rules; no real filing or tax advice |
| FC-05 | Contract lifecycle review | Python, OCaml, C# | Compare fixture clauses against a redline set and propose edits; approval edits must be reauthorized |
| FC-06 | Regulatory tracking and internal audit | Python, R, Perl | Compare versioned fixture policies and draft remediation; [legal compliance](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/legal-compliance) uses a scripted approval, not a real reviewer |

## Science And Research (6)

| ID | Scenario | Targets | First bounded tutorial outcome / related slice |
| --- | --- | --- | --- |
| SC-01 | Literature review and hypotheses | Python, Julia, Haskell | Retrieve fixed abstracts, cite claims and label hypotheses as unverified; no fabricated papers; [Haskell literature-review slice](https://github.com/axisvela/praxo-core/tree/main/language/haskell/Tutorial/literature-review) covers two fixture papers and an unverified draft |
| SC-02 | Drug and molecular design | Python, Julia, C++ | Rank synthetic descriptors under fixed constraints; no efficacy, toxicity, synthesis or clinical claim |
| SC-03 | Self-driving laboratory | Julia, Rust, C | Simulate a parameter/result loop with deterministic limits; no laboratory actuator or chemical handling |
| SC-04 | Materials inverse design and simulation | Fortran, Julia, C++ | Evaluate fixed candidate properties and draft the next simulation; no validated new material |
| SC-05 | Weather modeling and warnings | Fortran, R, Octave | Compute fixed time-series anomalies and draft a review notice; no operational forecast or disaster dispatch |
| SC-06 | Research data cleaning and statistics | R, Julia, MATLAB | Validate fixed data and compare stated statistics; [data quality](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/data-quality) is a related slice; native MATLAB remains unverified |

## Industry And Energy (6)

| ID | Scenario | Targets | First bounded tutorial outcome / related slice |
| --- | --- | --- | --- |
| IN-01 | Predictive maintenance and scheduling | C++, Rust, Nim | Compute fixed sensor indicators and draft maintenance; [industrial edge](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/industrial-edge) and [Nim maintenance-triage](https://github.com/axisvela/praxo-core/tree/main/language/nim/Tutorial/maintenance-triage) do not predict a validated failure window |
| IN-02 | Adaptive production scheduling | Erlang, C++, V | Replan a bounded synthetic job queue and draft MES/AGV instructions; no physical dispatch; [V production-scheduling slice](https://github.com/axisvela/praxo-core/tree/main/language/v/Tutorial/production-scheduling) computes a fixed priority order and draft |
| IN-03 | Supply-chain disruption and sourcing | Go, Java, Ruby | Score synthetic supplier events and draft alternatives; [logistics checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/logistics-checkpoint) is message continuation only |
| IN-04 | Microgrid dispatch and load balance | Julia, Fortran, Zig | Simulate constrained charge/discharge schedules and check limits outside the agent; no grid commands |
| IN-05 | Engineering drawing review and BOM | C++, C#, OCaml | Validate a synthetic parsed drawing graph and draft a BOM; no CAD/BIM vision or engineering certification |
| IN-06 | Precision irrigation and crop protection | C, Lua, Nim | Evaluate fixture soil/weather observations and draft a bounded irrigation request; no drones or actuators |

## Healthcare (5)

| ID | Scenario | Targets | First bounded tutorial outcome / related slice |
| --- | --- | --- | --- |
| HC-01 | Clinical and MDT support | Python, Java, R | Retrieve synthetic guideline excerpts with citations and abstain on missing evidence; no diagnosis or treatment decision |
| HC-02 | Chronic-care follow-up | Swift, Dart, Objective-C | Summarize synthetic wearable trends and route an alert for review; no dosage or individualized treatment changes |
| HC-03 | Clinical-trial recruitment | Python, Java, C# | Evaluate synthetic inclusion/exclusion predicates and explain unknowns; no real patient search or eligibility decision |
| HC-04 | Record quality and DRG/DIP coding | Java, COBOL, C# | Check synthetic record completeness and draft codes; no reimbursement optimization, false coding or billing submission |
| HC-05 | Mental-health support and CBT exercises | Swift, Dart, Python | Demonstrate a synthetic exercise dialogue and an explicit crisis-escalation branch; no therapist replacement or unsupervised crisis handling |

## Personal And Embodied (5)

| ID | Scenario | Targets | First bounded tutorial outcome / related slice |
| --- | --- | --- | --- |
| PE-01 | Socratic learning tutor | Python, TypeScript, Haskell | Track a synthetic learner's attempts and ask graded questions; [education tutoring](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/education-tutoring) retrieves lessons, not a validated adaptive tutor |
| PE-02 | Travel and life concierge | TypeScript, Dart, Swift | Replan a fixture itinerary under budget and draft a booking; [travel booking](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/travel-booking) does not pay or rebook |
| PE-03 | Personal information and privacy agent | Rust, Go, Objective-C | Classify fixture messages and draft a deletion/rotation request; no real passwords, account access or deletion |
| PE-04 | Humanoid and household robotics | C++, Rust, Zig | Simulate observe/plan/action with bounded authority, freshness and cancel confirmation; no hardware or safety certification |
| PE-05 | Game NPC and dynamic narrative | Lua, C, V | Persist synthetic character state, choose a scoped host action and observe its result; no arbitrary host commands |

## Cybersecurity (7)

All testing must be authorized and scoped to owned fixtures or an isolated lab.
No arbitrary target discovery, live exploitation, credential theft or automated
counterattack is provided by these candidate tutorials.

| ID | Scenario | Targets | Bounded candidate outcome | Existing related slice | Full implementation |
| --- | --- | --- | --- | --- | --- |
| CY-01 | Penetration testing and red-team exercises | Rust, Go, Python | Inventory an allowlisted loopback lab and report seeded configuration defects; no public scanning or exploit chain | None | Not implemented |
| CY-02 | SOC alert analysis and SOAR response | Go, Elixir, Erlang | Correlate synthetic EDR/firewall events and draft isolation; no live blocking | [SOC triage](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/soc-alert-triage): fixed alert, not real EDR correlation | Not implemented |
| CY-03 | Threat hunting and TTP reconstruction | Perl, Rust, Python | Search fixed logs and cite a synthetic TTP timeline; no external intelligence feed or APT detection guarantee | [Log triage](https://github.com/axisvela/praxo-core/tree/main/language/perl/Tutorial/log-triage): severity counts only | Not implemented |
| CY-04 | Phishing detection and awareness exercises | Python, TypeScript, C# | Classify synthetic emails and draft an authorized awareness exercise; no deceptive sends or infrastructure attacks | None | Not implemented |
| CY-05 | Zero-trust policy tuning | Java, C#, Go | Replay synthetic access decisions and propose narrower grants; no live permission relaxation | None | Not implemented |
| CY-06 | DLP and privacy redaction | Go, Rust, Objective-C | Check synthetic exports for specified sensitive fields and deny or redact before sharing; no encryption/DLP completeness claim | [SOC triage](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/soc-alert-triage): email/phone redaction only | Not implemented |
| CY-07 | Open-source supply-chain tampering monitoring | Rust, OCaml, Ruby | Compare fixed manifests and maintainer-change fixtures; propose a reviewed version pin, not proven malware detection | None | Not implemented |

## Smart Cities And Public Governance (7)

| ID | Scenario | Targets | Bounded candidate outcome | Existing related slice | Full implementation |
| --- | --- | --- | --- | --- | --- |
| CT-01 | City-wide adaptive traffic signals | Erlang, C++, Julia | Simulate fixed junction queues and verify proposed timing against deterministic limits; no signal commands | None | Not implemented |
| CT-02 | Utility-pipeline leak localization and dispatch | Fortran, Rust, Nim | Rank synthetic pressure anomalies and draft inspection; no valve isolation or field dispatch | [Signal trends](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends): metrics only, not leak localization | Not implemented |
| CT-03 | Cross-agency public-service approvals | Java, C#, PHP | Validate synthetic applications and draft parallel review tasks; no real identity checks or official approval | None | Not implemented |
| CT-04 | Emergency command and resource allocation | Go, Julia, Erlang | Simulate road closures and constrained relief routes; no operational rescue directions or dispatch | None | Not implemented |
| CT-05 | Pollution source tracing and inspection support | R, Fortran, Python | Compare synthetic sensor/weather records and draft investigation hypotheses; no causal or enforcement finding | None | Not implemented |
| CT-06 | Waste collection and route optimization | Julia, Dart, V | Replan a bounded synthetic collection queue under vehicle limits; no vehicle commands | None | Not implemented |
| CT-07 | Public-budget execution and performance review | R, COBOL, Java | Reconcile synthetic disbursements and milestones, explain flagged variances; no official audit conclusion | None | Not implemented |

## Transport Shipping And Aviation (7)

| ID | Scenario | Targets | Bounded candidate outcome | Existing related slice | Full implementation |
| --- | --- | --- | --- | --- | --- |
| TL-01 | Drone-fleet inspection and airspace conflict resolution | Rust, C++, Zig | Simulate bounded waypoints and conflict checks outside the agent; no flight or avoidance commands | None | Not implemented |
| TL-02 | Container-yard and quay-crane scheduling | Erlang, C++, Java | Replan synthetic container jobs under resource constraints; no crane or AGV dispatch | None | Not implemented |
| TL-03 | Ocean routing and fuel optimization | Fortran, Julia, C++ | Compare synthetic route/weather costs and draft a route; no navigation, fuel-savings or CII compliance claim | None | Not implemented |
| TL-04 | Cold-chain temperature and cargo-risk alerts | Rust, Nim, Octave | Compute fixed temperature excursions and draft a transfer review; no refrigeration changes or clinical cargo guarantee | [Signal trends](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends): generic signal fixture only | Not implemented |
| TL-05 | Multimodal customs documentation and rerouting | Java, Go, PHP | Validate synthetic document fields and compare alternate routes; no customs filing | [Logistics checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/logistics-checkpoint): message continuation and draft only | Not implemented |
| TL-06 | Autonomous-fleet remote assistance and map updates | C++, Rust, D | Replay synthetic road-topology changes and draft a reviewed map patch; no vehicle takeover | None | Not implemented |
| TL-07 | Airport gates and disruption recovery | Java, Julia, C# | Simulate gate/crew/connection constraints and draft recovery options; no operational scheduling or latency guarantee | [Travel booking](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/travel-booking): fare-hold fixture, not airport recovery | Not implemented |

## Media Design Games And Content (7)

| ID | Scenario | Targets | Bounded candidate outcome | Existing related slice | Full implementation |
| --- | --- | --- | --- | --- | --- |
| MD-01 | Film storyboards and virtual-production previs | Lua, C++, TypeScript | Turn a fixed script into a bounded shot-plan draft; no verified Unreal integration or rendered production | None | Not implemented |
| MD-02 | News fact-checking and source verification | Python, Haskell, Perl | Compare fixed source excerpts and metadata, cite contradictions and uncertainty; no truth guarantee or live news crawl | [Office Q&A](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/office-qa): citations mechanism only | Not implemented |
| MD-03 | Open-world game ecosystem simulation | Lua, C, V | Simulate economy/resource rules with persisted synthetic state; no scale or long-term equilibrium guarantee | [Host embedding](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding): device callbacks, not game ecology | Not implemented |
| MD-04 | Dubbing lip-sync and cultural localization | Python, Swift, C++ | Plan localized captions and timing using synthetic/licensed media; no impersonation, unconsented voice cloning or verified lip-sync | None | Not implemented |
| MD-05 | Industrial design and 3D topology generation | C++, Julia, Fortran | Compare synthetic mesh descriptors against stated constraints; no manufacturability or mechanical certification | None | Not implemented |
| MD-06 | Audiobook and audio-drama production | Python, Dart, Swift | Plan licensed character voices and fixture mixing cues; no synthesized production or rights guarantee | None | Not implemented |
| MD-07 | Digital-presenter live-show direction | TypeScript, Elixir, Lua | Replay synthetic engagement events and draft a presentation order; no audience profiling, coupon sends or real stream control | None | Not implemented |

## Law Justice And Intellectual Property (5)

| ID | Scenario | Targets | Bounded candidate outcome | Existing related slice | Full implementation |
| --- | --- | --- | --- | --- | --- |
| LJ-01 | Litigation evidence timelines and examination outlines | Python, OCaml, Go | Build a cited timeline from synthetic documents and flag contradictions; no legal advice or evidentiary admissibility claim | [Evidence vault](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/evidence-vault): confined reads, not litigation analysis | Not implemented |
| LJ-02 | Patent search FTO and portfolio analysis | Python, Java, Haskell | Compare synthetic claims and draft questions for counsel; no exhaustive patent search or non-infringement opinion | None | Not implemented |
| LJ-03 | Commercial due diligence | Java, C#, Ruby | Reconcile synthetic ownership/contracts/disputes and draft a risk checklist; no verified acquisition conclusion | None | Not implemented |
| LJ-04 | Precedent retrieval and legal-document drafting | Python, Java, OCaml | Retrieve fixed synthetic precedents and draft a cited outline; no sentencing recommendation or judicial decision | [Legal compliance](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/legal-compliance): policy citation and scripted gate only | Not implemented |
| LJ-05 | Copyright monitoring and rights-enforcement workflow | Rust, PHP, TypeScript | Compare authorized fixture assets and draft an evidence packet; no broad crawl, automatic DMCA notice or infringement adjudication | None | Not implemented |

## Built Environment Mining And Property (5)

| ID | Scenario | Targets | Bounded candidate outcome | Existing related slice | Full implementation |
| --- | --- | --- | --- | --- | --- |
| BE-01 | Construction safety inspection and remediation review | C++, Rust, C# | Evaluate synthetic inspection labels and track a review checklist; no real vision or certified safety finding | None | Not implemented |
| BE-02 | Commercial-building HVAC and lighting management | Julia, C, Delphi | Simulate occupancy/thermal constraints and draft settings; no BMS commands or verified energy savings | None | Not implemented |
| BE-03 | Autonomous mining and slope-risk warning | Fortran, Rust, C++ | Compute synthetic displacement indicators and draft a review alert; no collapse prediction or mining-vehicle dispatch | None | Not implemented |
| BE-04 | Tender drafting and bid-collusion review | Java, PHP, COBOL | Validate synthetic qualifications and flag document similarities for review; no automatic bid submission or collusion verdict | None | Not implemented |
| BE-05 | Property-site assessment and rental forecasting | R, Julia, D | Compare synthetic site metrics and show forecast assumptions; no verified probability, return or personal-location profiling | None | Not implemented |

## Agriculture Forestry And Conservation (5)

| ID | Scenario | Targets | Bounded candidate outcome | Existing related slice | Full implementation |
| --- | --- | --- | --- | --- | --- |
| AE-01 | Livestock monitoring and precision feeding | C, Nim, Rust | Summarize synthetic animal observations and draft a review request; no veterinary diagnosis, isolation or feeding control | None | Not implemented |
| AE-02 | Forest-fire monitoring and spread simulation | Fortran, Julia, R | Replay synthetic weather/fuel cells and compare modeled spread; no operational warning or firebreak dispatch | None | Not implemented |
| AE-03 | Aquaculture water quality and feeding | Lua, C, Octave | Compute fixed oxygen/temperature indicators and draft a bounded action; no aerator or feeder commands | [Host embedding](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding): host-callback mechanism only | Not implemented |
| AE-04 | Agricultural hedging and production-sales planning | R, Julia, COBOL | Simulate exposure and compare scenario costs; no futures orders, price lock or financial advice | None | Not implemented |
| AE-05 | Biodiversity monitoring and anti-poaching alerts | Python, Rust, Zig | Classify synthetic labeled observations and draft ranger review; no species-recognition guarantee or automatic pursuit | None | Not implemented |

## Organization Architecture And Collaboration (7)

| ID | Scenario | Targets | Bounded candidate outcome | Existing related slice | Full implementation |
| --- | --- | --- | --- | --- | --- |
| OG-01 | Enterprise architecture asset-graph governance | Java, OCaml, C# | Compare fixed application/API graphs with stated standards and draft change findings; no production scanning or automatic blocking | None | Not implemented |
| OG-02 | Multi-agent society and policy simulation | Julia, Erlang, Haskell | Simulate a small bounded synthetic population and report sensitivity; no tens-of-thousands scale or real policy prediction | None | Not implemented |
| OG-03 | Cross-cultural negotiation interpretation and advice | TypeScript, Swift, Python | Compare fixture transcripts and terminology, flag uncertainty; no micro-expression inference, mind reading or live interpretation guarantee | None | Not implemented |
| OG-04 | Open-source community governance and onboarding | Ruby, Elixir, Perl | Classify synthetic issues and draft contributor guidance/reviewer requests; no automatic issue closure or maintainer impersonation | None | Not implemented |
| OG-05 | EDA placement and routing optimization | C++, Fortran, Julia | Explore a synthetic placement grid and report stated PPA proxies; no foundry-valid layout or proven PPA optimization | None | Not implemented |
| OG-06 | Personal digital twin and cross-app memory | Swift, Objective-C, Dart | Store synthetic consent-scoped memories with provenance and deletion tests; no real inbox/passwords or unrestricted recall | [Logistics checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/logistics-checkpoint): message continuation only, not a personal memory hub | Not implemented |
| OG-07 | Multidisciplinary Virtual PI | Python, Julia, Haskell | Coordinate bounded literature/simulation/review tasks with shared limits and explicit provenance; no autonomous scientific-validity claim | [Representative chain](https://github.com/axisvela/praxo-core/tree/main/examples/representative-chain): application-level delegation, not a research team | Not implemented |

## Core Language Coverage

Every current Core entry has a candidate assignment. This is **planning coverage**,
not a hundred applications multiplied by thirty-one languages. Prefer one differentiated
consumer path per language, then reuse fixtures and acceptance criteria rather
than copying an agent loop. Shared teaching data is not a shared remote agent.

| Core directory | Candidate IDs | Runtime / implementation boundary |
| --- | --- | --- |
| `go` | SE-01, SE-06, IN-03, PE-03 | Reference Core; application-owned stores and effects |
| `python` | SE-02, SC-01, HC-01, PE-01 | Native Core; retrieval/analysis tools remain scoped |
| `typescript` | SE-01, CS-01, PE-02 | Native Core; browser UI is not another Core |
| `java` | SE-03, OP-04, HC-03 | Native Core; local Windows runtime limitations remain separate from CI |
| `rust` | SE-02, FC-02, PE-04 | Native Core; no real-time control guarantee |
| `csharp` | OP-01, HC-03, IN-05 | Native .NET Core; identity remains application-owned |
| `r` | OP-07, FC-01, SC-06 | Native Core; computed statistics are not causal evidence |
| `c` | SC-03, IN-06, PE-05 | Native Core; caller-owned memory/transport and host limits |
| `cpp` | FC-02, IN-01, PE-04 | Native Core; device SDK and safety controller remain external |
| `fortran` | SC-04, SC-05, IN-04 | Native Core; fixed numerical workload, no arbitrary generated code |
| `cobol` | SE-03, FC-04, HC-04 | Native Core; GnuCOBOL is not z/OS/CICS/IMS verification |
| `php` | SE-08, OP-01, CS-05 | Native Core; service transport and published-package state checked separately |
| `ruby` | SE-07, OP-05, IN-03 | Native Core; worker/job durability remains application-owned |
| `elixir` | SE-06, OP-03, CS-06 | Native Core; OTP supervision is not exactly-once effects |
| `erlang` | SE-06, IN-02 | Native Core; bounded actor messages and application supervision |
| `lua` | IN-06, PE-05 | Native Core embedded in a host; no independent device authority |
| `dart` | SE-01, OP-02, PE-02 | Native Core; UI/platform permissions require separate checks |
| `swift` | OP-02, HC-02, PE-02 | Native Core; OS runtime and package verification are separate |
| `julia` | SC-02, SC-03, IN-04 | Native Core; deterministic numerical safety constraints |
| `haskell` | SE-04, SC-01, PE-01 | Native Core; typed plans do not prove runtime safety |
| `matlab` | SC-06 | Shared MATLAB/Octave source; native MATLAB runtime unverified |
| `octave` | SC-05, SC-06 | Shared MATLAB/Octave source run under GNU Octave |
| `perl` | SE-02, CS-07, FC-06 | Native Core; fixed logs/text, no arbitrary shell |
| `delphi` | SE-03, OP-04, FC-04 | Native Core; Free Pascal evidence does not verify commercial Delphi |
| `ocaml` | SE-05, FC-05, IN-05 | Native Core; application-owned dependency graph/reviewer |
| `objc` | HC-02, PE-03 | Native Objective-C Core; GNUstep and Apple runtimes distinguished |
| `nim` | IN-01, IN-06 | Native Core; sensor/actuator transports remain fixtures |
| `v` | IN-02, PE-05 | Native Core; constrained host callbacks |
| `d` | SE-07, OP-07, FC-02 | Native Core; dependency/registry versions checked separately |
| `zig` | IN-04, PE-04 | Native Core; simulation only, no device protocol or hardware claim |
| `powershell` | SE-07, OP-01 | Shared C# Core; no duplicate PowerShell agent loop |

JavaScript, Kotlin, Scala, Groovy, Clojure, Visual Basic, F#, and OpenCL remain
host-Core samples. Shell, Lisp, Tcl and Prolog remain Bridge consumers. Reusing
these entry points does not add independent Core implementations. Ada, Mojo and
other planned implementations are not activated by this catalog.

## Acceptance For Each Slice

1. Name the scenario ID, chosen language, SDK version/source mode and non-goals.
2. Record plan steps and application-owned state; never silently elevate memory
   to instructions or assume an SDK automatically recalls it.
3. Exercise at least two tool/result/decision steps with explicit final scope.
4. Test denial before effects, malformed input, dependency failure, cancellation
   where supported, and approval-edit reauthorization where applicable.
5. Keep external actions simulated or draft-only by default. Real actions require
   separately verified identity, approval, idempotency/reconciliation and isolation.
6. Provide commands, expected output, nonzero failures and an automated test.
7. Record source, local runtime, CI, live provider and independent reproduction
   separately. Optional live-model mode does not count as a recorded live run.
8. Use only existing Core APIs. Any discovered reusable API/wire gap follows the
   specification, compatibility and per-language parity gates first.

No new deployment, clinical, financial, laboratory, grid, robotic or security
guarantee is created by a tutorial or a passing deterministic fixture.
