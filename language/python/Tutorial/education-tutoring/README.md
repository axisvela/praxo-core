# Python education tutoring

A native Python Core tutorial for a guided study plan. An application-owned
`LessonRetriever` implements the Core `Retriever` protocol and returns typed
`Document`s with metadata and scores; the agent cites the top lesson and drafts a
review-only study plan. This tutorial does not read arbitrary files, create
assignments, identify a student or call a live model.

## Why this language and runtime?

- **Selection basis:** Python fits education tooling that already uses retrievers and
  structured lesson content.
- **Demonstrated fit:** A fixed lesson corpus and Core `Retriever` produce a draft study
  plan; no adaptive learner model or assignment write runs.
- **Choose when:** Learning retrieval and review boundaries in an existing Python tool.
- **Do not choose when:** Seeking validated adaptive tutoring or grading. Compare the
  learning platform's pedagogy and assessment rules first.
- **Evidence limit:** Core integration fixture only; no student data, adaptive
  validation, assignment creation, grading or learning-outcome claim.

## Run

From this directory:

```bash
python -m pip install -r requirements.txt
python app.py --test
python app.py
python app.py --scope private
python app.py --simulate-failure
```

Expected test output:

```text
Python education-tutoring tutorial: all checks passed
```

`--scope private` is denied by policy before the retriever runs (reads=0). A
simulated lesson-index failure errors after one retrieval.

## Path

1. `search_lessons` calls the application-owned `LessonRetriever`, which returns
   `Document`s scored over a fixed three-lesson corpus (`lesson-fractions`,
   `lesson-decimals`, `lesson-ratios`) and their metadata.
2. `draft_study_plan` returns `status=draft_only`, `review_required=true` and
   `assignments_created=0` for `assign_review`.
3. The deterministic model cites `lesson-fractions` and packages the plan into a
   JSON report.

The application owns the student identity, curriculum policy, assignment
creation and any real learning record.

## Scope

This is source and local fixture evidence. It does not establish a real learning
system, student data, curriculum correctness, live provider, public hosting or
independent adoption. The retriever and report fields are tutorial-local and are
not Core or wire API.
