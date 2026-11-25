# Content Review Precursor (PHP host-integration precursor)

A Laravel 12 content portal that routes one existing draft article through a
governed PRAXO-CORE agent. The agent reads the article through an
application-owned content store, drafts a review-only publication step, and
returns a JSON report with `publications_executed=0`.

This is a host-integration precursor, not the AI-native reference application.
The AI-native sibling at [`../ai-editorial-studio`](../ai-editorial-studio)
generates the primary editorial artifact from a brief.

The application demonstrates the host integration, not another generic agent
loop: Laravel routing, middleware, container bindings, configuration, an Artisan
command, and the published PHP Core package.

**Design status:** this is a host-integration precursor. The AI-native editorial
studio is implemented separately at
[`../ai-editorial-studio`](../ai-editorial-studio). This review-only app must not
be described as the AI-native reference application.

## Why this language and runtime?

- **Selection basis:** PHP is a common host for content management systems,
  editorial portals, and back-office applications. The AI-native target is an
  editorial studio that generates a draft from a brief, not only a review endpoint.
  This precursor uses Laravel's routing, middleware, dependency injection, and
  console commands; Drupal is the next PHP host to validate against a CMS-native
  editorial workflow.
- **Demonstrated fit:** A Laravel API route authenticates a tenant header, passes
  the request to a container-built agent, and returns a draft publication review.
  The same agent is available as an Artisan command. Core tool policy denies
  `article-200` before the content store is read.
- **Choose when:** Adding a governed editorial review step to an existing PHP
  portal or CMS application that already owns its users, content, and workflow.
- **Do not choose when:** A simpler editorial workflow, an external moderation
  worker, or an existing CMS approval chain can satisfy the task. This example is
  not a reason to move unrelated content operations into an agent.
- **Evidence limit:** This is a Laravel content-portal host integration with a
  deterministic model and an in-memory fixture article store. It is not Drupal
  yet, not a production CMS, not a live provider check, and not an independent
  consumer.

## What the host integration covers

| Host boundary | Where |
| --- | --- |
| API route and middleware | `routes/api.php`, `app/Http/Middleware/RequireTenant.php` |
| Container wiring | `app/Providers/AppServiceProvider.php` |
| Application configuration | `config/content.php`, `.env.example` |
| Application-owned content data | `app/Contracts/ArticleStore.php`, `app/Services/FixtureArticleStore.php` |
| Governed Core agent | `app/Services/EditorialAgent.php`, `EditorialPolicy.php` |
| Tool schemas and adapters | `app/Services/SchemaTool.php`, `DeterministicEditorialModel.php` |
| CLI host entry | `routes/console.php` |
| Negative paths | `tests/Feature/ArticleReviewTest.php` |

Identity, content persistence, editorial approval, and effect reconciliation
remain application responsibilities. The tenant header is a teaching stand-in for
a verified principal, not an authentication system.

## Requirements

- PHP 8.2 or newer with `openssl`, `mbstring`, `curl`, `fileinfo`, and `intl`.
- Composer 2.
- No database, model endpoint, or credentials are required for the tests.

## Install

The application uses the published Packagist package
`axisvela/praxo-core:0.8.1`, not a source checkout.

```bash
cd language/php/application/content-review
composer install --no-interaction --prefer-dist
```

Run the deterministic tests:

```bash
vendor/bin/phpunit
```

Expected: seven tests pass, covering route success, missing tenant, tenant
mismatch, policy denial before read, dependency failure, and the Artisan command.

## Deterministic run

```bash
php artisan content:review-article article-100
```

Expected JSON includes:

- `report.article.section = "news"`
- `report.review.status = "draft_only"`
- `report.review.review_required = true`
- `report.publications_executed = 0`
- `agent.reads = 1`
- `agent.drafts = 1`

Out-of-scope article:

```bash
php artisan content:review-article article-200
```

Expected: exit code 1 with `AGENT_POLICY_DENIED`, `agent.reads = 0`.

Simulated dependency failure:

```bash
php artisan content:review-article article-100 --simulate-failure
```

Expected: exit code 1 with `TOOL_ERROR`, `agent.reads = 1`, `agent.drafts = 0`.

## HTTP run

```bash
php artisan serve
curl -s -X POST http://127.0.0.1:8000/api/articles/article-100/review \
  -H 'X-Tenant-Id: acme'
```

Missing tenant returns `401 TENANT_REQUIRED`; a different tenant returns
`403 TENANT_DENIED`; both are rejected before the content store is read.
`article-200` returns `403 AGENT_POLICY_DENIED`. A simulated store failure returns
`503 TOOL_ERROR` with no draft.

## Optional live model

Set an OpenAI-compatible endpoint to replace the deterministic model:

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
export PRAXO_API_KEY=
php artisan content:review-article article-100
```

The model receives the same tool schemas and still passes through the same policy.
The live path has not been run against a hosted endpoint in this environment, and
its output still needs the report validation. Record provider, model, endpoint,
cost, and failures separately from the deterministic result.

## Boundaries

- No real publish, CMS update, content mutation, or external system write.
- No database, queue, durable checkpoint, or exactly-once effect semantics.
- No production authentication, authorization service, or tenant directory.
- The fixture store and deterministic model are teaching components.
- Local evidence is deterministic host/CI integration, not independent adoption.
- Drupal is the next PHP host to implement; this Laravel portal is not a Drupal
  module or a substitute for CMS-native verification.

## Evidence

Local verification uses PHP 8.5.12 on Windows with the required extensions enabled
per command and the published `axisvela/praxo-core==0.8.1` package. Composer and
the local CA bundle are environment workarounds, not application requirements.
The application CI job installs the published package on Ubuntu and runs the same
PHPUnit suite. CI results are recorded only after the job runs; a local pass is not
a CI pass.
