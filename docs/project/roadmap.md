# Public Roadmap

Current core release: `2.7.0`.

This roadmap is organized around developer outcomes: choose the framework,
run something useful, build a real prototype, embed it in an application, and
then harden that integration. It is not a delivery schedule, a product roadmap,
or a promise that every language implementation supports every feature.

## Next-stage Direction

**Planning update: 2026-11-13.** The immediate priority is to shorten the path
from discovery to a useful project. New users should not need to understand the
full specification, evidence taxonomy, cross-language matrices, or advanced
execution profiles before they can build an agent.

PRAXO-CORE remains a **governed, embeddable agent execution framework**. The
roadmap favors runnable applications and clear integration boundaries over new
language, adapter, profile, or test counts.

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

## Adoption Path

| Stage | Developer outcome | Current state | Next result |
| --- | --- | --- | --- |
| 0. Decide | Know whether Core fits and which language/path to use | The overview, task chooser, comparison, and non-goals exist | Make the choice path shorter and show application responsibilities clearly |
| 1. Run | Install a published package, connect a model, register one tool, and get a useful result | Published-package deterministic starters and four-language live-model examples now exist | Run the live path against supported endpoints and record language-specific troubleshooting |
| 2. Prototype | Build one coherent local application with tools, streaming, structured output, MCP, workspace access, or telemetry | A task-oriented catalog, workspace tutorial, provider/MCP walkthrough, structured-output examples, and local MCP examples, plus cross-language structured-output and MCP tutorials, exist | Add MCP examples for the remaining SDKs and more language-specific prototype tutorials |
| 3. Embed | Integrate Core into an existing service with application-owned identity, policy, persistence, events, and shutdown | Vendor-neutral Go/Python HTTP services, verified-identity and durable-checkpoint variants, and a risk-tiered checklist exist | Add a live identity/policy service integration and more language service examples |
| 4. Harden | Make the specific integration safe to upgrade, fail, cancel, and recover | Negative, upgrade, containment, and recovery assets exist | Organize them by application risk instead of requiring everything up front |
| 5. Extend | Adopt plugins, delegation, long-running operations, workspace providers, or embodied integrations when needed | Experimental and advanced assets exist | Advance only with a named consumer and a concrete project need |

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

Contract status and evidence remain available in
[Contract and Evidence Status](contract-status.md), but are not prerequisites for
the first project.

## Stage 1: Run a Useful Agent

### Developer Outcome

From an empty directory, install a published package, connect Ollama or an
OpenAI-compatible endpoint, register one low-risk tool, and see a model response
or tool result in 15-30 minutes.

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
- Examples under `examples/`, including `reference`, `governed-workspace`,
  `checkpoint`, `plugin`, and `recipes`

### Next Work

- Extend the examples catalog with Basic, Integration, Hardening, and Advanced
  groups and mark package/source mode, credentials, local command execution,
  external services, and maturity.
- Add one coherent prototype tutorial for each primary SDK, starting from the
  existing [workspace tutorial](../guides/workspace-agent-tutorial.md).
- Add runnable MCP client examples for the remaining SDKs; Python and TypeScript
  stdio examples and a C# in-process example are available under their language
  `examples/mcp` directories.
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

- Add a live identity/policy service integration or another language service
  variant, building on the
  [authenticated service example](https://github.com/axisvela/praxo-core/tree/main/examples/embedded-service-auth).
- Keep the [application integration checklist](../guides/application-integration-checklist.md)
  aligned with the read-only, side-effecting, and high-risk tiers.
- Provide a minimal durable checkpoint path between the teaching examples and
  the advanced long-running operation fixture.

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

Do not prioritize new ROS, workspace-provider, language, or generic asynchronous
action APIs without a named consumer and a concrete gap.

## Current Priorities

1. Published-package live-model golden paths across the main SDKs, starting with
   Go, Python, TypeScript, and Java.
2. A language-aware, task-oriented example catalog.
3. One complete practical prototype tutorial per primary SDK, not only Go.
4. Vendor-neutral application integration samples in representative languages.
5. Risk-tiered production and maintenance checklists that state language support
   explicitly.

These priorities favor fewer complete paths over more isolated features. A
single Go example is not sufficient evidence that the developer path works for
the other language SDKs.

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
