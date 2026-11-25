# Ruby AI Commerce Copilot (AI-native reference application)

A Rails-hosted commerce back-office copilot where the agent drives the primary
workflow: a customer intent enters through `/assistant`, the agent searches the
application-owned catalog, quotes an in-stock cart, and saves a review-only order
draft. Payment and refund tools are always denied.

This is the AI-native Ruby reference application. The existing
[`Tutorial/retail-replenishment`](../Tutorial/retail-replenishment/) tutorial
remains the basic deterministic replenishment slice.

## Why this language and runtime?

- **Selection basis:** Rails is common for e-commerce and SaaS back-offices that
  already own tenant identity, catalog data, order drafts, and web controllers.
- **Demonstrated fit:** A Rails 8 controller boots in-process, a tenant-scoped
  request enters a native Ruby `praxo-run` loop, and application-owned catalog
  and draft services stay under the host boundary.
- **Choose when:** Adding a governed commerce assistant next to an existing Rails
  application and its order workflow.
- **Do not choose when:** Direct Rails CRUD or a fixed checkout rule already
  solves the task, or when payment effects cannot be approval-gated.
- **Evidence limit:** Fixture catalog and in-memory draft store. The Rails runtime
  is a minimal host, not a full generated Rails application, and the app does not
  implement production checkout, payment, refund, inventory reservation, or
  durable order storage.

## AI-native workflow

1. `POST /assistant` with `X-Tenant: acme` and a customer intent.
2. The agent calls `search_catalog` to inspect the app-owned catalog.
3. The agent calls `quote_cart` for an in-stock cart.
4. The agent calls `draft_order` with `review_only=true`, a diagnosis, and a
   rationale; the app saves a `draft_only` order.
5. The response reports `payment_charges=0`, `refunds=0`, and
   `mutating_actions=[]`. `charge_payment` and `refund_order` are policy-denied.

If the model is removed, the primary commerce workflow disappears.

## Where is the LLM reasoning?

The deterministic tests use a scripted model. They verify the Rails boundary,
tenant handling, tool policy, draft persistence, and failure paths, not LLM
reasoning.

A live path is implemented with `Praxo::Adapters::OpenAICompatible`. A hosted
DeepSeek `deepseek-flash` run on 2026-11-25 recorded `model=live`; the model chose
repeated `search_catalog` reads, then `quote_cart` and `draft_order`. The app kept
the computed quote and draft authoritative, returned `payment_charges=0`,
`refunds=0`, and `mutating_actions=[]`, and ignored no policy boundary.

On Windows the application transport uses `curl.exe --ssl-no-revoke` with the
local proxy; this is transport plumbing, not model evidence.

## Host integration

| Boundary | Where |
| --- | --- |
| Rails controller and routes | `app/controllers/commerce_controller.rb`, `config/routes.rb` |
| Agent service | `lib/commerce_agent.rb` |
| Catalog, quote, and draft store | `lib/commerce_store.rb` |
| Agent loop | `language/ruby/lib/praxo` (`praxo-run` equivalent) |
| Policy | `AgentService#policy` |
| Trace | `RecordingSink` |
| Tests | `run-tests.rb` |
| Live runner | `run-live.rb` |

Tenant identity, durable orders, inventory reservation, payment, refund, and
effect reconciliation remain application-owned.

## Tools and policy

| Tool | Effect | Policy |
| --- | --- | --- |
| `search_catalog` | Read-only catalog search | Tenant `acme` |
| `quote_cart` | Computes totals and stock status; no reservation | Tenant `acme` |
| `draft_order` | Saves a review-only draft | `review_only=true`, items, diagnosis, rationale |
| `charge_payment` | Would charge a card | Always denied |
| `refund_order` | Would refund an order | Always denied |

A missing or different tenant is rejected before the agent. A direct charge or
refund is denied with zero effects. A weak draft without diagnosis/rationale is
denied without persistence.

## Run and test

Install the minimal Rails host components and run the in-process tests:

```bash
gem install railties actionpack rack tzinfo-data --no-document
ruby language/ruby/application/run-tests.rb
```

Expected:

```text
Ruby AI commerce copilot: all checks passed
```

Start a server with a Rack server if one is installed:

```bash
rackup language/ruby/application/config.ru
```

For a live model:

```bash
export PRAXO_BASE_URL=https://api.deepseek.com
export PRAXO_MODEL=deepseek-flash
export PRAXO_API_KEY=...
ruby language/ruby/application/run-live.rb
```

## Boundaries

- Fixture catalog and in-memory draft store; no production database, Active
  Record model, Active Job worker, inventory reservation, or durable audit store.
- No real payment, refund, tax service, checkout, fulfillment, or account change.
- Tenant checking is a header-based local boundary, not production authentication.
- The Rails host is a minimal boot for the reference slice; it is not a full
  generated Rails application or production deployment.
- Local source runtime; not a registry-package install.
