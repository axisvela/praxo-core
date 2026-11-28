# Public Roadmap

Current core release: `2.11.3`.

This roadmap is organized around developer outcomes: choose the framework,
run something useful, build a real prototype, embed it in an application, and
then harden that integration. It is not a delivery schedule, a product roadmap,
or a promise that every language implementation supports every feature.

## Related Pages

- [Delivery History and Application Status](../status/delivery-history.md) records delivered stages, application status, and adoption evidence.
- [Contract Status](../status/contract-status.md) records the current contract and evidence snapshot.
- [Verification Evidence](../evaluation/verification-evidence.md) records exact runs and limits.

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
five-minute timing, hosted starter-path validation, an external consumer-selected
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
the [catalog](../../getting-started/tutorial-catalog.md) separates related slices
from full applications. Tutorial CI passed at `dfdfd558` in run `45537631891`;
this is revision-scoped fixture evidence, not external adoption. The next bounded
work is ecosystem-native reference applications, with selection-to-validation
measurement supporting those paths, not another language-count campaign. Discovery materials exist, but their effect
on unaided framework choice remains unmeasured outside the recorded pilot.

**Planning update: 2026-11-24 (basic-entry phase).** Scenario breadth does not
establish language fit. That phase prioritized batch completion of basic scenario
entry points, discovery and attracting users before broad optimization. Keep each
entry accurately scoped and assess mappings against the
[language selection gate](../../getting-started/tutorial-plan.md#language-selection-gate).
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
[language implementation matrix](../../languages/index.md) and
[support policy](../../languages/support.md).

| Scope | Languages | Roadmap expectation |
| --- | --- | --- |
| Reference | Go | Defines shared behavior and leads reference examples |
| Independently implemented Core | Core SDKs listed in the matrix | Share adoption stages and receive runnable provider, tool, and integration paths where practical; runtime and ecosystem limits stay per language |
| Shared-runtime, Bridge, and Sample entries | Other matrix entries | Use per-language documentation and state gaps explicitly; no promise of every example or feature |

The roadmap does not require every language to publish every example at the same
time. It does require user-facing paths to say which language and package they
target and not to present Go-only behavior as a cross-language guarantee.
Language count is not a goal: read `complete` as contract-complete, and check
[Adapter Status](../../languages/adapter-status.md) for the separate adapter and
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
| 1. Run | Install a published package, connect a model, register one tool, and get a useful result | Published-package deterministic starters and live-model examples exist; five-minute completion has not been independently measured. Registry state is recorded separately in the language support pages. The live-model guide covers endpoint, model id, credential, timeout, tool schema, and platform troubleshooting. Local Ollama tool-call runs are recorded for Go, Python, TypeScript, C#, and Rust (C# and Rust via built binaries); hosted verification of this starter path is not recorded. Seven separate reference applications have hosted live-model runs, not starter-path acceptance. The local Java JVM remains blocked | Record independent deterministic and live-endpoint completion separately; hosted starter-path validation is tracked in [#31](https://github.com/axisvela/praxo-core/issues/31) and independent timing in [#30](https://github.com/axisvela/praxo-core/issues/30) |
| 2. Prototype | Build one coherent local application with tools, streaming, structured output, MCP, workspace access, or telemetry | Thirteen example themes have source entries across thirty-one languages. The catalog is grouped by task, and a first-pass source-depth audit now labels Core references, mechanism checks, and transport-neutral handlers; it does not certify execution. End-to-end prototype tutorials now include the Go Workspace Agent and the Python structured-output application; most other examples remain integration checks | Turn the source-depth audit into recorded runs for one consumer-selected application path; external validation is tracked in [#32](https://github.com/axisvela/praxo-core/issues/32) |
| 3. Embed | Integrate Core into an existing service with application-owned identity, policy, persistence, events, and shutdown | Vendor-neutral Go/Python/TypeScript/C# HTTP services and authenticated identity/policy services; Go, Python, TypeScript, C#, Ruby, PHP, and Rust support OIDC/JWKS with provider discovery; the Java example passes in Linux CI, while its local Windows JVM is blocked; 30 of 31 declared implementations have source-level RFC 7662 introspection and RFC 7009 revocation, with 29 runtime-verified locally (28 native runtimes plus Octave for the shared MATLAB/Octave module), native MATLAB unverified, and COBOL boundary-only; an optional external Python policy decision service, verified-identity and durable-checkpoint variants, a risk-tiered checklist, and a checkpoint-continuation guide connecting message history, allowlisted stores, and operation state exist | Extend OIDC/external identity to further SDKs, close registry publication gaps for consumer-selected languages, record native MATLAB separately, and validate the checkpoint store for a real consumer |
| 4. Harden | Make the specific integration safe to upgrade, fail, cancel, and recover | Negative, upgrade, containment, and recovery assets exist. The Go memory-role fix is released in `2.9.0`; retry hazard tests have local deterministic coverage. A source audit found no automatic recall in other SDK agent paths or in the Bridge `run`/`event stream` paths. The consumer test template now covers two-run memory trust, unknown-effect retry/reconciliation, and language-specific starting points. It has been run against 9 of 10 maintainer-owned fixtures; the local Java run timed out, and these are not external consumers | Apply the template to an external consumer; repository fixtures are not a substitute. Tracked in [#32](https://github.com/axisvela/praxo-core/issues/32) |
| 5. Extend | Adopt plugins, delegation, long-running operations, workspace providers, or embodied integrations when needed | Application-level delegation examples cover Go, Python, TypeScript, Java, C#, and Rust; Go reference examples cover long-running operations, workspaces, and plugins | Add controlled parent-to-child policy, tool-scope, budget, and depth narrowing before claiming governed delegation |

The stages describe the recommended order for adoption. They are not release
gates and do not require all languages to advance together.

## Current Priorities

1. **P0: Deliver ecosystem-native reference applications.** Follow the ordered
   portfolio below, starting with the PHP business application. Prove integration
   with an existing host and its runtime behavior, not another generic agent loop.
   Deliver one coherent path before expanding the next; these are proposed
   acceptance targets with source implementations, not completed host integrations
   or a commitment to parallel delivery.
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
   [Agent Selection Benchmark](../evaluation/adoption-baseline.md#next-stage-agent-selection-benchmark)
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

## Reference Application Portfolio

Moved to [Delivery History and Application Status](../status/delivery-history.md#reference-application-portfolio).

## Adoption Evidence

Moved to [Delivery History and Application Status](../status/delivery-history.md#adoption-evidence).


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
sandbox. See [ecosystem integration](../../integrations/ecosystem.md) for optional
AxisVela mappings.

## Compatibility Commitments

- Keep the public Go API small and preserve the MIT boundary.
- Keep shared wire changes explicit in `spec/`.
- Do not widen the Go API merely to simplify a language port or example.
- Let each language keep an idiomatic API; ports are not required to mirror Go
  internals.
- Prefer examples and adapters until a consumer proves a reusable Core gap.
- Preserve published URLs and provide migration guidance for breaking changes.

See [compatibility policy](../status/compatibility-policy.md),
[Core support](../../languages/support.md), and
[language policy](../../contributing/language-policy.md).

## Status and Delivered Work

Moved to [Delivery History and Application Status](../status/delivery-history.md#status-and-delivered-work).

## Adoption Stages

Stage details moved to [Delivery History and Application Status](../status/delivery-history.md#adoption-stages).

<a id="stage-0-decide-whether-core-fits"></a>
<a id="stage-1-run-a-useful-agent"></a>
<a id="stage-2-build-a-real-prototype"></a>
<a id="stage-3-embed-core-in-an-application"></a>
<a id="stage-4-harden-and-maintain"></a>
<a id="stage-5-advanced-and-experimental-integrations"></a>
