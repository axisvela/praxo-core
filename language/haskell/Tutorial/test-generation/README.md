# Haskell test generation (SE-04)

A bounded first slice of SE-04, not a test-execution or load-testing service. It
generates three bounded tests for a fixed local fixture and records zero
executions. No load target, network traffic or runtime verification.

Run from the repository root:

```bash
runghc -ilanguage/haskell/src language/haskell/Tutorial/test-generation/app.hs --test
runghc -ilanguage/haskell/src language/haskell/Tutorial/test-generation/app.hs
runghc -ilanguage/haskell/src language/haskell/Tutorial/test-generation/app.hs --fixture fixture-200
runghc -ilanguage/haskell/src language/haskell/Tutorial/test-generation/app.hs --simulate-failure
```

Expected test output:

```text
success: fixture-100 functions=2 tests=3 status=draft_only executions=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: FIXTURE_INDEX_UNAVAILABLE reads=1
```

`fixture-200` is denied by policy before the tool runs. `--simulate-failure` reads
once, reports `FIXTURE_INDEX_UNAVAILABLE`, and exits nonzero.

`read_fixture` returns 2 functions with last failure `parse` in Dart for
`fixture-100`; `draft_tests` returns 3 generated tests covering `parse`/`format`
with `status=draft_only`, `review_required=true`, `executions=0` and
`load_targets=0`. Policy limits the fixture and final `generate_tests` action.

Real execution, coverage measurement and loopback load testing belong to the
consumer.
