# Haskell Rule DSL (SE-05)

A bounded business-rule validation tutorial. It parses a small access-rule DSL
into a typed Haskell structure, detects allow/deny conflicts and returns a
counterexample. Core consumes that result and drafts a review-only revision. No
rule is published or applied.

## Why this language and runtime?

- **Selection basis:** Haskell suits typed rule languages, parsers and analyzers
  where algebraic data types and exhaustive evaluation make conflicts explicit.
- **Demonstrated fit:** `words`-based parsing yields either a typed rule or a parse
  error; `conflict` returns an actual `(role, action)` counterexample from the parsed
  list, and the draft branch changes when the input changes.
- **Choose when:** An existing Haskell policy or compiler tool needs a governed rule
  review seam.
- **Do not choose when:** A mature policy engine or direct rules evaluator already
  covers the task. Types do not guarantee business correctness.
- **Evidence limit:** Tiny DSL and fixed roles/actions only; no parser combinator
  library, formal proof, policy deployment, authorization enforcement or live model.

## Run

From the repository root:

```bash
runghc -ilanguage/haskell/src language/haskell/Tutorial/rule-dsl/app.hs --test
runghc -ilanguage/haskell/src language/haskell/Tutorial/rule-dsl/app.hs
runghc -ilanguage/haskell/src language/haskell/Tutorial/rule-dsl/app.hs --deny
runghc -ilanguage/haskell/src language/haskell/Tutorial/rule-dsl/app.hs --invalid
runghc -ilanguage/haskell/src language/haskell/Tutorial/rule-dsl/app.hs --simulate-failure
```

Expected test output lists a conflict path, a conflict-free path, policy denial,
source failure and parse failure, ending with:

```text
Haskell rule-dsl tutorial: all checks passed
```

The conflict fixture returns role `admin`/action `write`; the clean fixture has no
conflict and drafts approval review instead. `--deny` is rejected with zero reads.
`--invalid` returns `RULE_PARSE_ERROR` with no draft.
