# AI Commerce Assistant (Java AI-native reference application)

A Spring Boot commerce application where the agent drives the primary shopping
workflow: a customer states an intent, the agent searches the application-owned
catalog, checks inventory, drafts a cart, and creates a review-only checkout
request. The agent never charges, places an order, or ships.

This is the AI-native Java reference application. There is no traditional
application precursor for Java.

## Why this language and runtime?

- **Selection basis:** E-commerce and enterprise web services are typical Java
  scenarios. Spring Boot provides the service container, HTTP entry point,
  configuration, validation, and test harness used by existing Java applications.
- **Demonstrated fit:** The application uses Spring MVC, a tenant filter, service
  beans, an application-owned catalog and draft store, Core tool policy, and a
  deterministic model over the published Java Core package.
- **Choose when:** Adding an AI shopping assistant to an existing Spring Boot
  commerce service where inventory, pricing, and checkout remain application-owned.
- **Do not choose when:** A simpler search/ranking workflow, an existing
  recommendation engine, or an external checkout service solves the task with less
  integration and operational cost.
- **Evidence limit:** Deterministic model, fixture catalog, and in-memory drafts.
  This is not a live storefront, payment system, production identity provider,
  live-model check, or independent consumer.

## AI-native workflow

1. `POST /api/commerce/checkout-drafts` with `{"intent": "..."}` and a verified tenant.
2. The agent searches the catalog and reads inventory/pricing.
3. The model drafts a cart with `draft_only` status.
4. The model requests a review-only checkout step.
5. The application returns a JSON package with `checkouts_executed=0`.
6. A human or host workflow approves payment and order placement outside the agent.

If the model is removed, the primary shopping workflow disappears.

## Where is the LLM reasoning?

The deterministic tests use a scripted model. They verify the harness, tool
policy, failure paths, and trace shape, not LLM reasoning.

In the live path, the model chooses the catalog/inventory/cart tools and arguments
and writes the cart `rationale`. `CommerceAgent` records `agent_trace` with the
model's tool calls and output and sets `model` to `"live"`. The live path has not
been run because the local JVM is blocked; do not claim live Java reasoning until
CI or another JVM records a run.

## Host integration

| Boundary | Where |
| --- | --- |
| Spring Boot entry | `CommerceApplication.java` |
| HTTP route and validation | `CheckoutDraftController.java`, `CheckoutDraftRequest.java` |
| Tenant verification | `TenantFilter.java` |
| Configuration | `CommerceSettings.java`, `application.yml` |
| Catalog and inventory | `CatalogService.java` |
| Cart and review state | `DraftService.java` |
| Governed agent | `CommerceAgent.java`, `CommercePolicy.java` |
| Deterministic model | `DeterministicCommerceModel.java` |
| Tests | `CommerceApplicationTests.java`, `CatalogFailureTest.java` |

Identity, catalog persistence, payment, order placement, and effect reconciliation
remain application responsibilities. The tenant header is a teaching stand-in for
a verified principal.

## Tools and policy

| Tool | Effect | Policy |
| --- | --- | --- |
| `search_catalog` | Read-only catalog search | Intent required |
| `check_inventory` | Read-only inventory and price | SKU required |
| `draft_cart` | Saves a review-only cart | SKU, quantity, intent required |
| `request_checkout_review` | Creates a review-only checkout request | Only `checkout_review` |
| `checkout` | Would charge and place an order | Always denied in the agent path |

A `Checkout now`, `Buy now`, or `Pay now` intent is denied before catalog
retrieval, cart creation, or checkout.

## Requirements

- JDK 21 or newer.
- Maven 3.9 or newer.
- Network access for the first Maven dependency resolution.
- No database, model endpoint, or credentials are required for the deterministic
  tests.

## Build and test

Uses the published `com.axisvela:praxo-core:0.12.3` package and Spring Boot 4.1.0.

```bash
cd language/java/application
mvn -B -ntp -DskipTests package
mvn -B -ntp test
```

Expected: the application builds and seven tests pass (six main tests plus the
catalog-failure test), covering the draft package, tenant boundaries, direct
checkout denial, validation, catalog failure, and invalid model output.

## Run

```bash
mvn -B -ntp spring-boot:run
```

Deterministic request:

```bash
curl -s -X POST http://127.0.0.1:8080/api/commerce/checkout-drafts \
  -H 'Content-Type: application/json' \
  -H 'X-Tenant-Id: acme' \
  -d '{"intent":"Find a trail running shoe for a weekend hike."}'
```

Expected JSON includes:

- `report.cart.status = "draft_only"`
- `report.cart.rationale` from the model
- `report.review.status = "review_requested"`
- `report.checkouts_executed = 0`
- `report.model = "deterministic"` for the fixture run
- `report.agent_trace` with tool calls and model output
- `agent.reads = 2`, `agent.drafts = 1`, `agent.reviews = 1`,
  `agent.checkouts = 0`

Direct checkout:

```bash
curl -s -X POST http://127.0.0.1:8080/api/commerce/checkout-drafts \
  -H 'Content-Type: application/json' \
  -H 'X-Tenant-Id: acme' \
  -d '{"intent":"Checkout now for the trail running shoe."}'
```

Expected: `403 AGENT_POLICY_DENIED` with zero effects.

Catalog failure:

```bash
COMMERCE_CATALOG_FAILURE=true mvn -B -ntp spring-boot:run
```

Expected: `503 TOOL_ERROR` after one read and no draft.

## Optional live model

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
export PRAXO_API_KEY=
mvn -B -ntp spring-boot:run
```

The live model receives the same tool schemas and policy. Verify `report.model =
"live"`, the model-selected tools in `report.agent_trace`, and a model-written
cart rationale. The live path has not been run here because the local JVM is
blocked. Record provider, endpoint, model, cost, latency, trace, and failures
separately.

## Boundaries

- No payment, charge, order placement, inventory write, or shipment.
- No durable cart store, queue, or exactly-once effect.
- No production authentication, tenant directory, or catalog service.
- Fixture catalog and in-memory drafts are teaching components.
- Local Windows JVM execution is blocked on the development workstation; Linux CI
  is the intended verification path. Do not treat the source as locally compiled
  or tested until that job passes.
- No live-model reasoning evidence is recorded for Java. The deterministic
  `agent_trace` proves trace plumbing, not model reasoning.
