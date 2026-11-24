# Erlang Policy Simulation (OG-02)

A bounded concurrent simulation: twelve Erlang processes compute household
subsidies for base and alternate policies, yielding 1200 and 1800. Core drafts a
review-only sensitivity report with no policy prediction.

## Why this language and runtime?

BEAM lightweight processes make the bounded household workers natural; the
tutorial uses real spawn/receive behavior, not a precomputed sum.

Evidence limit: twelve synthetic households and two fixed subsidies; no real
population, calibration, causal inference or policy prediction.
