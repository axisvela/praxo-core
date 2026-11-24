# Octave Water Quality (AE-03)

A bounded pond water-quality tutorial. It computes fixed dissolved-oxygen and
temperature indicators, compares oxygen with a threshold, and lets Core choose a
normal or aeration-review branch. No sensor or aerator is accessed.

## Why this language and runtime?

- **Selection basis:** Octave is used for matrix and environmental data analysis
  where threshold checks and simple models already live.
- **Demonstrated fit:** Oxygen 4.2 mg/L versus a 5.0 threshold produces
  `review_aeration`; 6.2 mg/L produces `review_normal`.
- **Choose when:** An Octave monitoring workflow needs a governed review seam.
- **Do not choose when:** Real sensor ingestion, aeration control or water-quality
  certification is required. Compare the controller and farm SOP first.
- **Evidence limit:** Two fixed oxygen values and one threshold; no sensor, actuator,
  aerator/feeder command, water-quality model or production guarantee.

## Run

From the repository root:

```bash
octave --no-gui --quiet language/octave/Tutorial/water-quality/run.m --test
octave --no-gui --quiet language/octave/Tutorial/water-quality/run.m
octave --no-gui --quiet language/octave/Tutorial/water-quality/run.m --normal
octave --no-gui --quiet language/octave/Tutorial/water-quality/run.m --simulate-failure
```

Expected test output:

```text
Octave water-quality tutorial: threshold branch, denial and failure passed
```

The default low-oxygen path flags aeration review; `--normal` returns normal review.
Pond scope denial and the simulated data outage are covered. No actuator command is
drafted.
