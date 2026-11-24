# Octave Vibration Review (IN-01)

A bounded vibration-analysis tutorial. It computes FFT/RMS for normal and anomalous
signals, derives a high-frequency energy ratio, and lets Core choose normal or
inspection review. No device is accessed and no failure is predicted.

## Why this language and runtime?

- **Selection basis:** Octave is used for matrix and signal analysis in engineering
  workflows that follow MATLAB-style processing without a commercial license.
- **Demonstrated fit:** Native `fft`/RMS calculations change with the input: normal
  samples stay near 50 Hz with low high-band energy; anomalous samples add a strong
  180 Hz component and switch the review action.
- **Choose when:** An Octave signal workflow needs a governed inspection-review seam.
- **Do not choose when:** Native MATLAB behavior, a validated diagnostic model or a
  real acquisition system is required. Octave results are not MATLAB evidence.
- **Evidence limit:** Synthetic samples and a fixed threshold only; no sensor,
  predictive model, maintenance schedule, equipment command or MATLAB claim.

## Run

From the repository root:

```bash
octave --no-gui --quiet language/octave/Tutorial/vibration-review/run.m --test
octave --no-gui --quiet language/octave/Tutorial/vibration-review/run.m
octave --no-gui --quiet language/octave/Tutorial/vibration-review/run.m --normal
octave --no-gui --quiet language/octave/Tutorial/vibration-review/run.m --simulate-failure
```

Expected test output:

```text
Octave vibration-review tutorial: FFT branch, denial and failure passed
```

The anomalous fixture flags inspection at about 180 Hz with a high-band ratio above
the threshold; `--normal` returns `review_normal`. The failure path returns
`TOOL_ERROR` with one read and no draft. `--normal` and the default path exit zero.
