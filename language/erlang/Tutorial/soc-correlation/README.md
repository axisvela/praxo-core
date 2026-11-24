# Erlang SOC Correlation (CY-02)

Fixed EDR and firewall events are correlated; one critical event selects an
isolation-review branch, while clean input selects monitoring review. No host is
blocked and no live SIEM is queried.

## Why this language and runtime?

Erlang/BEAM fits concurrent security event handling; the tutorial exercises fixed
event correlation and policy branches in the same runtime.

Evidence limit: three fixed events only; no live EDR/firewall feed, detection
quality, host isolation or incident platform.
