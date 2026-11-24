# OCaml Code Review (SE-05)

A bounded first slice of [SE-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a full security or license audit. It reads a fixed diff and dependency
manifest, flags a high-severity unsafe-shell rule and a missing test, and drafts a
review-only comment set. This uses the source OCaml Core through the `ocaml`
toplevel; no network, credentials or packages beyond OCaml are required.

## Why this language and runtime?

- **Selection basis:** OCaml fits compiler, linter and static-analysis tools that
  already represent diffs or ASTs with typed data.
- **Demonstrated fit:** A fixed diff yields review-only comments; no repository scan,
  build, test or edit runs.
- **Choose when:** Learning the Core seam in an existing OCaml code tool.
- **Do not choose when:** Seeking real review automation or security audit. Compare the
  existing analyzer, CI rules and repository permissions first.
- **Evidence limit:** Core integration fixture only; no source build, test execution,
  security analysis, patch generation or repository write.

Run from **this directory** (the `#use` path is relative to the current working
directory):

```bash
cd language/ocaml/Tutorial/code-review
ocaml unix.cma review.ml --test
ocaml unix.cma review.ml
ocaml unix.cma review.ml --repo repo-200
ocaml unix.cma review.ml --simulate-failure
```

From the repository root:

```bash
(cd language/ocaml/Tutorial/code-review && ocaml unix.cma review.ml --test)
```

Expected test output:

```text
success: repo-100 high=unsafe_shell status=draft_only comments_written=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: CHANGE_SOURCE_UNAVAILABLE reads=1
```

Both negative commands exit nonzero.

The deterministic model plans three steps and consumes each result: `read_change`
returns two files, two findings (high `unsafe_shell`, low `test_missing`) and an
MIT license marker; `draft_review` returns `status=draft_only`,
`review_required=true` and `comments_written=0`. The action policy receives tool
name and arguments, limiting the repository and final `request_changes` action;
`require_policy` and `require_tool_scope` are enabled.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-repository denial, and one read/zero drafts for the simulated change-source
outage. The tool returns an error object for that outage; the model reports
`CHANGE_SOURCE_UNAVAILABLE` and no comment set is drafted.

Real repositories, diff parsing, vulnerability databases, license policy,
GitHub/GitLab writes, approvals and effect reconciliation belong to the consumer.
No live provider, publication, independent consumer or production audit is
claimed.
