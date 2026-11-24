# Python bug repair (SE-02)

A bounded first slice of [SE-02](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an autonomous coding agent. It reproduces a seeded defect, applies a review-only
patch to an in-memory fixture and reruns a fixture test. No real repository scan,
test runner, commit or pull request is used.

## Why this language and runtime?

- **Selection basis:** Python is a common language for debugging, test automation and
  developer tooling; the tutorial keeps the repair loop in that ecosystem.
- **Demonstrated fit:** The fixture source genuinely changes in memory, and the test
  result is derived from the patched source instead of a fixed success flag.
- **Choose when:** Learning the read/patch/rerun/policy boundary in a Python tool.
- **Do not choose when:** Seeking real code repair or CI integration. Compare the
  repository's test runner, patch review and branch protections first.
- **Evidence limit:** Fixed one-function defect and synthetic test check only; no
  repository scan, arbitrary code execution, real test runner, commit, PR or merge.

From this directory:

```bash
python app.py --test
python app.py
python app.py --repo repo-200
python app.py --simulate-failure
```

Expected test output: `Python SE-02 bug-repair tutorial: all checks passed`.
Both negative commands exit nonzero.

`read_defect` returns the seeded source, failing test and observed result;
`draft_patch` changes the in-memory source and returns a review-only patch;
`run_tests` recomputes pass/fail from the patched source and reports
`before=failed`, `after=passed` and `pull_requests=0`. Policy limits the repository
and each action.
