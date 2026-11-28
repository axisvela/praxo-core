# PRAXO-CORE Go Core

Go is the reference implementation of PRAXO-CORE: an embeddable, MIT-licensed
agent execution kernel with explicit policy controls, checkpoints, events, and
tool calling. It runs in-process and does not require a hosted service.

- `SPEC_VERSION`: `0.2.0`
- Source module: `github.com/axisvela/praxo-core/v2@v2.11.3`
- Tier: Core (reference)
- License: MIT
- Go: module declares `1.25.0`; CI and releases use Go `1.26.11`

## Install

```bash
go get github.com/axisvela/praxo-core/v2@v2.11.3
```

## Quickstart

```go
agentInstance, err := agent.New(agent.Options{
    Model: model,
    Tools: tools,
    MaxSteps: 4,
    AllowedTools: []string{"get_time"},
    Policy: policy.FuncHook(authorize),
})
if err != nil {
    return err
}
result, err := agentInstance.Run(ctx, agent.Session{ID: "demo"}, "What time is it?")
```

See [`language/go/examples/quickstart`](../../language/go/examples/quickstart) for a runnable
OpenAI-compatible endpoint with a `get_time(zone)` tool, and
[`language/go/examples/live-model`](language/go/examples/live-model) for the published-package live path.

## Features

- Governed agent loop with policy hooks, final-argument authorization, and HITL.
- Tools, registry, gateways, retries, and parameter schemas.
- Memory, context budgets, middleware, checkpoints, events, and streaming.
- Provider-neutral model adapters and optional MCP, OTel, and workspace seams.
- Shared `spec/` vectors and API snapshots for cross-language conformance.

## Examples

- [`language/go/examples/quickstart`](../../language/go/examples/quickstart): endpoint quickstart.
- [`language/go/examples/live-model`](language/go/examples/live-model): live model with `get_time(zone)`.
- [`language/go/examples/consumer-go`](language/go/examples/consumer-go): published-package allow/deny starter.
- [`language/go/examples/hitl`](../../language/go/examples/hitl): approval and edit reauthorization.
- [`language/go/examples/session-checkpoint`](../../language/go/examples/session-checkpoint): multi-turn checkpoint recovery.
- [`language/go/examples/governed-workspace`](../../language/go/examples/governed-workspace): policy and approval boundaries.
- [`language/go/examples/multiagent`](../../language/go/examples/multiagent): local delegation.
- [`language/go/examples/plugin`](../../language/go/examples/plugin): process plugin host.

## Verify

From the repository root:

```bash
GOWORK=off go test ./...
GOWORK=off go vet ./...
GOWORK=off go build ./...
```

## Documentation

- [Go Core documentation](https://axisvela.github.io/praxo-core/languages/go/)
- [API reference](https://pkg.go.dev/github.com/axisvela/praxo-core/v2)
- [Specification](../../spec/README.md)
- [Public roadmap](../../ROADMAP.md)


## Tutorials and Reference Applications

Language-specific scenario tutorials and reference applications for Go.

### Scenario Tutorials

| Tutorial | What it shows |
| --- | --- |
| [customs-reroute](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/customs-reroute) | A scoped customs tutorial over the Go reference Core. It validates fixed document fields for one shipment, compares two routes and drafts a review-only reroute. The source and m... |
| [emergency-route-plan](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/emergency-route-plan) | A scoped emergency-planning tutorial over the Go reference Core. It reads fixed road closures for one event through an application-owned `RoadSource`, drafts a review-only relie... |
| [evidence-vault](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/evidence-vault) | A scoped security-operations tutorial over the Go reference Core. It reads one allowlisted evidence file from a local `vfs/localfs` backend confined to a vault root, then drafts... |
| [fullstack-workspace](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/fullstack-workspace) | A scoped full-stack-planning tutorial over the Go reference Core. It reads a fixed allowlisted workspace, applies one bounded edit to `app.go` and inspects synthetic diagnostics... |
| [incident-coordination](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/incident-coordination) | A scoped operations tutorial over the Go reference Core. It reads one fixed `incident-100` snapshot through an application-owned `IncidentSource` interface, drafts an operator u... |
| [litigation-timeline](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/litigation-timeline) | A scoped litigation-support tutorial over the Go reference Core. It builds a cited timeline from fixed synthetic documents, flags one contradiction and drafts a review-only evid... |
| [logistics-checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/logistics-checkpoint) | A scoped logistics tutorial over the Go reference Core that shows a two-run workflow across a checkpoint. The first run assesses a fixed `shipment-100` and saves a `checkpoint.C... |
| [pentest-lab-review](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/pentest-lab-review) | A scoped penetration-testing tutorial over the Go reference Core. It inventories one fixed allowlisted loopback lab host through an application-owned `LabSource`, reports two se... |
| [soc-alert-triage](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/soc-alert-triage) | A scoped security-operations tutorial over the Go reference Core. It reads one fixed `alert-100` snapshot through an application-owned `AlertSource`, redacts personal data with... |
| [zero-trust-review](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/zero-trust-review) | A bounded first slice of [CY-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), not a live policy engine. It reads fixed access events for one tenant,... |

Index: [language/go/Tutorial](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial).

### Reference Applications

No accepted end-to-end reference application is recorded for this language yet. Candidate goals are tracked in the [Reference Application Portfolio](https://axisvela.github.io/praxo-core/project/planning/roadmap/#reference-application-portfolio).

Planning context: [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/), [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/), and [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/). Chinese: [教程计划](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/), [候选场景](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/), [教程目录](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/).

## Community

- X: <https://x.com/axisvela>
- Weibo: <https://weibo.com/u/1936025761>
- LinkedIn: <https://www.linkedin.com/company/axisvela/>
- Facebook: <https://www.facebook.com/profile.php?id=61596905732406>
- YouTube: <https://www.youtube.com/@axisvela>
- Discord: <https://discord.com/channels/1575163993767809064/1575164343148875977>
- GitHub Discussions: <https://github.com/axisvela/praxo-core/discussions>
- GitHub Issues: <https://github.com/axisvela/praxo-core/issues>
- Documentation: <https://axisvela.github.io/praxo-core/>
- Architect: <https://axisvela.architect.pub>

