# MATLAB Data Quality (SC-06)

A bounded data-quality tutorial. It computes fixed mean/median/outlier statistics,
then lets Core choose normal or outlier review. No source data is modified.

## Why this language and runtime?

- **Selection basis:** MATLAB is common for data cleaning and statistical checks in
  engineering and research groups.
- **Demonstrated fit:** The fixed sample `[10 12 12 14 100]` yields one outlier and
  `review_outliers`; the clean sample yields zero and `review_normal`.
- **Choose when:** An existing MATLAB analysis workflow needs a governed review seam.
- **Do not choose when:** Native MATLAB, toolboxes or a production ETL pipeline are
  required. Local verification is GNU Octave only.
- **Evidence limit:** Five fixed samples and a simple threshold only; no source
  correction, profiling engine, ETL, native MATLAB validation or quality guarantee.

## Run

From the repository root (local evidence uses GNU Octave):

```bash
octave --no-gui --quiet language/matlab/Tutorial/data-quality/run.m --test
octave --no-gui --quiet language/matlab/Tutorial/data-quality/run.m
octave --no-gui --quiet language/matlab/Tutorial/data-quality/run.m --normal
octave --no-gui --quiet language/matlab/Tutorial/data-quality/run.m --simulate-failure
```

Expected test output:

```text
MATLAB/Octave data-quality tutorial: statistics, branches, denial and failure passed
```

The default dataset flags one outlier; `--normal` returns normal review. Scope denial
and the simulated data outage are covered. Native MATLAB behavior is not established
by this Octave run.
