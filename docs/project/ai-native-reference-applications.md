# AI-Native Reference Applications

**Status:** design accepted 2026-11-25. PHP v1 harness is implemented locally at
`language/php/application/ai-editorial-studio`; the sibling `content-review`
application remains a host-integration precursor. Java v1 source is added at
`language/java/application` using Spring Boot and published Core 0.11.0, but the
local Windows JVM is blocked, so Java has not been compiled or tested locally.
Elixir v1 harness is implemented locally at `language/elixir/application` with a
supervised telemetry store and remediation executor; source-mode tests pass 6/6,
including tenant denial and supervisor restart, and the result records model
diagnosis/rationale plus `agent_trace`. The local Hex install hit an unknown-CA
failure, so the CI job uses the published package and is added but not run. Erlang
v1 is implemented at `language/erlang/application`; source-mode tests pass 6/6,
including supervisor restart, and the live run records model diagnosis/rationale
plus `agent_trace`. Go v1 is implemented at `language/go/application` with an
HTTP/CLI host; 8/8 tests pass, and the live run records model-selected tools,
diagnosis/rationale, and `agent_trace`. Rust v1 is implemented at
`language/rust/application` with an edge CLI and `GatewayAdapter`; 6/6 tests pass,
and a hosted DeepSeek live run records `model=live`, model-selected tools, a
review-only draft, and `executions=0` through an application-owned `curl`
transport. C++ v1 is
implemented at `language/cpp/application`; five local CLI checks pass, and its
live path is not implemented because the Core adapter requires an
application-supplied HTTP transport. COBOL v1 is implemented at
`language/cobol/application`; its native `praxo-run` harness passes five
deterministic checks and a batch-file check, but no live-model transport is
bundled. Julia v1 is implemented at `language/julia/application`; its native
`LinearAlgebra` response-surface harness passes six deterministic checks and a
hosted DeepSeek `deepseek-flash` live run records `model=live`, model-selected
tools, computed fit evidence, and `writes=0`. Ruby v1 is implemented at
`language/ruby/application`; a Rails 8 host passes five deterministic checks and
a hosted DeepSeek `deepseek-flash` live run records `model=live`, model-selected
tools, a review-only draft, and zero payment/refund effects. PHP, Elixir, Erlang,
Go, Rust, Julia, and Ruby have recorded live-model reasoning runs with hosted
DeepSeek `deepseek-flash`; Java/C++/COBOL live reasoning, SDK CI, Drupal, payment,
and independent-consumer paths remain open. Other languages implement the
AI-native workflow directly.

## Purpose

