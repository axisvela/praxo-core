# Public Roadmap

Current core release: `2.10.0`.

This roadmap is organized around developer outcomes: choose the framework,
run something useful, build a real prototype, embed it in an application, and
then harden that integration. It is not a delivery schedule, a product roadmap,
or a promise that every language implementation supports every feature.

## Next-stage Direction

**Planning update: 2026-11-13.** The immediate priority is to shorten the path
from discovery to a useful project. New users should not need to understand the
full specification, evidence taxonomy, cross-language matrices, or advanced
execution profiles before they can build an agent.

**Planning update: 2026-11-16.** The next focus is evidence depth and the first
working path, not more language entries. The first path is a five-minute embed;
governed acceptance is a second step. Public claims now separate contract
completeness, adapter availability, and integration verification. Safe default
semantics also move up: Go source at `73da5139` removes recalled memory from the
system role. `2.9.0` and `2.10.0` include the fix; `2.8.0` still used the previous
role. The fix does not prevent all prompt injection, and does not establish the
same behavior in every SDK. Final tool arguments remain reauthorized after edits.

**Planning update: 2026-11-20.** `2.10.0` records provider SSE streaming and
process plugin hosts across the declared language cores. C and C++ package
recipes for vcpkg, Conan Center, and xmake are prepared and submitted upstream;
an open PR is not a registry publication or install evidence. Distribution work
stays separate from language count: a package is adopted only after an external
project installs it and runs the allow/deny path.

