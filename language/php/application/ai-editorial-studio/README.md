# AI Editorial Studio (PHP AI-native reference application)

A Laravel 12 content-portal application where the agent drives the primary
editorial workflow: an editor submits a brief, the agent retrieves related
content, drafts an article package, suggests taxonomy, and creates a review-only
publication request. The application never publishes from the agent path.

This is the AI-native PHP reference application. The sibling `../content-review/`
app is a host-integration precursor and is not AI-native.

## Why this language and runtime?

- **Selection basis:** PHP commonly hosts content management systems, editorial
  portals, and back-office applications. The typical AI-native workflow is
  content generation and editorial review, not order processing.
- **Demonstrated fit:** Laravel routing, tenant middleware, container bindings,
  configuration, an application-owned content index and draft repository, tool
  policy, and an Artisan command all participate in a brief-to-review workflow.
- **Choose when:** Adding an AI editorial studio to an existing PHP content portal
  or CMS where editors already own publishing authority.
- **Do not choose when:** A deterministic template workflow, an existing CMS
  approval chain, or an external moderation service solves the task with less
  integration and operational cost.
- **Evidence limit:** Deterministic tests plus one hosted live run; in-memory
  content index and draft repository. This is not Drupal yet, not a production
  CMS, not an independent consumer, and not a production deployment.

## AI-native workflow

1. `POST /api/editorial/drafts` with `{"brief": "..."}` and an authenticated tenant.
2. The agent searches the application-owned content index.
3. The model writes a draft title, outline, body, and SEO description.
4. The application saves the draft as `draft_only`.
5. The model suggests a section and tags.
6. The application creates a `review_requested` publication request.
7. An editor approves, edits, or rejects in the host application.
8. The host application performs any CMS publication outside the agent path.

If the model is removed, the primary workflow disappears. That is the AI-native
acceptance test.

## Where is the LLM reasoning?

The deterministic tests use a scripted model. They verify the harness, tool
policy, failure paths, and trace shape, not LLM reasoning.

In the live path, the model chooses retrieval and drafting tools, writes the
title/body/SEO/rationale, and decides what the taxonomy and review request should
contain. `agent_trace` records the model's tool calls and output, and `model` is
`"live"` rather than `"deterministic"`. A hosted DeepSeek `deepseek-flash` run on
2026-11-25 recorded `model=live`, a four-step trace
(`search_content` -> `draft_article` -> `suggest_taxonomy` ->
`request_publish_review`), a model-written rationale (858 characters in the latest
run), and
`publications_executed=0`. The model explicitly avoided inventing Q3 facts and
used placeholders for missing operational data. This is one local hosted run, not
independent reproduction or production deployment.

## Host integration

| Boundary | Where |
| --- | --- |
| Route and tenant middleware | `routes/api.php`, `app/Http/Middleware/RequireTenant.php` |
| Container wiring | `app/Providers/AppServiceProvider.php` |
| Configuration | `config/content.php`, `.env.example` |
| Content retrieval | `app/Contracts/ContentIndex.php`, `app/Services/FixtureContentIndex.php` |
| Draft and review state | `app/Contracts/DraftRepository.php`, `app/Services/InMemoryDraftRepository.php` |
| Governed agent | `app/Services/EditorialAgent.php`, `EditorialPolicy.php` |
| Tool schemas and model | `app/Services/SchemaTool.php`, `DeterministicEditorialModel.php` |
| CLI entry | `routes/console.php` |
| Tests | `tests/Feature/EditorialDraftTest.php` |

Identity, content persistence, editorial approval, audit, and CMS effects remain
application responsibilities. The tenant header is a teaching stand-in for a
verified principal.

## Tools and policy

| Tool | Effect | Policy |
| --- | --- | --- |
| `search_content` | Read-only content retrieval | Tenant and brief scope |
| `draft_article` | Saves a model-written draft artifact | Sources required; no CMS write |
| `suggest_taxonomy` | Saves section and tags on a draft | Draft must exist |
| `request_publish_review` | Creates a review-only request | Only `publish_review` |
| `publish_article` | Would publish to the CMS | Always denied in the agent path |

The model never holds publication authority. A brief such as
`Publish immediately: Q3 service update.` is denied before retrieval, drafting, or
publication.

## Requirements

- PHP 8.2 or newer with `openssl`, `mbstring`, `curl`, `fileinfo`, and `intl`.
- Composer 2.
- No database, model endpoint, or credentials are required for the tests.

## Install

Uses the published Packagist package `axisvela/praxo-core:0.8.1`.

```bash
cd language/php/application/ai-editorial-studio
composer install --no-interaction --prefer-dist
```

Run the deterministic tests:

```bash
vendor/bin/phpunit
```

Expected: nine tests pass, covering the generated package, tenant boundaries,
direct-publish denial, content-search failure, validation, Artisan success and
failure, and invalid model output.

## Deterministic run

```bash
php artisan content:draft-article "Write a Q3 service update for the news section."
```

Expected JSON includes:

- `report.draft.status = "draft_only"`
- `report.draft.rationale` from the model
- `report.taxonomy.section = "news"`
- `report.review.status = "review_requested"`
- `report.publications_executed = 0`
- `report.model = "deterministic"` for the fixture run
- `report.agent_trace` with tool calls and model output
- `agent.reads = 1`, `agent.drafts = 1`, `agent.reviews = 1`,
  `agent.publications = 0`

Direct publish attempt:

```bash
php artisan content:draft-article "Publish immediately: Q3 service update."
```

Expected: exit code 1 with `AGENT_POLICY_DENIED` and zero effects.

Simulated content-index failure:

```bash
php artisan content:draft-article "Write a Q3 service update." --simulate-failure
```

Expected: exit code 1 with `TOOL_ERROR` after one read and no draft or review.

## HTTP run

```bash
php artisan serve
curl -s -X POST http://127.0.0.1:8000/api/editorial/drafts \
  -H 'Content-Type: application/json' \
  -H 'X-Tenant-Id: acme' \
  -d '{"brief":"Write a Q3 service update for the news section."}'
```

Missing or mismatched tenant returns `401` or `403` before retrieval. A direct
publish brief returns `403 AGENT_POLICY_DENIED`. A simulated content-index failure
returns `503 TOOL_ERROR` without a draft.

## Optional live model

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
export PRAXO_API_KEY=
php artisan content:draft-article "Write a Q3 service update for the news section."
```

The live model receives the same tool schemas and policy. A hosted DeepSeek
`deepseek-flash` run on 2026-11-25 used a custom cURL transport for the local
proxy/CA and recorded `model=live`, the four-step tool trace, a model-written
rationale, and zero publications. Verify `report.model = "live"`, the
model-selected tools in `report.agent_trace`, and the persisted draft rationale.
This is one local hosted run; record provider, endpoint, model, cost, latency,
trace, and failures separately. It is not independent reproduction or a
production deployment.

## Boundaries

- No real CMS publication, content mutation, or external write.
- No durable draft store, queue, or exactly-once effect.
- No production authentication, tenant directory, or search service.
- In-memory content index and draft repository are teaching components.
- Drupal is the next PHP host; this Laravel studio is not a Drupal module.
- Local deterministic tests and one hosted live run are recorded; the live run
  used a custom cURL transport and is not independent adoption or production.

## Evidence

Local verification uses PHP 8.5.12 on Windows with required extensions enabled per
command and published `axisvela/praxo-core==0.8.1`. Composer and the local CA
bundle are environment workarounds. The application CI job installs the published
package on Ubuntu and runs the same PHPUnit suite; CI results are recorded only
after the job runs.
