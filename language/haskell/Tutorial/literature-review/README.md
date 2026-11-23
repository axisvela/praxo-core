# Haskell Literature Review (SC-01)

A bounded first slice of [SC-01](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not autonomous scientific discovery. It searches a fixed synthetic paper corpus,
cites the top result, and drafts an explicitly unverified hypothesis. This uses
the source Haskell Core through `runghc`; no network, credentials or packages are
required beyond GHC.

Run from the repository root:

```bash
runghc -ilanguage/haskell/src language/haskell/Tutorial/literature-review/app.hs --test
runghc -ilanguage/haskell/src language/haskell/Tutorial/literature-review/app.hs
runghc -ilanguage/haskell/src language/haskell/Tutorial/literature-review/app.hs --scope private
runghc -ilanguage/haskell/src language/haskell/Tutorial/literature-review/app.hs --simulate-failure
```

Expected test output:

```text
success: paper-1 stage=hypotheses_drafted status=draft_only publications=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: LITERATURE_INDEX_UNAVAILABLE reads=1
```

Both negative commands exit nonzero.

The deterministic model plans three steps and consumes each result: `search_literature`
returns two fixed papers for the public scope; `draft_hypotheses` returns
`status=draft_only`, `review_required=true`, `unverified=true` and `publications=0`.
Policy receives tool arguments and limits both scope and the final paper/action;
`requirePolicy` and `requireToolScope` are enabled. The final report labels the
hypothesis unverified rather than asserting a discovery.

Tests assert one search and one draft on success, zero searches/drafts for a
private-scope denial, and one search/zero drafts for the simulated index outage.
A failing tool returns its Core error and no later draft executes.

Real literature APIs, citation validation, evidence grading, retraction checks and
scientific review belong to the consumer. No live provider, publication, claim of
scientific validity or independent adoption is made.
