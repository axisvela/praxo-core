# RHEOVELA Examples

This package shows two integration levels:

- `Runner` maps an `agent.Session` to a RHEOVELA workflow instance and advances
  it through stages.
- `DurableWorker` runs RHEOVELA work items through a `StepRunner` using the
  durable worker SDK. Results, checkpoint/effect references, and approval
  requests are persisted by RHEOVELA.

## Durable Worker

```go
runner := rheovela.AgentRunner{
    Agent: ag,
    Prompt: func(item worker.WorkItem) string {
        return "execute stage " + item.ActivityID
    },
}
w, err := rheovela.NewDurableWorker(
    rheovela.NewClient(os.Getenv("RHEO_URL")),
    runner,
    rheovela.WithLease(30*time.Second),
)
if err != nil {
    return err
}
return w.Run(ctx)
```

`AgentRunner` is a minimal example that runs one PRAXO agent invocation per work
item. A product runner can return `StepResult.Approval` to pause for human
approval, or set `CheckpointRef` and `EffectCursor` to connect its own recovery
state.

## Test

```bash
cd examples/ecosystem-sdk
GOWORK=off go test ./rheovela
```

## Live Test

Start a disposable RHEOVELA server, then run the durable worker against it:

```bash
cd Rheovela
./rheo serve --addr 127.0.0.1:18080 --db /tmp/praxo-rheo-live.db

cd ../praxo-core/examples/ecosystem-sdk
RHEO_URL=http://127.0.0.1:18080 GOWORK=off \
  go test -run TestLiveDurableWorker -v ./rheovela
```

The test publishes a one-stage workflow, opens a run, commits a result with
checkpoint/effect refs, then repeats with an approval request and resumes after
approval. Use a disposable database.

`TestLiveMultiWorkerLeaseFencing` additionally claims a work item with a short
lease, lets it expire, claims it with a successor, and verifies the stale
worker's commit is rejected.

## Multi-Node Validation

True multi-node validation needs a shared Postgres database and at least two
`rheo serve` processes. This environment has no Docker or Postgres, so the
committed tests cover a single local server plus lease/fencing takeover only.

A Postgres run should:

1. Start two nodes with `rheo serve --store postgres --db-url <dsn>` on
   different ports.
2. Point one PRAXO `DurableWorker` at each node URL.
3. Run `TestLiveDurableWorker` and `TestLiveMultiWorkerLeaseFencing` against
   both node URLs.
4. Claim on node A, expire the lease, claim on node B, and confirm A's stale
   commit is rejected.
5. Record whether scheduler duplication, leader election, replication, and
   failover are safe for the tested version.

RHEOVELA's current HA note says leader election, replication, and automatic
failover are deferred. Shared-Postgres fencing is not a production HA claim.

## TLS and Identity

The live tests accept optional TLS and header injection:

```bash
RHEO_URL=https://127.0.0.1:18443 \
RHEO_CA=/path/to/cert.pem \
RHEO_AUTH_HEADER=X-Auth-User \
RHEO_AUTH_VALUE=praxo-live \
GOWORK=off go test -run TestLiveDurableWorker -v ./rheovela
```

Start the server with `rheo serve --tls-cert <cert> --tls-key <key>`. The core
server does not enforce identity; `rheo-ee` with Keycloak/tenant middleware does.
This test proves client CA trust and header injection, not authorization
enforcement. Full identity validation requires the enterprise identity stack.
