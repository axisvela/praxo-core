# C# Sales / CRM Service Desk

A native C# Core tutorial for a review-only sales workflow. The Agent has two
fixed tools: `read_customer` reads synthetic customer `customer-100`, and
`draft_followup` produces a `draft_only` follow-up note for human review. It
never writes the CRM, sends email or changes an opportunity.

## Why this language and runtime?

- **Selection basis:** C#/.NET fits CRM integrations and service desks that already
  expose HTTP entry, identity and enterprise tooling.
- **Demonstrated fit:** A .NET HTTP/CLI host reads a fixed customer and drafts a
  follow-up note; no CRM write, email send or opportunity change runs.
- **Choose when:** Adding a governed review step to an existing .NET CRM service.
- **Do not choose when:** Seeking CRM automation or message delivery. Compare the CRM's
  native workflow/rules and authorization model first.
- **Evidence limit:** Synthetic customer and local HTTP tests; no production CRM,
  OIDC, email, write-back or sales outcome claim.

## Run

Requires .NET SDK 8. From this directory:

```bash
dotnet build
dotnet bin/Debug/net8.0/Praxo.SalesCrm.dll
```

The CLI prints JSON with `draft.status=draft_only`, `draft.action=review_required`,
a customer citation and an empty `crm_writes` list. It uses published NuGet
`Praxo.Core==0.10.0`, with no local Core replacement.

## HTTP Entry

```bash
dotnet bin/Debug/net8.0/Praxo.SalesCrm.dll --serve
```

The service binds to `http://127.0.0.1:8091`; use `DEMO_WEB_URL` for another
loopback URL. Health is `GET /healthz`; the fixed review route is
`POST /followup/customer-100`.

```bash
curl.exe -X POST http://127.0.0.1:8091/followup/customer-100 -H "Authorization: Bearer demo-sales-token"
```

Missing credentials return 401 before the Agent. A downstream failure returns
503. The fixture bearer token is not production authentication.

## Tests

```bash
dotnet bin/Debug/net8.0/Praxo.SalesCrm.dll --test
```

Self-tests cover draft-only success with zero CRM writes, `customer-200` policy
denial, simulated CRM dependency failure, and the Web health/401/200/503 boundary.

## Boundaries

- The customer fixture is synthetic and fixed; no CRM connector, real customer
  record, email send or opportunity write exists.
- The follow-up is a draft for human review, not a sent message, CRM mutation or
  sales recommendation.
- Identity, approvals, durable audit, retention and effect reconciliation remain
  application-owned.
- No live model, public hosting, production CRM integration or independent
  consumer evidence is claimed.
