# Coding-Agent Adoption Baseline Protocol

**Status:** proposed evaluation protocol, 2026-11-08. **Not run.** No discovery,
selection, installation, repair-cost, or retention results exist yet. This page
defines how to produce them; it is not adoption evidence.

## Purpose

The [roadmap](roadmap.md#adoption-evidence) separates three questions: free
selection, directed integration, and upgrade/maintenance. This protocol defines a
repeatable baseline before discovery materials, skills, or integration guidance
are changed.

## Non-Claims

- A successful session does not prove framework correctness; correctness is
  covered by tests and evidence indices.
- An explicitly required dependency is directed-integration evidence, not free
  selection.
- Registry downloads are supporting signals, not adoption or retention.
- A tool failure or exclusion is data, not automatically a framework defect.
- Results are scoped to the exact tool, model, prompt, package version,
  environment, permissions, and budget.
- No live provider, production deployment, or independent assurance is implied.

## Tracks

| Track | Question | Required condition |
| --- | --- | --- |
| Free selection | Without naming PRAXO-CORE, does the coding tool discover it and correctly select or exclude it for the task? | The task prompt omits the framework name |
| Directed integration | When PRAXO-CORE is required, can the tool install, build, test, and satisfy the stated governance requirements? | The task names PRAXO-CORE and the required controls |
| Upgrade and maintenance | Does the generated integration continue to work after a dependency update or application change? | Start from a recorded baseline; change only the dependency or application |

Do not combine the tracks into one score.

## Task Set

Use both regression tasks and unseen tasks.

- **Regression tasks** are fixed, published, and reused across runs.
- **Unseen tasks** are not used to tune documentation, skills, or prompts; treat
  them as held-out.
- Each task defines the goal, whether PRAXO-CORE is suitable, the expected
  artifact, required governed controls, acceptance checks, and hidden failure
  cases.
- Include tasks where PRAXO-CORE is unsuitable. Correct exclusion is a successful
  selection decision, not an integration failure.
- Do not score a task only by "installed successfully"; require the stated
  governed behavior.

## Task Manifest

Pre-register the task set as JSON before running any trial. The manifest records
the pinned tool, model, environment, permissions, budgets, and every task's
track, kind, suitability, prompt, package version, and acceptance checks.

```json
{
  "schemaVersion": 1,
  "protocol": "docs/project/adoption-baseline.md",
  "tool": {"name": "example-tool", "version": "1.0.0"},
  "model": {"name": "example-model", "version": "2026-11-01"},
  "environment": {
    "os": "linux",
    "toolchain": "go1.25.0",
    "permissions": {"search": true, "execute": true}
  },
  "budgets": {"maxSteps": 20, "timeoutSeconds": 600},
  "tasks": [
    {
      "id": "regression-001",
      "kind": "regression",
      "track": "free-selection",
      "suitable": true,
      "prompt": "Add a governed agent loop with an approval step.",
      "packageVersion": "2.6.0",
      "acceptance": ["the loop runs", "approval is required"]
    }
  ]
}
```

Validate the manifest before running:

```bash
python scripts/adoption_baseline.py manifest.json
```

Validation is structural and does not execute a coding tool or produce adoption
evidence. Free-selection prompts must not name PRAXO-CORE; directed-integration
prompts must name it. Upgrade tasks also require `baselineVersion` and
`targetVersion`. Keep real manifests and raw transcripts in restricted internal
storage; publish only the scoped summary.

## Conditions

- Compare **no skill** and **installed skill** separately.
- Compare **free selection** and **directed integration** separately.
- Pin the coding tool, model, tool version, prompt, package version, registry,
  operating system, toolchain, search and execution permissions, budget, and
  time limit.
- Repeat trials and report the sample size. Do not compare conditions with
  different pinned versions or prompts.
- For upgrade questions, reuse the published-package upgrade fixtures and the
  unchanged consumer source where applicable.

## Metrics

| Metric | Definition |
| --- | --- |
| Discovery | The tool surfaces the project without being told its name |
| Selection correctness | Selects PRAXO-CORE when suitable and excludes it when unsuitable |
| Install and build | The published package installs and builds without a source checkout or local replacement |
| Governed behavior | Missing policy/scope, final-argument and approval-edit reauthorization, and policy-service failure checks pass |
| First-attempt success | The task passes on the first generated integration |
| Eventual session success | The task passes after autonomous repair within the declared budget |
| Repair cost | Attempts, commands, elapsed time, tokens, and human interventions |
| Retention | The dependency remains after an observed upgrade or application change |
| Exclusions | Correct exclusions and their reasons |

Keep first-attempt and eventual success separate. A later successful repair does
not erase the first failure.

## Procedure

1. Pre-register the task set, track, condition, pinned versions, permissions,
   budgets, and success criteria as a validated task manifest.
2. Prepare a clean environment with published packages and no source checkout or
   local replacement.
3. Run the baseline condition and record the raw transcript, commands, outputs,
   failures, and skipped or blocked steps.
4. Run the treatment condition with the same task and environment.
5. Verify acceptance independently of the tool's self-report.
6. Record unavailable data as unknown; never infer it from registry downloads or
   from a later run.
7. Analyze per track and per task. Do not aggregate free selection with directed
   integration.
8. Publish a scoped summary that names the exact revisions, environment, and
   limitations.

## Evidence Record

Use the [test evidence standard](../contributing/test-evidence.md). Record:

- date and trial identifier;
- coding tool and model versions;
- task ID and prompt text;
- track and condition (free selection or directed; no skill or installed skill);
- package, published version, and registry;
- operating system, toolchain, and permissions;
- budget and time limit;
- commands, outputs, and failure transcripts;
- first-attempt result and eventual result;
- repair cost;
- retention observation and its window;
- evidence references and limitations.

Raw transcripts and full environment logs stay in restricted internal storage.
Publish only scoped summaries that name the exact revision and result.

## Analysis and Reporting

- Report per task and per track; do not publish a single adoption score.
- Keep correct exclusions separate from integration failures.
- Do not compare conditions with different tool, model, prompt, or package
  versions.
- Set improvement targets only after the baseline; do not invent percentages.
- Distinguish regression tasks from unseen tasks in every summary.

## Open Decisions

- Which coding tools and models, and which exact versions.
- Which tasks and hidden acceptance checks.
- Allowed search and execution permissions.
- Budgets, repetition count, and time limits.
- Retention observation window and consent.
- Where raw records are stored and who reviews the summary.

## Related Documents

- [Public roadmap](roadmap.md)
- [Contract and evidence status](contract-status.md)
- [Test and evidence taxonomy](test-taxonomy.md)
- [Test evidence standard](../contributing/test-evidence.md)
- [Coding-agent integration contract](../getting-started/coding-agents.md)
- [Adoption guide](../getting-started/adoption.md)
