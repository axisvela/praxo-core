# Elixir SOC Correlation (CY-02)

Fixed EDR/firewall events produce a critical count; one critical event selects an
isolation review, clean input selects monitoring. No host blocking.

## Why this language and runtime?

BEAM concurrency fits security event handling; the tutorial keeps event
correlation and policy review in that runtime.

Evidence limit: fixed events only; no live EDR/SIEM, detection quality or host
blocking.
