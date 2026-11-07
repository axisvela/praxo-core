# Context Budget and Compaction Recipe (Go)

This recipe demonstrates the deterministic context budget and the optional
summary compactor. It uses `pkg/agent/context` with no model service; the
summary model is a deterministic fixture.

**Evidence level: L1 contract/application recipe.** It shows prompt fitting and
mandatory-system preservation. It does not prove a general prompt-injection
filter, source authenticity, or production context storage. See
[EC-06](../../../docs/project/execution-correctness.md) and the
[test and evidence taxonomy](../../../docs/project/test-taxonomy.md).

Run from this directory:

```sh
GOWORK=off go test -mod=readonly -run 'Budget|Summarizer' -v ./...
```

The tests show:

- prompts under budget are unchanged;
- over-budget prompts keep the first System message and the most recent
  non-system messages, with an explicit compaction marker;
- an oversized System prompt fails instead of being silently dropped;
- `ModelSummarizer` replaces older context with a summary;
- a summary-model failure falls back to deterministic compaction rather than
  aborting the run.

From the repository root, `python scripts/test_go_context_budget_recipe.py -v`
repeats the checks in a fresh temporary module using the published package.
