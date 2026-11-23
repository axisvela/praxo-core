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

- Present one concise task-to-path table across the landing and getting-started
  pages.
- Separate "try the framework" from "verify a package" and "harden a deployment."
- Describe language support in terms of what a developer can build, not only
  contract tier or test coverage.
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
cross-language parity guarantee. Ruby's SE-07 FinOps slice now has local
source-mode tests; its CI job is added but not yet run. No cloud mutation or
live-model evidence is claimed.

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
  Local R 4.6.1 checks pass; the Linux CI job is added but not yet run. It does
  not send messages, launch a campaign, read arbitrary data or use a live model.
  R's `Tutorial/wealth-analysis/` computes weighted risk `0.54` and concentration
  `0.60` over a fixed `acct-100` portfolio, recommends `rebalance`, and drafts a
  review-only proposal with `trades_executed=0`. Local R 4.6.1 checks pass; the
  Linux CI job is added but not yet run. It does not trade, use market data, give
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
  gfortran 16.2.0/RE2 checks pass; the Linux CI job is added but not yet run. It
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
  `StructuredOutputError`). Local Python 3.14 checks pass; the Linux CI job is
  added but not yet run. It does not execute a payment, decide coverage, read
  arbitrary files or use a live model.
  Python's `Tutorial/legal-compliance/` searches fixed policy fixtures for a
  citation and gates `publish_memo` behind a Core interrupt: approval runs the
  simulated publish, rejection raises `ApprovalDeniedError` with zero
  publications, and an out-of-scope query is policy-denied before the read. Local
  Python 3.14 checks pass; the Linux CI job is added but not yet run. It does not
  give legal advice, record a real approval, write a document store or use a live
  model.
  Python's `Tutorial/education-tutoring/` implements the Core `Retriever` protocol
  with an application-owned `LessonRetriever` returning typed `Document`s, cites
  `lesson-fractions`, and drafts a review-only study plan with
  `assignments_created=0`. Local Python 3.14 checks pass; the Linux CI job is added
  but not yet run. It does not use student data, create assignments, guarantee
  curriculum correctness or call a live model.
  TypeScript's `Tutorial/customer-support/` streams a cited support reply over
  SSE with fixed order/policy tools, authentication, denial and dependency-failure
  checks. Local Node 24 checks pass, and Linux CI passed at `39558592` (run
  `45086046576`). It does not send replies, change orders, issue refunds or use a
  live model.
  TypeScript's `Tutorial/travel-booking/` checks fixed `trip-100` inventory and
  drafts a review-only fare hold with `payment_executed=false` and
  `bookings_writes=0`; `trip-200` is policy-denied and a simulated inventory error
  fails after one read. Local Node 24 checks pass; the Linux CI job is added but
  not yet run. It does not pay, ticket, change inventory or call a live model.
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
  one read. Local .NET 8 build and self-tests pass; the Linux CI job is added but
  not yet run. It does not write the schedule, confirm the booking, use patient
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
  `event.FuncSink`. Local `go test` and `go run --test` pass; the Linux CI job is
  added but not yet run. It does not connect a real incident system, start a
  durable workflow, mutate an incident or call a live model.
  Go's `Tutorial/soc-alert-triage/` reads a fixed `alert-100` snapshot through an
  application-owned `AlertSource`, redacts reporter email and phone with Core's
  `PIIRedactor`, drafts a review-only `isolate_host` and records audit events
  through an `event.FuncSink`. Local `go test` and `go run --test` pass and assert
  the raw PII is absent; the Linux CI job is added but not yet run. It does not
  connect a real SIEM, run a host action, call a live model, or redact live tool
  arguments, errors or event payloads.
  Go's `Tutorial/logistics-checkpoint/` assesses a fixed `shipment-100`, serializes
  the transcript into a `checkpoint.Checkpoint`, and resumes a second run that
  drafts a review-only reroute without re-reading the shipment (`reads` stays 1,
  `drafts` reaches 1) and saves an extended checkpoint. Local `go test` and
  `go run --test` pass; the Linux CI job is added but not yet run. The store is an
  in-memory JSON round-trip, not a database, concurrent store or exactly-once
  proof, and it does not connect a real logistics system or use a live model.
  Go's `Tutorial/evidence-vault/` reads one allowlisted `evidence-100.txt` from a
  `vfs/localfs` backend confined to a vault root, rejects `../secret.txt` and
  absolute paths, and drafts a review-only finding with `case_writes=0`. Local
  `go test` and `go run --test` pass and assert containment; the Linux CI job is
  added but not yet run. The vault is a temporary directory, not an encrypted
  store or production sandbox, and the tutorial connects no case system or live
  model.
  C's `Tutorial/device-diagnostics/` reads a fixed `device-100` snapshot through an
  application-owned `PxDeviceAdapter` function pointer and drafts a
  `notify_operator` review action. Local MinGW gcc/CMake checks pass; the Linux CI
  job is added but not yet run. It does not implement a serial bus, socket, device
  SDK, device command or a live model.
  C++'s `Tutorial/industrial-edge/` reads a fixed `edge-100` snapshot through an
  application-owned `DeviceAdapter` interface and drafts a `schedule_maintenance`
  review action, with a failing adapter raising `DEVICE_READ_FAILED`. Local MinGW
  g++/CMake checks pass; the Linux CI job is added but not yet run. It does not
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

1. Close the discovery and classification gap before adding languages: make
   package descriptions say "AI agent framework" rather than ambiguous "agent",
   keep the coding-agent package map generated from or checked against release
   metadata, and record how external indexes classify the project.
2. Validate one consumer-selected embedding path: deterministic install/run/deny,
   then a real provider tool call. Measure time, repairs, and author assistance.
3. Seek one independent framework consumer and one third-party reproduction.
   Record real provider, MCP, and Harmovela checks separately; a combined-chain
   claim requires one recorded run exercising that chain.
4. Deepen only the gaps demonstrated by that consumer, starting with a controlled
   delegation semantics review if required. Reuse existing checkpoint-store
   recipes before adding another store or public API.
5. Keep evidence layers and example depth explicit, and publish a task tutorial
   from the validated path rather than opening another broad SDK campaign.

These priorities favor fewer complete paths over more isolated features. A
single Go example is not sufficient evidence that the developer path works for
the other language SDKs, and registry downloads alone are not adoption.

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