**Planning update: 2026-11-22.** The documentation now has one canonical
task-to-path table in Start Here, language entries grouped by what a developer
can build today, a first-pass source-depth audit for the example catalog, and
language-specific starting points in the consumer test template. These close the
internal documentation gaps, but they do not close the external ones. Independent
five-minute timing, hosted-endpoint validation, an external consumer-selected
path, and registry install verification remain open and are tracked in
[#30](https://github.com/axisvela/praxo-core/issues/30),
[#31](https://github.com/axisvela/praxo-core/issues/31),
[#32](https://github.com/axisvela/praxo-core/issues/32), and
[#33](https://github.com/axisvela/praxo-core/issues/33). Repository fixtures are
not substitutes for external evidence.

PRAXO-CORE remains a **governed, embeddable agent execution framework**. The
roadmap favors runnable applications and clear integration boundaries over new
language, adapter, profile, or test counts. Existing systems and constrained
runtime environments are the primary integration target; a new language Kernel
or adapter still requires a named consumer, a maintainer, and a real deployment
path.

### Planning Principles

**Planning update: 2026-11-25.** The basic scenario-entry batch is delivered;
the [catalog](../getting-started/tutorial-catalog.md) separates related slices
from full applications. Tutorial CI passed at `dfdfd558` in run `45537631891`;
this is revision-scoped fixture evidence, not external adoption. The next bounded
work is ecosystem-native reference applications, with selection-to-validation
measurement supporting those paths, not another language-count campaign. Discovery materials exist, but their effect
on unaided framework choice remains unmeasured outside the recorded pilot.

**Planning update: 2026-11-24 (basic-entry phase).** Scenario breadth does not
establish language fit. That phase prioritized batch completion of basic scenario
entry points, discovery and attracting users before broad optimization. Keep each
entry accurately scoped and assess mappings against the
[language selection gate](../getting-started/tutorial-plan.md#language-selection-gate).
Prioritize accurate selection guidance and reproducible starting paths. Deeper
host integrations follow a named consumer or concrete usage feedback, not a
blanket requirement to deepen unused tutorials. A concise selection rationale
must not turn into a deep-integration prerequisite for publishing basic examples.
Generic scripted fixtures remain useful Core integration
examples, not evidence that a language is preferable for an industry task.
Selection rationale must distinguish an existing-runtime constraint from a
demonstrated ecosystem capability and state when not to choose that runtime.

- Lead with a working result, then explain the underlying contracts.
- Start from published packages and common local or hosted model endpoints.
- Keep one minimal denial check in the first path; move broad matrices and fault
  campaigns to the hardening stage.
- Use examples, recipes, and optional adapters before adding public Core APIs.
- Add a shared API only when a real consumer demonstrates a reusable gap.
- Keep credentials, identity, durable state, isolation, and product data in the
  embedding application.

## Language Scope

This roadmap applies to the whole PRAXO-CORE family, not only the Go reference
implementation. Go defines the normative reference behavior, while each language
Core ships as an independently versioned package with idiomatic APIs. The stages
below describe the common developer journey; language-specific availability,
installation, and feature coverage follow the
[language implementation matrix](../languages/index.md) and
[support policy](../languages/support.md).

| Scope | Languages | Roadmap expectation |
| --- | --- | --- |
| Reference | Go | Defines shared behavior and leads reference examples |
| Agent-capable Core | Python, TypeScript, Java, Rust, R, C# | Share the adoption stages and receive runnable provider, tool, and integration paths where practical |
| Extended Core | C, PHP, Fortran, COBOL, Ruby, Elixir, Erlang, C++, Lua | Provide consumer paths as demand and maintainers justify them; advanced features may remain Go-first |
| Other declared implementations | Other languages listed in the matrix, plus Bridge and Sample entries | Use per-language documentation and state gaps explicitly; no promise of every example or feature |

The roadmap does not require every language to publish every example at the same
time. It does require user-facing paths to say which language and package they
target and not to present Go-only behavior as a cross-language guarantee.
Language count is not a goal: read `complete` as contract-complete, and check
[Adapter Status](../languages/adapter-status.md) for the separate adapter and
integration layers.

These are technical coverage groups, not investment priorities or support SLAs.
Consumer demand may prioritize an implementation from any group without changing
its declared capability or evidence level.

Long-tail language work is evaluated as market experiments, not language-count
expansion. The first candidates are PowerShell for existing Windows automation,
Fortran for simulation workflows, COBOL for existing business systems, and
Delphi / Free Pascal for existing applications. Each needs a named consumer and
evidence that an embedded Core solves a real task better than external
orchestration. A conformance pass or package publication is not adoption.

### COBOL batch exception review

- Keep the primary batch deterministic and independent of review completion.
  Start with the [batch exception review example](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/batch-exception-review):
  check that normal output is unchanged, exceptions are retained, and reviews
  do not commit business writes when a worker is slow or unavailable.
- With a named consumer, compare a separate COBOL review step using Core with
  an external worker that does not embed Core in the batch. Measure batch
  completion against its window, exception backlog and recovery, and integration
  effort. Prefer the external worker unless keeping policy and tools in COBOL
  solves a demonstrated problem. The fixture is not production evidence.

## Adoption Path

| Stage | Developer outcome | Current state | Next result |
| --- | --- | --- | --- |
| 0. Decide | Know whether Core fits and which language/path to use | The overview, comparison, non-goals, and a single canonical task-to-path table in Start Here exist; the landing page and overview link to it. Language entries are grouped by what can be built today | Use the canonical path in external onboarding and record where it breaks; keep language entry points aligned with registry state |
| 1. Run | Install a published package, connect a model, register one tool, and get a useful result | Published-package deterministic starters and live-model examples exist; five-minute completion has not been independently measured. Registry state is recorded separately in the language support pages. The live-model guide covers endpoint, model id, credential, timeout, tool schema, and platform troubleshooting. Local Ollama tool-call runs are recorded for Go, Python, TypeScript, C#, and Rust (C# and Rust via built binaries); no hosted endpoint is recorded. The local Java JVM remains blocked | Record independent deterministic and live-endpoint completion separately; hosted endpoint validation is tracked in [#31](https://github.com/axisvela/praxo-core/issues/31) and independent timing in [#30](https://github.com/axisvela/praxo-core/issues/30) |
| 2. Prototype | Build one coherent local application with tools, streaming, structured output, MCP, workspace access, or telemetry | Thirteen example themes have source entries across thirty-one languages. The catalog is grouped by task, and a first-pass source-depth audit now labels Core references, mechanism checks, and transport-neutral handlers; it does not certify execution. End-to-end prototype tutorials now include the Go Workspace Agent and the Python structured-output application; most other examples remain integration checks | Turn the source-depth audit into recorded runs for one consumer-selected application path; external validation is tracked in [#32](https://github.com/axisvela/praxo-core/issues/32) |
| 3. Embed | Integrate Core into an existing service with application-owned identity, policy, persistence, events, and shutdown | Vendor-neutral Go/Python/TypeScript/C# HTTP services and authenticated identity/policy services; Go, Python, TypeScript, C#, Ruby, PHP, and Rust support OIDC/JWKS with provider discovery; the Java example passes in Linux CI, while its local Windows JVM is blocked; 30 of 31 declared implementations have source-level RFC 7662 introspection and RFC 7009 revocation, with 29 runtime-verified locally (28 native runtimes plus Octave for the shared MATLAB/Octave module), native MATLAB unverified, and COBOL boundary-only; an optional external Python policy decision service, verified-identity and durable-checkpoint variants, a risk-tiered checklist, and a checkpoint-continuation guide connecting message history, allowlisted stores, and operation state exist | Extend OIDC/external identity to further SDKs, close registry publication gaps for consumer-selected languages, record native MATLAB separately, and validate the checkpoint store for a real consumer |
| 4. Harden | Make the specific integration safe to upgrade, fail, cancel, and recover | Negative, upgrade, containment, and recovery assets exist. The Go memory-role fix is released in `2.9.0`; retry hazard tests have local deterministic coverage. A source audit found no automatic recall in other SDK agent paths or in the Bridge `run`/`event stream` paths. The consumer test template now covers two-run memory trust, unknown-effect retry/reconciliation, and language-specific starting points. It has been run against 9 of 10 maintainer-owned fixtures; the local Java run timed out, and these are not external consumers | Apply the template to an external consumer; repository fixtures are not a substitute. Tracked in [#32](https://github.com/axisvela/praxo-core/issues/32) |
| 5. Extend | Adopt plugins, delegation, long-running operations, workspace providers, or embodied integrations when needed | Application-level delegation examples cover Go, Python, TypeScript, Java, C#, and Rust; Go reference examples cover long-running operations, workspaces, and plugins | Add controlled parent-to-child policy, tool-scope, budget, and depth narrowing before claiming governed delegation |

The stages describe the recommended order for adoption. They are not release
gates and do not require all languages to advance together.

## Stage 0: Decide Whether Core Fits

### Developer Outcome

Within a few minutes, a developer can answer:

- Is an embedded model/tool loop the right solution?
- Which supported language and starter should I use?
- Which responsibilities remain in my application?

### Start Now

- [Start Here](../getting-started/index.md)
- [Overview](../getting-started/overview.md)
- [When Not to Use PRAXO-CORE](../getting-started/when-not-to-use.md)
- [Language implementations](../languages/index.md)
- [Language support and distribution](../languages/support.md)
- [Framework comparison](comparison.md)

### Next Work

- Use the existing canonical task-to-path table in external onboarding and record
  where it breaks.
- Maintain the separate try, package-verification, embedding, and hardening paths.
- Keep the existing build-oriented language groups aligned with registry state.
- Make each package description classify the project as an AI agent framework,
  not an HTTP agent or hosted service, and keep coding-agent version maps
  consistent with registry metadata.

Contract status and evidence remain available in
[Contract and Evidence Status](contract-status.md), but are not prerequisites for
the first project.

## Stage 1: Run a Useful Agent

### Developer Outcome

From an empty directory, install a published package, connect Ollama or an
OpenAI-compatible endpoint, register one low-risk tool, and see a model response
or tool result. Completion-time targets are not measured results:

- Five minutes for deterministic embedding, with the language toolchain already
  installed; no live model or API key is required.
- 15-30 minutes for a real tool call, with the model endpoint and credentials
  already available; model download and account setup are recorded separately.

Measure from the documented install command to the expected result, recording
environment, failures, repairs, and any author assistance. Governed acceptance
remains a separate follow-up path.

The first path keeps only three checks:

1. the application starts;
2. the tool can be called successfully;
3. one denied call produces no tool effect.

It does not require the full governed negative matrix, cross-version upgrade
suite, Behavior Lab, or compatibility report.

### Start Now

- [Quickstart](../getting-started/quickstart.md)
- [Live Model Golden Path](../getting-started/live-model-golden-path.md)
- Published-package starters for [Go](../getting-started/consumer-go.md),
  [Python](../getting-started/consumer-python.md),
  [TypeScript](../getting-started/consumer-typescript.md), and
  [Java](../getting-started/consumer-java.md)
- Extended-language starters for [Ruby](../getting-started/consumer-ruby.md),
  [PHP](../getting-started/consumer-php.md),
  [Elixir](../getting-started/consumer-elixir.md), and
  [Lua](../getting-started/consumer-lua.md)
- [OpenAI-compatible adapters](../reference/openai-compatible-adapter.md) in the
  languages that provide them

### Next Work

- Validate the four-language live examples against Ollama and at least one
  hosted OpenAI-compatible endpoint, then extend them to other maintained
  languages.
- Give the main SDKs a direct continuation from deterministic starter to a real
  model endpoint, with language-specific installation and code.
- Record expected output and short troubleshooting for endpoint URLs, model
  names, credentials, timeouts, tool schemas, and platform-specific environment
  variables.

## Stage 2: Build a Real Prototype

The [100-scenario tutorial catalog](../getting-started/agent-scenarios.md) maps sixteen
domains to bounded slices and candidate assignments for all 31 current Core
entries. This is planning coverage, not a hundred implemented applications or a
cross-language parity guarantee. Ruby's SE-07 FinOps slice has local source-mode
tests and passed tutorial CI at `dfdfd558` (run `45537631891`). No cloud mutation
or live-model evidence is claimed.

### Developer Outcome

Turn the first run into one useful local application, such as:

- a structured-output processor;
- an MCP-backed tool assistant;
- a read-only workspace assistant;
- a streaming agent with event or OpenTelemetry output.

### Start Now

- [Examples](../getting-started/examples.md)
- [Recipes](../guides/recipes.md)
- [Integration adapters](../integrations/index.md)
- [Plugin guide](../guides/plugins.md)
- [Multi-agent patterns](../guides/multi-agent.md)
- [Representative chain tutorial](../guides/representative-chain-tutorial.md),
  with the Go real-model chain and deterministic counterparts across the wired
  languages
- Examples under `examples/`, including `reference`, `governed-workspace`,
  `checkpoint`, `plugin`, and `recipes`

### Next Work

- Keep the existing Basic, Integration, Hardening, and Advanced catalog groups;
  distinguish mechanism checks, Core integrations, application tutorials, and
  recorded runs. Source-file coverage alone does not establish a working path.
- Build language-shaped application tutorials over shared synthetic business
  services in the public MIT `axisvela/agent-tutorial-services` repository. Start with
  scoped order lookup and resolution drafts, then add Java enterprise orders,
  Python/C# service desks, PowerShell/Perl operations, COBOL batch review,
  Julia/R/Octave analysis, Lua host embedding, a Rust gateway adapter fixture,
  a Zig gateway health fixture, and C/C++ device scenarios only as their paths
  are validated. Business APIs remain outside Core and
  `spec/`; local service execution is required, public hosting is optional.
  Maintainer tutorials are not independent consumer evidence.
  New application tutorials live in `language/<language>/Tutorial/`, alongside
  `examples/`; existing mechanism examples stay in their published locations.
  The first local slice now has an HTTP order service plus native Python and
  TypeScript clients covering draft-only success, policy/server denial, and
  dependency failure. This is source/local fixture evidence, not a hosted
  service, a full enterprise Web tutorial, or external adoption.
  Java's `Tutorial/order-review/` adds a CLI and loopback Web entry plus JUnit
  contract tests; local JVM verification is blocked, but compilation and
  mock-backed Agent/Web tests passed in Linux CI at `3c2063f9` (run
  `45031868787`). TypeScript now installs its own pinned tutorial dependency.
  The teaching backend is now public; the original demo repository stays private.
  Core CI pins public backend revision `8b7820e` for the full native-client gate,
  without private credentials. Full Python/TypeScript/Java CLI integration passed
  at Core `8b0593bb` in run `45033109188`, using published packages and deterministic
  models. The earlier private gate remains a recorded skip, not a pass; neither
  result establishes independent adoption or live-provider verification.
  C# now has a local-verified ASP.NET Core service-desk tutorial with fixed-order
  routing and a native Core CLI; the public integration harness adds real Web
  authentication, draft replay and dependency-failure checks. Four-language CLI
  and C# Web integration passed in CI at `ae953050` (run `45034303513`), backend
  `cd08b09`; no live model, production identity or public deployment is claimed.
  PowerShell's `Tutorial/windows-diagnostics/` adds fixed read-only Windows
  service/disk checks through the shared C# Core. Local PowerShell 7.7.0 tests
  pass 4/4, and hosted Windows CI passed the C# Core build plus all four
  source-mode checks at `5afe6e35` (run `45036962205`). It supports no repairs,
  remote hosts, arbitrary shell commands or live model path.
  Perl's `Tutorial/log-triage/` adds a native operations path with a fixed fixture
  log, severity report, policy denial and dependency failure. Local Perl 5.40.3
  checks pass, and Linux CI passed at `3b5edcc7` (run `45038008192`). It does not read arbitrary
  paths, execute shell, deliver alerts or call a live model.
  R's `Tutorial/data-quality/` computes fixed-dataset statistics through the
  native R Core and returns a report that packages tool-computed values. Local
  R 4.6.1 checks pass, and Linux CI passed at `e89c9037` (run `45039622807`). It
  does not read arbitrary files, run SQL/shell, install packages or call a live
  model.
  R's `Tutorial/marketing-segmentation/` splits a fixed eight-customer fixture into
  four segments, computes native per-segment averages (`vip` = `825`), picks the
  highest-value segment and drafts a review-only `invite_segment` with zero sends.
  Local R 4.6.1 checks and tutorial CI at `dfdfd558` pass. It does
  not send messages, launch a campaign, read arbitrary data or use a live model.
  R's `Tutorial/wealth-analysis/` computes weighted risk `0.54` and concentration
  `0.60` over a fixed `acct-100` portfolio, recommends `rebalance`, and drafts a
  review-only proposal with `trades_executed=0`. Local R 4.6.1 checks pass; the
  tutorial CI at `dfdfd558` passes. It does not trade, use market data, give
  advice or call a live model.
  COBOL's `Tutorial/batch-exception-review/` reuses the existing deterministic
  batch handoff and checks reviewed, unavailable and timeout paths while keeping
  batch output and exceptions unchanged. Local GnuCOBOL 2.0.0/Python checks pass,
  and Linux CI passed at `01d9b1ff` (run `45040372057`). It does not implement real posting,
  durable queues, recovery proof or a live model.
  Julia's `Tutorial/experiment-comparison/` computes fixed baseline/candidate
  metrics through the native Julia Core and packages computed evidence in a
  report. Local Julia 1.13.2 checks pass, and Linux CI passed at `bbf12c42` (run
  `45041423996`). It does not read arbitrary data, run model-provided Julia code,
  install packages or call a live model.
  Fortran's `Tutorial/simulation-metrics/` computes fixed ten-sample metrics
  (mean, minimum, maximum, peak-to-peak, two exceedances) through the native
  Fortran Core and packages the computed evidence in a `draft_only` report. Local
  gfortran 16.2.0/RE2 checks and tutorial CI at `dfdfd558` pass. It
  does not read arbitrary data, run model-provided Fortran, install packages,
  publish a report or call a live model.
  Octave/MATLAB's `Tutorial/signal-trends/` computes fixed-signal mean,
  peak-to-peak, RMS and threshold anomalies through the shared Core and packages
  the evidence in a report. Local GNU Octave 11.3.0 checks pass, and Linux CI
  passed at `0664a194` (run `45042266323`). Native MATLAB is unverified. It does
  not read arbitrary files, run model-provided code, control devices or call a
  live model.
  Python's `Tutorial/office-qa/` adds a citation-bearing office Q&A path over
  fixed policy documents, with scoped search denial and index failure. Local
  Python checks pass, and Linux CI passed at `cfd850a6` (run `45043537084`). It
  does not read arbitrary files, call connectors, send email or use a live model.
  Python's `Tutorial/insurance-claims/` reads a fixed `claim-100` file, computes a
  deterministic risk signal, drafts a review-only payout and validates the final
  report through `StructuredOutput` (a malformed report raises
  `StructuredOutputError`). Local Python 3.14 checks and tutorial CI at
  `dfdfd558` pass. It does not execute a payment, decide coverage, read
  arbitrary files or use a live model.
  Python's `Tutorial/legal-compliance/` searches fixed policy fixtures for a
  citation and gates `publish_memo` behind a Core interrupt: approval runs the
  simulated publish, rejection raises `ApprovalDeniedError` with zero
  publications, and an out-of-scope query is policy-denied before the read. Local
  Python 3.14 checks and tutorial CI at `dfdfd558` pass. It does not
  give legal advice, record a real approval, write a document store or use a live
  model.
  Python's `Tutorial/education-tutoring/` implements the Core `Retriever` protocol
  with an application-owned `LessonRetriever` returning typed `Document`s, cites
  `lesson-fractions`, and drafts a review-only study plan with
  `assignments_created=0`. Local Python 3.14 checks and tutorial CI at `dfdfd558`
  pass. It does not use student data, create assignments, guarantee
  curriculum correctness or call a live model.
  TypeScript's `Tutorial/customer-support/` streams a cited support reply over
  SSE with fixed order/policy tools, authentication, denial and dependency-failure
  checks. Local Node 24 checks pass, and Linux CI passed at `39558592` (run
  `45086046576`). It does not send replies, change orders, issue refunds or use a
  live model.
  TypeScript's `Tutorial/travel-booking/` checks fixed `trip-100` inventory and
  drafts a review-only fare hold with `payment_executed=false` and
  `bookings_writes=0`; `trip-200` is policy-denied and a simulated inventory error
  fails after one read. Local Node 24 checks and tutorial CI at `dfdfd558` pass.
  It does not pay, ticket, change inventory or call a live model.
  Java's `Tutorial/wealth-service/` reads a fixed portfolio and drafts a
  review-only rebalance, with policy denial and a loopback HTTP boundary. Local
  compilation passed; the local JVM blocks runtime execution, and Linux CI passed
  at `827d47ca` (run `45088386879`). It does not trade, transfer cash, use market
  data or call a live model.
  C#'s `Tutorial/sales-crm/` reads a fixed customer and drafts a review-only
  follow-up, with policy denial and a loopback HTTP boundary. Local .NET 8 build
  and self-tests pass, and Linux CI passed at `00641594` (run `45093076768`). It
  does not write the CRM, send email, use a real customer or call a live model.
  C#'s `Tutorial/healthcare-scheduling/` reads a fixed `appointment-100` clinic
  schedule and drafts a review-only booking with `booking_writes=0`;
  `appointment-200` is policy-denied and a simulated scheduling error fails after
  one read. Local .NET 8 build/self-tests and tutorial CI at `dfdfd558` pass.
  It does not write the schedule, confirm the booking, use patient
  identity or call a live model.
  Lua's `Tutorial/host-embedding/` embeds the native Lua Core in a host event loop
  with fixed read-only device and draft-action callbacks. Local Lua 5.4.6 checks
  pass, and Linux CI passed at `9163d03a` (run `45095923385`). It does not send
  device commands, open sockets or use a live model.
  Rust's `Tutorial/iot-gateway/` reads fixed `device-100` telemetry through an
  explicit application-owned `GatewayAdapter` trait and drafts a review-only
  operator action. Local Rust checks pass, and Linux CI passed at `a78de75e` (run
  `45098362060`). The adapter is an in-process fixture; it does not implement
  MQTT, OPC UA, sockets, device commands or a live model.
  Zig's `Tutorial/gateway-health/` checks a fixed `gateway-100` snapshot through an
  explicit application-owned `GatewayAdapter` function table and drafts a
  `restart_telemetry` review action. Local Zig 0.17.0 checks pass, and Linux CI
  passed at `0b2f15d6` (run `45102354617`). It does not implement MQTT, OPC UA,
  sockets, device commands or a live model.
  Go's `Tutorial/incident-coordination/` reads a fixed `incident-100` snapshot
  through an application-owned `IncidentSource`, drafts a `notify_oncall` update,
  and records `run.started`/`tool.call`/`run.completed` through an
  `event.FuncSink`. Local `go test`/`go run --test` and tutorial CI at `dfdfd558`
  pass. It does not connect a real incident system, start a
  durable workflow, mutate an incident or call a live model.
  Go's `Tutorial/soc-alert-triage/` reads a fixed `alert-100` snapshot through an
  application-owned `AlertSource`, redacts reporter email and phone with Core's
  `PIIRedactor`, drafts a review-only `isolate_host` and records audit events
  through an `event.FuncSink`. Local `go test` and `go run --test` pass and assert
  the raw PII is absent; tutorial CI at `dfdfd558` passes. It does not
  connect a real SIEM, run a host action, call a live model, or redact live tool
  arguments, errors or event payloads.
  Go's `Tutorial/logistics-checkpoint/` assesses a fixed `shipment-100`, serializes
  the transcript into a `checkpoint.Checkpoint`, and resumes a second run that
  drafts a review-only reroute without re-reading the shipment (`reads` stays 1,
  `drafts` reaches 1) and saves an extended checkpoint. Local `go test` and
  `go run --test` and tutorial CI at `dfdfd558` pass. The store is an
  in-memory JSON round-trip, not a database, concurrent store or exactly-once
  proof, and it does not connect a real logistics system or use a live model.
  Go's `Tutorial/evidence-vault/` reads one allowlisted `evidence-100.txt` from a
  `vfs/localfs` backend confined to a vault root, rejects `../secret.txt` and
  absolute paths, and drafts a review-only finding with `case_writes=0`. Local
  `go test` and `go run --test` pass and assert containment; tutorial CI at
  `dfdfd558` passes. The vault is a temporary directory, not an encrypted
  store or production sandbox, and the tutorial connects no case system or live
  model.
  C's `Tutorial/device-diagnostics/` reads a fixed `device-100` snapshot through an
  application-owned `PxDeviceAdapter` function pointer and drafts a
  `notify_operator` review action. Local MinGW gcc/CMake checks and tutorial CI at
  `dfdfd558` pass. It does not implement a serial bus, socket, device
  SDK, device command or a live model.
  C++'s `Tutorial/industrial-edge/` reads a fixed `edge-100` snapshot through an
  application-owned `DeviceAdapter` interface and drafts a `schedule_maintenance`
  review action, with a failing adapter raising `DEVICE_READ_FAILED`. Local MinGW
  g++/CMake checks and tutorial CI at `dfdfd558` pass. It does not
  implement a fieldbus, OPC UA, socket, device SDK, device command or a live model.
  See the
  [Tutorial Plan](../getting-started/tutorial-plan.md) for the scenario map,
  current status, delivery standard and next candidates.
- Validate one application-shaped prototype for a named consumer before
  expanding tutorials across SDKs.
- Audit the existing MCP examples against their actual transports and commands;
  only add missing behavior required by a consumer.
- Give adapter pages a consistent install, authentication, minimal example, and
  limitation section.

## Stage 3: Embed Core in an Application

### Developer Outcome

Integrate Core into an existing service while the application owns:

- configuration and provider credentials;
- authenticated identity and policy decisions;
- explicit tool and resource scope;
- checkpoint or application state persistence;
- events, telemetry, cancellation, and graceful shutdown;
- isolation around shell, file, or network effects.

### Start Now

- [Adoption guide](../getting-started/adoption.md)
- [Application integration checklist](../guides/application-integration-checklist.md)
- [Integration guide](../guides/integration.md)
- [Identity and policy recipe](../guides/identity-policy.md)
- [Long-running operation recipe](../guides/long-running-operations.md)

### Next Work

- Extend token introspection, revocation, and provider discovery to further
  SDKs. The
  [TypeScript example](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/service-auth)
  supports OIDC discovery, introspection, and revocation; the
  [Go](https://github.com/axisvela/praxo-core/tree/main/examples/embedded-service-auth),
  [Python](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/service-auth),
  and [C#](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/service)
  examples support OIDC/JWKS with provider discovery and keep the
  application-local HMAC path. Python also supports an application-owned HTTP
  policy decision service.
- Keep the [application integration checklist](../guides/application-integration-checklist.md)
  aligned with the read-only, side-effecting, and high-risk tiers.
- Use the [checkpoint store
  recipe](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/checkpoint-store-go)
  and [continuation guide](../guides/checkpoint-continuation.md) in a real
  consumer, and record the result. Keep the recipe distinct from a concurrent
  database, exactly-once, or a durable lease service.
- Validate the C and C++ package recipes from a clean external project before
  describing them as installable. Record prepared, submitted, merged, and
  registry-installable as separate states; the vcpkg ports currently exclude
  Android until Android-specific CI exists.

## Stage 4: Harden and Maintain

This is where broad tests and verification become a primary activity. They
should strengthen an application that already exists, not block a developer
from reaching the first useful result.

### Developer Outcome

- denied and dependency-failure paths fail closed;
- final tool arguments are authorized after edits;
- unknown outcomes are not blindly retried;
- local cancellation is not confused with remote effect cancellation;
- checkpoints are not treated as transactions;
- framework upgrades preserve the application's required behavior.

### Later-stage Work

- Keep the risk-tiered
  [application integration checklist](../guides/application-integration-checklist.md)
  aligned with the read-only, side-effecting, and high-risk tiers.
- Extend the [consumer test template](../guides/consumer-test-template.md) with
  language-specific examples instead of requiring the whole repository matrix.
- Test two-run memory write/recall paths for assistant output, application-stored
  tool results, and external writes. Assert that recalled content is not system
  data and that a denied tool call still has zero effects; do not infer general
  prompt-injection prevention from these tests.
- Keep the unknown-effect retry cases: a transport or timeout error does not
  prove that a non-idempotent tool produced no effect.
- Run upgrade, fault, load, provider, database, collector, sandbox, and recovery
  checks for the integrations that actually need them.
- Continue the [Execution Correctness](execution-correctness.md), Behavior Lab,
  compatibility, and [verification evidence](verification-evidence.md) tracks as
  maintenance and release-quality work.

The [compatibility policy](compatibility-policy.md) and security fixes continue
through every stage; only exhaustive validation is deferred.

## Stage 5: Advanced and Experimental Integrations

Advanced work follows real project demand rather than framework completeness
scores. It includes plugins, local delegation, MCP/A2A, provider-neutral
workspaces, long-running remote operations, and embodied integrations.

Use one Kernel with the documented
[integration levels](../reference/execution-profiles.md). Governed and embodied
profiles remain integration designs, not separate kernels or mandatory starting
points.

AKROVELA is the selected consumer for the embodied pilot, while PRAXOVELA is a
separate product consumer. Details and acceptance conditions remain in the
[embodied pilot plan](embodied-pilot.md); embodied work is not on the normal SDK
adoption path.

Controlled delegation is proposed, gated by a named consumer and a semantics
review before public API changes. Distinguish tools a parent can invoke from
authority it can delegate: a parent may invoke only `delegate` while granting a
child a separately authorized `read_file` capability. Define non-bypassable
parent-policy composition, shared cumulative budgets across siblings, child-count
and depth limits, cancellation/deadline propagation, and final-argument
reauthorization. Until implemented and versioned, enforcement is application-owned.
All sixteen wired languages now have application-level negative tests covering
scope narrowing, parent/child policy composition, shared sibling budgets,
child/depth limits, cancellation before effects, and final-argument
reauthorization. Extended implementations use native test suites or example
directories. They do not provide Core-enforced inheritance; public API and
profile work remain gated.

Do not prioritize new ROS, workspace-provider, language, or generic asynchronous
action APIs without a named consumer and a concrete gap.

## Current Priorities

1. **P0: Deliver ecosystem-native reference applications.** Follow the ordered
   portfolio below, starting with the PHP business application. Prove integration
   with an existing host and its runtime behavior, not another generic agent loop.
   Deliver one coherent path before expanding the next; these are proposed
   applications, not completed examples or a commitment to parallel delivery.
2. **P0: Validate the reference path with a consumer.** Run published-package
   install/run/deny, then a real provider tool call and application integration.
   Record time, failures, author assistance, and independent reproduction. Track
   third-party continued use and a consented non-author production application as
   separate milestones, not current claims or prerequisites for basic examples.
3. **P1: Stabilize the paths users choose.** Exercise the documented public APIs
   and unchanged-consumer upgrade checks for selected mainstream SDKs; publish
   migration notes and address observed breaks rather than promising identical
   APIs or freezing all `0.x` packages. Deepen an ecosystem tutorial only when a
   reproduction attempt or named consumer demonstrates the need.
4. **P1: Measure selection and keep distribution truthful.** Use the bounded
   [Agent Selection Benchmark](adoption-baseline.md#next-stage-agent-selection-benchmark)
   to assess whether tools correctly select and run the available reference paths;
   report candidate appearance, recommendation rank, exclusions, install/build,
   behavior, and repair cost separately. This supports application delivery rather
   than preceding it or opening a broad model/skill campaign. Maintain registry
   versions, package descriptions, the coding-agent package map, and bilingual
   evidence together. Describe the combination of native embedding, provider
   choice, and shared governance contracts with per-SDK limits; do not claim
   universal feature parity or superiority to orchestration frameworks.
5. **P2: Close demonstrated capability gaps.** Prioritize correctness and security
   fixes throughout; expand parity, delegation semantics, or adapters when actual
   usage proves a gap. New languages remain consumer/maintainer-gated, with no
   default expansion quota. Reuse checkpoint recipes before adding Core APIs.

These priorities favor fewer complete paths over more isolated features. A
single Go example is not sufficient evidence that the developer path works for
the other language SDKs, and registry downloads alone are not adoption.

Mainstream SDKs provide a baseline; existing-runtime and long-tail integrations
are experiments, not proven markets. Candidate hosts include Laravel/Drupal,
Rails, Spring Boot, Phoenix/OTP, PowerShell operations, Perl legacy systems,
C/C++ embedding, Fortran/R analysis, Rust gateways, and Go services. These are
selection hypotheses, not delivered integrations or market-share rankings. Compare
native embedding with simpler workflows and external orchestration, including
maintenance, deployment effort, and willingness to keep using the dependency.
Low competition alone does not establish demand. Retain useful basic slices;
do not require every slice to become a deep host integration.

External qualitative scores and suggested staffing percentages are not measured
project facts or resource commitments. Sequence work by observed user friction,
reproduction results, maintainer capacity, and expected learning value. Shared
contracts are a technical differentiator to test, not proof of a competitive moat.

### Reference Application Portfolio

The next-stage priority is reference applications, in the order below. Reference
applications live at `language/<language>/application/`; tutorials and mechanism
examples remain under `language/<language>/Tutorial/` and their existing paths.
They must be AI-native: the agent drives the primary workflow, not an add-on review
endpoint on a traditional application. See the
[AI-Native Reference Applications design](ai-native-reference-applications.md)
for the acceptance test, scenario map, and PHP/Java workflow proposals. PHP keeps
a precursor and an AI-native variant in subdirectories; other languages implement
the AI-native workflow directly, without a traditional-app precursor.
An existing slice is reusable input, not completion evidence. The language-selection gate
still applies; public scope, runtime, dependency versions, and limits must be
documented before claiming ecosystem integration. Concrete build sequencing and
operator procedures remain internal.

| Priority | Language | Proposed reference application | Ecosystem behavior to demonstrate |
| --- | --- | --- | --- |
| 1 | PHP | Drupal CMS editorial workflow and Laravel content portal | Content management and editorial portals are the typical PHP scenario, not order processing. Demonstrate CMS/portal bootstrap, routes or commands, container/service wiring, authenticated editor context, article workflow, and review-only publication. The first implementation is a Laravel content portal; a Drupal module host is next. Test framework authorization and Core tool policy together; no Python sidecar or separate Agent service required |
| 2 | Java | E-commerce catalog, order, and checkout Agent on Spring Boot | E-commerce is the typical Java enterprise scenario: Spring Boot services, commerce domain, inventory/order tools, transactional boundaries, principal propagation, approval, and audit. Show application transactions versus remote effects; banking/ERP are secondary scenarios |
| 3 | Elixir / Erlang | OTP real-time messaging, telecom, and high-availability operations Agent | Real-time messaging, notification, telecom, and OTP supervision are the typical Erlang/Elixir scenarios. Exercise supervision trees, failure/restart, bounded work, cancellation, and reconciliation before repeating an unknown-effect action. AIOps is a secondary scenario; record Elixir and Erlang entry points separately |
| 4 | Go | Cloud infrastructure and DevOps Agent | Services, CLIs, control planes, and infrastructure automation are typical Go scenarios. Use existing service/CLI integration, infrastructure client interfaces, cancellation/deadlines, tracing, and allowlisted operations; begin read-only and gate mutations |
| 5 | C++ / Rust | C++ industrial/embedded device Agent; Rust systems/edge service Agent | C++ is typical for industrial, embedded, and performance-sensitive hosts; Rust is typical for systems, CLI, and edge services. Use one concrete device SDK, simulator, or transport, bounded resources and lifecycle, command authorization, cancellation acknowledgement, and observed effect verification. Record C++ and Rust separately |
| 6 | COBOL | Banking/insurance batch exception analysis | Decimal/fixed-record batch processing is the typical COBOL scenario. Verify unchanged primary batch output, deterministic exception review, failure isolation, backlog/recovery, and compare a non-embedded external worker |
| 7 | Julia | Scientific computing and numerical optimization Agent | Numerical/scientific computing is the typical Julia scenario. Use an actual numerical/optimization dependency or existing scientific application, executable feasibility/objective checks, and evidence-linked interpretation; enumeration alone is not solver integration |
| 8 | Ruby | Rails e-commerce/SaaS back-office Agent | Rails web applications and e-commerce/SaaS back-offices are the typical Ruby scenario. Use Rails boot, authenticated tenant context, Active Record or Active Job boundaries, and draft/approval/replay tests; database transactions are not external exactly-once delivery |

The additional scenarios below select common runtime roles for implementations
outside the first eight. They are selection hypotheses, not market-share rankings,
delivery promises, or proof of ecosystem advantage. Existing slices remain bounded
integration checks until they meet the reference-application acceptance criteria.

| Language | Typical scenario | Current status |
| --- | --- | --- |
| Python | Data/AI pipeline, automation, Django/FastAPI services | Proposed |
| TypeScript | Web frontend/BFF, Node services, storefront | Proposed |
| C# | Enterprise line-of-business, ASP.NET Core services, Windows integration | Proposed |
| Perl | Log/text processing and legacy automation | Existing log-triage slice |
| Lua | Host embedding and extension/game scripting | Existing host-embedding slice |
| C | Embedded/constrained host components | Existing device-diagnostics slice |
| Fortran | Numerical simulation | Existing simulation-metrics slice |
| R | Statistical analysis and reporting | Existing data-quality slice |
| PowerShell | Windows/IT operations automation | Existing windows-diagnostics slice |
| MATLAB/Octave | Signal processing and numerical analysis | Existing signal-trends slice; native MATLAB unverified |
| Swift | Apple platform apps | Proposed; server Swift is not the primary case |
| Kotlin | Android/JVM services | Sample over the Java Core |
| Scala | JVM data engineering | Sample over the Java Core |
| Dart | Flutter applications | Proposed |
| Haskell | Compilers and domain modeling | Existing rule-DSL slice |
| OCaml | Compilers and static analysis | Existing static-diagnostics slice |
| Zig | Systems/embedded components | Existing gateway-health slice |
| D | Systems/data processing | Existing data-pipeline slice |
| Nim | Systems/CLI | Existing maintenance-triage slice |
| V | CLI/systems | Existing release-preflight slice |
| Delphi | Desktop business applications | Existing migration/RPA slices |
| Objective-C | Apple legacy applications | Existing privacy slice |
| Shell/bridges | Process orchestration and host automation | Bridge contract only |

**Current progress (2026-11-25).** Priority 1 now has two Laravel 12 paths under
[`language/php/application`](https://github.com/axisvela/praxo-core/tree/main/language/php/application):
`content-review/` is the host-integration precursor, and `ai-editorial-studio/` is
the AI-native reference implementation. The AI-native studio accepts a brief,
retrieves existing content, has the model write the draft, taxonomy, and SEO
description, saves the draft, and creates a review-only publication request. A
direct-publish brief is denied before retrieval, drafting, or publication.
It installs the published `axisvela/praxo-core==0.8.1` package and passes nine
deterministic tests (56 assertions); the precursor passes seven (29 assertions).
Order/checkout is reserved for the Java e-commerce reference; Drupal remains the
next PHP host. A hosted live run on 2026-11-25 with DeepSeek `deepseek-flash`
recorded `model=live`, a four-step trace (`search_content` -> `draft_article` ->
`suggest_taxonomy` -> `request_publish_review`), a model-written rationale (858
characters in the latest run), and `publications_executed=0`. It used a custom cURL transport for the local
proxy/CA; there is no independent reproduction or production deployment. The
application CI matrix is added but has not run.

Priority 2 has a Spring Boot AI commerce source at
[`language/java/application`](https://github.com/axisvela/praxo-core/tree/main/language/java/application).
It uses published `com.axisvela:praxo-core:0.11.0` and implements intent ->
catalog/inventory -> cart draft -> review-only checkout, with checkout always
denied. The source now records model rationale and `agent_trace`, but the local
Windows JVM remains blocked, so it has not been compiled or tested locally and no
live-model run is recorded. The Linux CI job is added but has not run. Do not
treat Java as verified until that job passes.

Priority 3 has an Elixir OTP AI ops copilot at
[`language/elixir/application`](https://github.com/axisvela/praxo-core/tree/main/language/elixir/application).
It runs a supervisor with a supervised telemetry store and remediation executor,
searches telemetry, drafts review-only remediation, and denies direct execution.
Local source-mode tests pass 6/6 on Elixir 1.20.4 / OTP 29, including tenant
denial and supervisor restart; the local Hex install hit an unknown-CA failure, while the CI job uses
the published Hex package and is added but not run. A hosted live run on 2026-11-25
with DeepSeek `deepseek-flash` recorded `model=live`: the model chose
`search_signals(service-100)`, then `draft_remediation` with a model-written
diagnosis and rationale, and finished with `executions=0`. An earlier attempt used
the display name `checkout` and was policy-denied before the authorized service id
was added to the prompt.

Priority 3 also has an Erlang OTP AI ops copilot at
[`language/erlang/application`](https://github.com/axisvela/praxo-core/tree/main/language/erlang/application).
It compiles the Erlang Core source plus the OTP supervision tree, passes 6/6
source-mode tests including supervisor restart, and denies direct remediation. A
hosted live run with DeepSeek `deepseek-flash` recorded `model=live`: the model
chose `search_signals(service-100)`, then `draft_remediation` with a model-written
diagnosis and rationale, and finished with `executions=0`. The live transport used
`httpc` with the local proxy/CA.

Priority 4 has a Go AI infrastructure agent at
[`language/go/application`](https://github.com/axisvela/praxo-core/tree/main/language/go/application).
It exposes an HTTP endpoint and CLI, uses the local Go reference source through a
module replace, passes 8/8 tests, denies direct remediation, and records
`agent_trace`. A hosted live run with DeepSeek `deepseek-flash` recorded
`model=live`, a three-step trace (`search_signals` -> `draft_remediation` ->
final report), a model-written diagnosis/rationale, and `executions=0`. Go CI is
added but has not run.

Priority 5 has a Rust AI edge gateway agent at
[`language/rust/application`](https://github.com/axisvela/praxo-core/tree/main/language/rust/application).
It passes 6/6 local tests, uses an application-owned `GatewayAdapter`, and records
model-selected tools plus `agent_trace`. The live path is wired, but the local TLS
backend build is blocked by missing native C headers for `ring`, so no Rust live
run is recorded. The C++ counterpart is implemented at
[`language/cpp/application`](https://github.com/axisvela/praxo-core/tree/main/language/cpp/application):
it passes five local CLI checks, uses an application-owned `GatewayAdapter`, and
records `agent_trace`. C++ live is not implemented because the Core adapter
requires an application-supplied HTTP transport. Priority 6 is implemented at
[`language/cobol/application`](https://github.com/axisvela/praxo-core/tree/main/language/cobol/application):
a native `praxo-run` batch analyst passes five deterministic checks plus a
batch-file check; private records, direct posting, and tenant mismatch are
denied, and no executable is committed. COBOL has no bundled HTTP/TLS transport,
so no live run is recorded. Priorities 7-8 remain proposals. Other languages
implement AI-native applications directly.

Deterministic harness tests are not live-model reasoning evidence. PHP, Elixir,
Erlang, and Go now have recorded live-model runs; Java, Rust, C++, and COBOL do
not. A claim of AI-native verification requires the live model id, model-selected tools,
generated content, policy boundaries, trace, and cost/latency. Track delivery in
[#34](https://github.com/axisvela/praxo-core/issues/34).

Each reference application needs reproducible installation from the selected
published Core package, a real host entry point, a useful end-to-end task, a
credential-free deterministic test mode, a separately runnable live-model path,
explicit tool policy, denial-before-effect and dependency-failure tests, expected
output, CI, and application-owned identity/state/effect boundaries. Record
source, host runtime execution, live provider, independent reproduction, and
continued use separately. A missing package, runtime, host, or credential is a
blocked claim, not a pass. No new Core API is assumed.

For PHP, Elixir, Erlang, and COBOL in particular, the question is no longer whether
the language can implement an agent. It is whether Core can use the existing
application ecosystem and runtime to solve a real task with less integration and
operational friction than simpler workflows or external orchestration. Measure
that trade-off; do not infer it from language coverage or low competition.

External verification requests are tracked in
[#30](https://github.com/axisvela/praxo-core/issues/30) (independent timing),
[#31](https://github.com/axisvela/praxo-core/issues/31) (hosted endpoint),
[#32](https://github.com/axisvela/praxo-core/issues/32) (external consumer path),
and [#33](https://github.com/axisvela/praxo-core/issues/33) (registry installs).
Closing an internal documentation gap does not close an external evidence gap.

## Adoption Evidence

Adoption work answers three separate questions: can developers discover the
framework, can they complete a directed integration, and can they maintain it
through change? The [adoption baseline protocol](adoption-baseline.md) records
the detailed evaluation method.

Those experiments should improve documentation after practical paths exist.
They do not block quickstarts, examples, or integrations from being published.
Useful signals are time to first result, completion rate, repair effort, issue
quality, upgrades completed, and continued use in real projects. Registry
downloads alone are not adoption.

## Deferred Until Adoption Paths Are Stable

- Expanding Behavior Lab or compatibility matrices for count alone.
- New language Kernels, repositories, or broad adapter sets without a named
  consumer, a maintainer, a real deployment path, and integration evidence.
- A durable execution module until a consumer needs crash-step recovery, pending
  approvals, effect cursors, or exactly-once semantics and provides real
  recovery tests.
- Re-running every historical evidence record after documentation changes.
- Broad coding-agent skill comparisons and repeated adoption experiments.
- Full fault, load, live-provider, and operational evidence for integrations
  without an active consumer.
- Additional language implementations or adapters without a maintainer and use
  case.
- Embodied simulation, hardware, or robotics middleware as a general SDK goal.

These remain valuable later-stage activities; they are not the first developer
experience.

## Ecosystem Boundaries

PRAXO-CORE is the reusable MIT framework, not a product platform. PRAXOVELA,
AKROVELA, other AxisVela products, and independent applications consume the same
public contracts while owning their own state, identity, policy services,
workflow, networking, deployment, and user experience.

Core provides model, tool, policy, event, checkpoint, plugin, stream, and
workspace seams. It does not operate an identity provider, policy decision
service, workflow engine, effect ledger, network control plane, or managed
sandbox. See [ecosystem integration](../integrations/ecosystem.md) for optional
AxisVela mappings.

## Compatibility Commitments

- Keep the public Go API small and preserve the MIT boundary.
- Keep shared wire changes explicit in `spec/`.
- Do not widen the Go API merely to simplify a language port or example.
- Let each language keep an idiomatic API; ports are not required to mirror Go
  internals.
- Prefer examples and adapters until a consumer proves a reusable Core gap.
- Preserve published URLs and provide migration guidance for breaking changes.

See [compatibility policy](compatibility-policy.md),
[Core support](../languages/support.md), and
[language policy](../contributing/language-policy.md).

## Status and Delivered Work

The roadmap explains direction. Detailed status and verification remain in:

- [Contract and Evidence Status](contract-status.md)
- [Release history](../releases/index.md)
- [Verification evidence](verification-evidence.md)
- [Complete changelog](https://github.com/axisvela/praxo-core/blob/main/CHANGELOG.md)
