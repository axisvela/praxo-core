# C# Order Service Desk

Embed the native C# Core in an ASP.NET Core minimal API. The Agent invokes a
scoped order-review tool over the public synthetic business service. The same
application also offers CLI mode for cross-language integration tests.

The first slice uses a deterministic model. Business rules select a carrier
follow-up or monitoring recommendation, and the backend stores a `draft_only`
record. The Agent never changes an order or issues a refund. This is a service
desk prototype, not a complete ERP or HR application.

## Start the Shared Backend

Requires Python 3.12+ in a separate terminal:

```bash
git clone https://github.com/axisvela/agent-tutorial-services.git
cd agent-tutorial-services
python service/orders.py
```

## Build and Run

Requires .NET SDK 8. From this tutorial directory:

```bash
dotnet build
dotnet bin/Debug/net8.0/Praxo.OrderReview.dll
```

The project installs NuGet `Praxo.Core==0.10.0`, with no Core source replacement.
The CLI prints an object containing `order` and `draft`; the draft status is
`draft_only`. `DEMO_BASE_URL` selects a loopback HTTP business origin,
`DEMO_TOKEN` selects the fixture credential and `DEMO_ORDER` the requested order.
Agent policy permits only `order-100`. Local business HTTP bypasses proxies and
rejects redirects; requests have a five-second timeout and bounded response buffer.

## ASP.NET Core Entry

```bash
dotnet bin/Debug/net8.0/Praxo.OrderReview.dll --serve
```

The service binds to `http://127.0.0.1:8087`; use `DEMO_WEB_URL` for another
loopback port. Health is `GET /healthz`. From another terminal:

```bash
curl -X POST http://127.0.0.1:8087/review/order-100 -H "Authorization: Bearer demo-a-token"
```

Use `curl.exe` on Windows PowerShell. Missing credentials return 401 before the
Agent runs. There is no route for arbitrary orders or user-supplied target URLs.
Business-service failures return 503 without inventing a successful response.

The public fixture bearer token is not production authentication. Caller
authentication at the Web entry, Agent policy, and backend tenant checks are
separate boundaries. Reuse the authenticated service examples for production
identity integration; this tutorial does not operate an identity provider.

## Failure and Repeat Checks

- Set `DEMO_ORDER=order-200` in CLI mode: Agent policy denies before HTTP calls.
- Set `DEMO_TOKEN=demo-b-token`: the backend independently denies `order-100`.
- Stop the backend: the CLI fails and the Web entry returns 503.
- Repeating a review uses fixture idempotency key `csharp-review-1`; an unchanged
  recommendation replays the same draft. A changed recommendation conflicts.
- Drafts are in-memory records, not refunds, durable operations or exactly-once
  effects. Production request identities and reconciliation remain application-owned.

## Tests and Limits

```bash
dotnet bin/Debug/net8.0/Praxo.OrderReview.dll --test
```

Self-tests use a scripted business transport and a real ephemeral ASP.NET Core
listener. They verify JSON results, pre-HTTP Agent denial, Web authentication,
fixed route scope and dependency failure. Public backend `tests/test_clients.py`
can additionally exercise this CLI and Web entry against the real local order
service when `PRAXO_DOTNET_DLL` points to the compiled DLL.

On 2026-11-22, Core `ae953050` passed
[CI run 45034303513](https://github.com/axisvela/praxo-core/actions/runs/45034303513):
C# self-tests plus all five real-service unittest methods, using public backend
`cd08b09`. Four native CLI clients and the C# ASP.NET Core Web entry ran against
the real ephemeral service. Tests used deterministic models, not live providers.

No live model, production identity, durable approvals, cancellation propagation,
public hosting or independent adoption is established by this deterministic slice.
