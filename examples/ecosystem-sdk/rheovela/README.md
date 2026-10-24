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

## Deployment Boundary

Postgres multi-node deployment, leader election, replication/failover, and
enterprise identity enforcement belong to RHEOVELA/RHEOVELA-ee. They are not
PRAXO-CORE validation targets.

PRAXO's live tests cover only the client side:

- durable worker result/checkpoint/effect persistence
- approval request and resume
- lease expiry and successor fencing
- concurrent scheduler deduplication (RHEOVELA core test)
- TLS CA trust and optional identity-header injection

## TLS and Header Wiring

The live tests accept optional TLS and header injection:

```bash
RHEO_URL=https://127.0.0.1:18443 \
RHEO_CA=/path/to/cert.pem \
RHEO_AUTH_HEADER=X-Auth-User \
RHEO_AUTH_VALUE=praxo-live \
GOWORK=off go test -run TestLiveDurableWorker -v ./rheovela
```

Start the server with `rheo serve --tls-cert <cert> --tls-key <key>`. This
proves client CA trust and header transport, not enterprise authorization or a
deployed identity stack.
