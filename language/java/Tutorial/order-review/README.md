# Java Order Review Web Agent

This tutorial embeds the native Java Core in a loopback HTTP application. It
uses the same synthetic business service as Python and TypeScript, not a shared
remote Agent. The initial model is deterministic: it requests `review_order`,
then returns the tool result. The application computes the recommendation from
order status. It does not use an LLM to decide a refund or perform business writes.

## Start the Business Service

From `axisvela/demo-repository` in a separate terminal:

That repository is currently private; an authorized checkout is required. No
public hosted backend is available. Java's default CI tests use their own local
contract fixture and do not require access to the business service repository.
The full cross-repository gate is manual: dispatch `ci-tutorials` with
`run_shared_service=true` and an explicitly configured, read-only
`DEMO_REPOSITORY_TOKEN`. Public pull requests never receive that credential.

```bash
python shared-business-services/service/orders.py
```

This serves synthetic order data at `http://127.0.0.1:8765`. Requests are checked
against public fixture tokens by that service, independently of Agent policy.

## Install and Run

Requires JDK 21+ and Maven. From this tutorial directory:

```bash
mvn -q test
mvn -q compile exec:java
```

The CLI prints JSON containing an order and a `draft_only` resolution. It uses
Maven Central `com.axisvela:praxo-core:0.11.0`. `DEMO_BASE_URL` selects the business
service, `DEMO_TOKEN` selects the fixture credential, and `DEMO_ORDER` selects
the requested order (Agent policy permits only `order-100`).

On Windows agent shells redirect Java/Maven stdin from NUL and bound execution
time. This workstation's Java launcher has previously hung; no runtime success
is claimed locally. Linux CI passed `mvn -B -q test` at Core `3c2063f9` in
[run 45031868787](https://github.com/axisvela/praxo-core/actions/runs/45031868787).
That verifies compilation and mock-backed Agent/Web tests, not the private
business service or a live model. The full integration job was skipped.

## Web Entry

```bash
mvn -q compile exec:java -Dexec.args=--serve
```

The server binds only to `127.0.0.1:8086`. In a second terminal:

```bash
curl -X POST http://127.0.0.1:8086/review/order-100 -H "Authorization: Bearer demo-a-token"
```

This fixed route accepts no model-selected target URL or arbitrary order ID.
Missing credentials return 401 before the Agent runs. Backend errors return 503,
not a fabricated successful result. The credential is deliberately public and
is not OIDC or production authentication.

## Failure and Repeat Behavior

- `DEMO_ORDER=order-200` is denied by Agent policy before business HTTP calls.
- `DEMO_TOKEN=demo-b-token` denies `order-100` at the backend, independently.
- Stop the backend: CLI fails; the Web endpoint returns 503.
- Repeating a review uses `java-review-1` as the fixture idempotency key. The
  business service replays an identical draft rather than creating a second one.
- An existing key with a different recommendation conflicts. A real application
  must supply its own request identity, reconciliation, and concurrency policy.

## Scope

JUnit covers the Java Agent and Web boundary against a local contract fixture.
The shared service tests cover its real tenant checks, idempotency and dependency
failure. These are different scopes; the mock does not verify the real service.
There is no live-model mode, public hosting, durable state, real order mutation,
refund, production authentication or independent consumer evidence in this slice.