The [reference application portfolio](roadmap.md#reference-application-portfolio)
selects a typical workload for each language. This design adds the missing
quality bar: the agent must be the primary product workflow, not an assistant
bolted onto a conventional application.

A CRUD portal with one "review with AI" endpoint does not qualify. An AI-native
reference application starts from a user intent or model decision, retrieves host
context, chooses tools, produces a useful artifact or draft, and stops at an
application-owned approval or effect boundary.

## Definition

An AI-native reference application satisfies all of these:

1. The primary user task begins with natural language or a model-driven decision,
   not only a pre-existing record selected from a list.
2. The application retrieves and labels host context; the model decides the next
   step and tool calls.
3. The host remains the system of record. High-risk effects stay application-owned
   and policy-gated.
4. A credential-free deterministic mode exercises the same loop and policy.
5. A live-model mode reuses the same tools and policy and is recorded separately.
6. Human review or approval is a first-class boundary for publication, payment,
   device commands, or other high-impact effects.
7. Tests cover a useful result, denial before effect, dependency failure, and
   invalid model output.
8. The integration uses the host's real routing, service container, identity,
   persistence, events, and deployment shape where applicable.

### Acceptance question

If the model is removed, does the product's primary workflow disappear?

- **Yes:** the application is AI-native.
- **No:** it is a traditional application with an optional AI feature.

### Anti-patterns

- A static form whose only AI step summarizes an existing record.
- A chat panel that can read data but is outside the main product workflow.
- A model that writes directly to the CMS, order system, or device.
- A demo that proves tool-calling but not a useful host-owned task.
- A live-model-only path with no deterministic replay.

## Scenario Map

The agent drives the primary workflow below. The host remains the system of
record and owns identity, persistence, approval, and effect reconciliation.

| Priority | Language | AI-native product | Primary workflow | Host integration | Governance and effects |
| --- | --- | --- | --- | --- | --- |
| 1 | PHP | AI editorial studio for a content portal/CMS | Brief -> retrieve existing content -> draft article, taxonomy and SEO -> request publish review | Laravel first; Drupal module next | No CMS write; review-only publication; `publications_executed=0` |
| 2 | Java | AI commerce assistant | Natural-language discovery -> compare -> cart/checkout draft -> order/refund approval | Spring Boot commerce services | Application transactions versus remote effects; no payment without approval |
| 3 | Elixir / Erlang | Real-time operations copilot | Telemetry/anomaly -> triage -> remediation draft -> approval | OTP supervision and messaging | Bounded work, cancel/reconcile, no unreviewed remediation |
| 4 | Go | Infrastructure operator | Alert -> diagnosis -> allowlisted remediation draft | Existing service/CLI and control-plane clients | Read-only first; mutation requires explicit approval |
| 5 | C++ / Rust | Edge/device agent | Sensor or telemetry -> diagnosis -> bounded action draft | Concrete device SDK, simulator or transport | Command authorization, cancel acknowledgement, effect verification |
| 6 | COBOL | Batch exception analyst | Batch -> exception -> analysis -> review handoff | Existing batch estate | No posting; primary batch output unchanged |
| 7 | Julia | Scientific copilot | Dataset/model -> numerical analysis or optimization -> evidence-linked report | Existing numerical stack | No device or production control; reproducibility limits stated |
| 8 | Ruby | Commerce/SaaS assistant | Customer intent -> account/order tools -> draft action | Rails services, Active Record/Active Job | No external exactly-once claim; approval and effect reconciliation |

Additional typical AI-native directions:

| Language | AI-native direction |
| --- | --- |
| Python | Data/AI pipeline copilot or Django/FastAPI service assistant |
| TypeScript | Storefront or BFF assistant with streaming UI |
| C# | Enterprise service-desk or line-of-business copilot |
| Perl | Legacy log/ticket analyst |
| Lua | Host/game extension assistant |
| C | Constrained embedded diagnostic component |
| Fortran | Simulation-analysis assistant |
| R | Statistical analysis and reporting assistant |
| PowerShell | Windows/IT operations assistant |
| MATLAB/Octave | Signal-analysis assistant |
| Swift/Kotlin/Scala/Dart | Platform-specific app or service assistant |
| Haskell/OCaml | Compiler or static-analysis assistant |
| Zig/D/Nim/V | Systems or CLI assistant |
| Delphi/Objective-C | Desktop or Apple legacy application assistant |

These are selection hypotheses, not market rankings. Every candidate must pass the
AI-native acceptance question and the reference-application evidence standard.

## PHP v1: AI Editorial Studio

### Product flow

1. An editor submits a brief, target section, and tenant.
2. The agent searches the application-owned content index for related material.
3. The agent drafts a title, outline, body, tags, and SEO description.
4. The agent creates a review-only publication request.
5. The editor approves, edits, or rejects in the host application.
6. The application performs the CMS effect; the agent never writes directly.

### Host surface

- `POST /api/editorial/drafts` with a brief and authenticated tenant.
- Artisan command `content:draft-article` for the same workflow.
- Laravel route, middleware, container bindings, configuration, and content index.
- Drupal is the next host: map the same workflow to CMS entities, editorial
  workflow states, and permissions. Do not vendor Drupal core into this MIT
  repository; keep the module code MIT and treat Drupal as an external GPL
  dependency.

### Tools

| Tool | Effect | Policy |
| --- | --- | --- |
| `search_content` | Read-only retrieval from the host index | Tenant and brief scope; labels retrieved content as untrusted |
| `draft_article` | Produces a draft artifact only | No CMS write; output schema validated |
| `suggest_taxonomy` | Suggests tags and section | Read-only |
| `request_publish_review` | Creates a review-only request | Requires approval boundary; no publication |
| `publish_article` | Would write to the CMS | Always denied in the agent path; a separate approved host workflow performs it |

### Governance

- The model never holds publication authority.
- Policy checks tenant, brief scope, tool name, and final arguments after edits.
- A direct "publish immediately" brief is denied before any CMS effect.
- Retrieved content is untrusted data, not system instruction.
- Output is validated before it becomes a review item.
- The application owns the approval UI, audit record, and CMS write.

### Deterministic and live modes

- The deterministic model exercises retrieval, drafting, taxonomy, and review
  request, then returns a schema-validated package.
- The live model uses the same schemas and policy. Record provider, endpoint,
  cost, latency, and failures separately.
- Tests must not require credentials.

### Required tests

- Useful draft with sources and `publications_executed=0`.
- Direct-publish brief denied before effect.
- Missing or mismatched tenant denied before retrieval.
- Content-index dependency failure after one read and no draft.
- Invalid model output rejected.
- Artisan path matches the HTTP workflow.
- Optional live-model run recorded separately.

## Java v2 Sketch

The order/checkout scenario is reserved for Java, where e-commerce is the typical
host. An AI-native Java reference would:

- accept a natural-language shopping intent;
- retrieve catalog, inventory, pricing, and order context;
- compare options and draft a cart or checkout step;
- stop at payment and refund approval boundaries;
- use Spring Boot services, security principal propagation, and transactions,
  while distinguishing local transactions from remote effects.

No payment, refund, or inventory write is claimed without an approved host path.

## Cross-Language Invariants

- The agent proposes; the application authorizes and performs high-impact effects.
- Tools are application-owned and narrow.
- Policy is evaluated at the effect boundary and after argument edits.
- Retrieved or model-generated content is untrusted.
- Deterministic tests are the baseline; live-model runs are separate evidence.
- A reference application is not a new Core API. Application-specific logic stays
  in the host.
- Evidence states source, host runtime, live provider, independent reproduction,
  and continued use separately.

## Reasoning Evidence

Deterministic or scripted models are test doubles. They can prove tool schemas,
policy, approval boundaries, failure handling, and trace plumbing; they do not
prove LLM reasoning.

An AI-native reasoning claim requires a recorded live-model run that shows:

1. the model selects tools and arguments from the request and prior observations;
2. host tools return observations;
3. the model writes the diagnosis, draft, rationale, or answer;
4. policy and approval boundaries still apply;
5. the run records model id, endpoint class, tool trace, latency, and cost;
6. the output or trace is inspectable and is not only fixed fixture text.

Current status (2026-11-25): PHP, Elixir, Erlang, Go, Rust, Julia, and Ruby have
recorded live-model reasoning runs with hosted DeepSeek `deepseek-flash`.

- PHP recorded `model=live`, a four-step trace (`search_content` ->
  `draft_article` -> `suggest_taxonomy` -> `request_publish_review`), a
  model-written rationale (858 characters in the latest run), and
  `publications_executed=0`. The run used a custom cURL transport for the local
  proxy/CA.
- Elixir recorded `model=live`: the model chose `search_signals(service-100)`,
  then `draft_remediation` with a model-written diagnosis and rationale, and
  finished with `executions=0`. An earlier attempt used the display name
  `checkout` and was policy-denied before the authorized service id was added to
  the prompt.
- Erlang recorded `model=live` with the same tool sequence and a model-written
  diagnosis/rationale; `executions=0`. The live transport used `httpc` with the
  local proxy/CA.
- Go recorded `model=live`, a three-step trace (`search_signals` ->
  `draft_remediation` -> final report), a 350-character diagnosis and
  523-character rationale, and `executions=0`.
- Rust recorded `model=live`: the model chose `read_gateway` then `draft_action`
  with a model-written diagnosis/rationale, and finished with `executions=0`.
  The live path uses an application-owned `curl` transport, avoiding the local
  `ring`/TLS build blocker.
- C++ has deterministic harness tests, but no live path is implemented because
  the Core adapter requires an application-supplied HTTP transport.
- COBOL has a native deterministic harness and a batch-file check, but the Core
  COBOL package has no bundled HTTP/TLS client, so no live run is recorded.
- Julia recorded `model=live`: the model chose `load_observations` then
  `fit_response_surface`; the report kept the computed quadratic (R²
  `0.999995`), bounded optimum `0.6994`, predicted yield `0.91764`, `writes=0`,
  and `mutating_actions=[]`. The Windows transport used `curl.exe` with
  `--ssl-no-revoke`.
- Ruby recorded `model=live`: the model chose repeated `search_catalog` reads,
  then `quote_cart` and `draft_order`. The app returned a `draft_only` order,
  a `$105.84` quoted total, `payment_charges=0`, `refunds=0`, and
  `mutating_actions=[]`. The Windows transport used `curl.exe --ssl-no-revoke`.

Java remains source-only and is not locally compiled; it has no live-model run.
Deterministic harness tests remain separate evidence and are not a substitute for
the live runs.

## Evidence Standard

| Level | Required for the reference application |
| --- | --- |
| Deterministic | HTTP/CLI success, denial before effect, dependency failure, invalid output |
| Host runtime | Real framework boot, container, config, identity boundary, and host services |
| Live model | Optional, separately recorded; same tools and policy |
| Independent | External consumer reproduction, not a maintainer fixture |
| Continued use | A later change or upgrade after adoption |

A missing package, host, runtime, or credential is a blocked claim, not a pass.

## Migration From the Current Baseline

- The Laravel content-review application remains a precursor baseline at
  `language/php/application/content-review/`.
- The AI-native PHP v1 is implemented at
  `language/php/application/ai-editorial-studio/` and does not replace or relabel
  the precursor.
- Both PHP applications use the published Core package and have deterministic
  local tests; CI is added but not run.
- Move order/checkout work to the Java e-commerce reference.
- Other languages implement the AI-native workflow directly, without a
  traditional-app precursor.
- Existing tutorials remain tutorials; reference applications live at
  `language/<language>/application/`.

## Open Decisions

1. Laravel first or Drupal first for PHP. Proposal: Laravel first for host
   plumbing, then Drupal for CMS-native workflow and permissions.
2. Content index implementation: fixture, SQLite, or CMS API.
3. Draft persistence: in-memory, database, or CMS revision.
4. Approval surface: HTTP route, queue, or CMS editorial workflow.
5. Live provider and model choice.
6. Exact output schema and validation strictness.
7. Whether any reusable gap justifies a Core API. Default: no.

## Implementation Sequence After Approval

1. Update the roadmap and tutorial-plan status to link this design.
2. Implement the PHP AI editorial studio with deterministic tests.
3. Add CI and an optional live-model command.
4. Record evidence and update the tracking issue.
5. Start the Java e-commerce assistant.
6. Add the Drupal host and record its licensing and deployment boundary.
7. Continue the ordered portfolio only with maintainer capacity and consumer
   feedback.

## Risks

- Model output quality is nondeterministic; validate schema and sources.
- Scope creep into CMS publication; keep the agent review-only.
- Drupal's GPL dependency must stay external to the MIT repository.
- Cost and latency must be measured, not inferred.
- AI-native claims can inflate; require the acceptance question and evidence.
- Prompt injection through retrieved content must not gain system authority.
