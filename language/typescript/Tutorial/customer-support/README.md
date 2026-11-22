# TypeScript Customer Support Streaming

A native TypeScript Core tutorial for a customer-support reply streamed over SSE.
The Agent has two fixed tools: `lookup_order` reads `order-100`, and
`search_policy` reads a fixed public shipping policy. The deterministic model
returns an answer with a document citation; it does not send a reply, change an
order or issue a refund.

## Run

From this directory:

```bash
npm ci
npm start
```

The server binds to `127.0.0.1:8088`. From another terminal:

```bash
curl.exe -N -X POST http://127.0.0.1:8088/support/order-100 -H "Authorization: Bearer demo-a-token"
```

The response is an SSE stream of `data: {"delta":"..."}` events followed by
`data: {"citations":["shipping"],"done":true}`. The final text says the order is
delayed and cites `shipping`.

## Failure Checks

```bash
npm test
```

The test covers:

- authenticated streaming success with a citation;
- missing credentials returning 401 before the Agent;
- simulated support dependency failure returning 503 before a stream starts;
- an out-of-scope order denied by Agent policy before HTTP/tool effects.

## Boundaries

- Only the fixed `order-100` route and fixed policy fixture are readable; no
  model-selected URL, file path, SQL query or connector is used.
- The stream is a rendering path for the final response; deltas are not durable
  events and the final cited result remains authoritative.
- No reply is sent to the customer, no order is changed and no refund is issued.
- Public fixture credentials are not production authentication; identity,
  approval, effect reconciliation, retention and audit remain application-owned.
- There is no live provider verification, public hosted endpoint or independent
  consumer evidence. The SSE demo is loopback-only.
