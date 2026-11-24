# Python CBT exercise (HC-05)

A bounded first slice of [HC-05](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a therapist or crisis service. It walks a fixed synthetic CBT exercise, keeps
an explicit `human_review` escalation branch, and drafts a review-only summary. No
live session, diagnosis, therapist replacement or unsupervised crisis handling.

From this directory:

```bash
python app.py --test
python app.py
python app.py --crisis
python app.py --session session-200
python app.py --simulate-failure
```

Expected test output: `Python HC-05 cbt-exercise tutorial: all checks passed`.
Negative commands exit nonzero.

`read_exercise` returns the `breathing` exercise with 3 steps, `crisis_flag`
false/true and `escalation=human_review` for `session-100`; `draft_summary`
returns `status=draft_only`, `review_required=true`, `therapist_replacement=0`
and `unsupervised_crisis=0`. Policy limits the session and final `draft_summary`
action.

Tests cover success, the crisis-escalation branch, a cross-session denial and the
simulated exercise-index outage. Real clinical care, crisis response and
therapist oversight belong to licensed professionals.
