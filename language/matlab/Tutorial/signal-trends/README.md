# Signal Trends Agent

A native MATLAB/Octave signal-analysis tutorial. The Agent has one fixed tool,
`review_signal`, which computes metrics over a fixed signal and returns a
structured report with an empty `mutating_actions` list. It does not read
arbitrary files, execute model-provided code, change thresholds or control a
device.

## Why this language and runtime?

- **Selection basis:** MATLAB is common in existing signal-processing and engineering
  workflows, so the Core seam can stay in that environment.
- **Demonstrated fit:** A shared `.m` tool computes fixed signal metrics and returns a
  report with no mutating actions. Current local execution evidence is GNU Octave.
- **Choose when:** Evaluating the seam in an existing MATLAB/Octave codebase.
- **Do not choose when:** Seeking toolbox-specific processing or device control.
  Compare direct MATLAB analysis and the acquisition pipeline first.
- **Evidence limit:** Fixed metrics via the Octave runner; native MATLAB execution is
  not established locally, and no toolbox, device or production claim follows.

## Run With GNU Octave

From the repository root:

```bash
octave --no-gui --quiet language/octave/Tutorial/signal-trends/run.m
```

Expected report:

```json
{"signal":{"source":"fixture","samples":10,"mean":0.42000000000000004,"peak_to_peak":1,"rms":0.53075418038862399,"anomalies":2,"first_anomaly":4},"mutating_actions":[]}
```

## Run With MATLAB

From the repository root, in MATLAB:

```matlab
addpath('language/matlab-octave-core');
addpath('language/matlab/Tutorial/signal-trends');
signal_trends();
```

Native MATLAB runtime verification is not claimed; the recorded run is GNU
Octave 11.3.0 only.

## What It Checks

- The fixture has ten samples, mean 0.42, peak-to-peak 1, RMS about 0.53075,
  two samples above the 0.80 threshold and first anomaly index 4.
- An out-of-scope dataset is denied by Agent policy before the tool runs
  (`reads=0`).
- A simulated signal dependency failure returns `TOOL_ERROR` after one tool call.
- The tutorial registers no mutating tools and writes no report when it fails.

## Boundaries

- The metric tool is fixed to one synthetic signal; no file path, arbitrary
  MATLAB code, package install or shell command comes from the model.
- The result is a teaching report, not a validated signal-processing pipeline,
  real-time controller, hardware interface or causal claim.
- There is no live model, provider credential, device control, dashboard,
  scheduler, durable report or independent consumer evidence.
- A successful Octave run does not establish native MATLAB behavior.
