# D Data Pipeline Diagnosis (SC-06)

Diagnose a bounded data-import batch before allowing a human to review it. Native
D parses unquoted two-column CSV records, calculates valid totals and reports
line-specific errors. Core calls the analysis tool, consumes its result and
chooses either rejection review or import review. Neither path imports data.

## Why this language and runtime?

- **Selection basis:** D supports native data-processing tools with standard-library
  ranges, conversion and string algorithms, alongside C interoperability.
- **Demonstrated fit:** `splitLines`, `split` and `to!int` parse actual input rather
  than returning precomputed error counts; changed-input tests alter the outcome.
- **Choose when:** An existing D import tool needs a governed review boundary.
- **Do not choose when:** A mature ETL platform or direct validation script already
  solves the task. This example is not a general CSV implementation.
- **Evidence limit:** In-memory fixture, no database, file replacement, ingestion
  platform, arbitrary code execution or live provider. Scope checks run inside
  tools before counters because the D policy hook exposes action kind only.

## Run

From the repository root:

```bash
dmd -i -Ilanguage/d/source -run language/d/Tutorial/data-pipeline/pipeline.d --test
dmd -i -Ilanguage/d/source -run language/d/Tutorial/data-pipeline/pipeline.d
dmd -i -Ilanguage/d/source -run language/d/Tutorial/data-pipeline/pipeline.d --batch batch-200
dmd -i -Ilanguage/d/source -run language/d/Tutorial/data-pipeline/pipeline.d --simulate-failure
```

Expected test output:

```text
D data-pipeline tutorial: parsing, branches, denial and failure passed
```

The fixture has two valid records totaling 20 and three rejected lines: invalid
integer, negative amount and field count. Both CLI negative commands exit nonzero.
Tests also cover clean input (total 11 and import-review branch), missing ID and
malformed header. All drafts require review; no records are imported.
