# MATLAB / Octave Representative Chain

Deterministic representative chain covering MCP record, final-argument
authorization, governed child delegation, OTel/Harmovela events, and an edited
denial with zero effects.

From the repository root:

```bash
octave-cli language/octave/examples/representative-chain/run.m
```

Expected output:

```text
output: DONE
effects: parent=1 child=1
child calls: 2
otel spans: 10
harmovela events: 10
denied effects: 0
```

The shared implementation records agent event kinds in `result.events`; the
example emits those events to the OTel and Harmovela transport seams after each
run. Native MATLAB execution remains unverified; current evidence is GNU Octave
11.3.0.
