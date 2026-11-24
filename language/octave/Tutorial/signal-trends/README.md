# Octave Signal Trends

## Why this language and runtime?

- **Selection basis:** GNU Octave offers a free local path for teams using MATLAB-like
  signal workflows without a MATLAB license.
- **Demonstrated fit:** The shared `.m` tutorial runs under GNU Octave 11.3.0 and
  computes fixed signal metrics on a local fixture.
- **Choose when:** Evaluating the workflow in an Octave-only environment.
- **Do not choose when:** MATLAB compatibility or production signal processing is
  required. Run and validate under native MATLAB and the real acquisition stack.
- **Evidence limit:** GNU Octave result only; this run does not establish MATLAB
  behavior, toolbox availability, device integration or numerical production quality.

This runner loads the shared MATLAB/Octave signal tutorial:

```bash
octave --no-gui --quiet language/octave/Tutorial/signal-trends/run.m
```

See the shared
[signal-trends README](https://github.com/axisvela/praxo-core/tree/main/language/matlab/Tutorial/signal-trends)
for the report, failure checks and limits. The runner verifies GNU Octave 11.3.0
only; native MATLAB behavior is not established by this result.
