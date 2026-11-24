# Elixir Knowledge Maintenance (OP-03)

A bounded first slice of [OP-03](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an autonomous Wiki service. It diffs two fixed knowledge versions, reports
changed sections and removed duplicates, and drafts a review-only revision. This
uses the source Elixir Core; no network, credentials or packages beyond Elixir/OTP
are required.

## Why this language and runtime?

- **Selection basis:** An existing Elixir/OTP knowledge service could keep a review
  workflow in its own supervised application. No such consumer is verified here.
- **Demonstrated fit:** An Elixir script runs Core callbacks over fixed knowledge
  versions and drafts a revision. Differencing and changed counts are fixture data.
- **Choose when:** Learning the Core seam for an already maintained Elixir service.
- **Do not choose when:** Expecting Wiki integration, real document diffing or OTP
  supervision behavior. Compare direct diff libraries and existing service rules.
- **Evidence limit:** Core integration fixture only; no wiki API, durable state,
  concurrency test, supervision restart or comparative BEAM advantage.

Compile the Core once, then run from the repository root:

```bash
mkdir -p language/elixir/build/ebin
elixirc -o language/elixir/build/ebin language/elixir/lib/praxo/*.ex language/elixir/lib/praxo/adapters/*.ex
elixir -pa language/elixir/build/ebin language/elixir/Tutorial/knowledge-maintenance/app.exs --test
elixir -pa language/elixir/build/ebin language/elixir/Tutorial/knowledge-maintenance/app.exs
elixir -pa language/elixir/build/ebin language/elixir/Tutorial/knowledge-maintenance/app.exs --workspace workspace-200
elixir -pa language/elixir/build/ebin language/elixir/Tutorial/knowledge-maintenance/app.exs --simulate-failure
```

Expected test output:

```text
success: workspace-100 changed=2 status=draft_only wiki_writes=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: KNOWLEDGE_INDEX_UNAVAILABLE reads=1
```

Both negative commands exit nonzero.

The deterministic model plans three steps and consumes each result: `diff_knowledge`
returns changed sections `retention` and `contact`, one removed duplicate and a
fixture source; `draft_revision` returns `status=draft_only`,
`review_required=true` and `wiki_writes=0`. Policy receives tool name and
arguments, limiting the workspace and final `propose_revision` action;
`require_policy` and `require_tool_scope` are enabled.

Tests assert one diff and one draft on success, zero reads/drafts for a
cross-workspace denial, and one read/zero drafts for the simulated index outage.
The tool returns an error object for that outage; the model reports
`KNOWLEDGE_INDEX_UNAVAILABLE` and no draft executes.

Real document stores, deduplication quality, citations, Wiki writes, approvals and
effect reconciliation belong to the consumer. No live provider, publication,
independent consumer or production knowledge service is claimed.
